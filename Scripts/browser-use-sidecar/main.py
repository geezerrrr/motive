#!/usr/bin/env python3
"""
browser-use-sidecar: Direct browser automation CLI with persistent sessions.

Uses Unix socket for IPC to maintain browser session across multiple CLI calls.
Features:
- Idle timeout: Server auto-exits after 5 minutes of inactivity
- Browser close detection: Server exits when browser crashes/closes
- Singleton guarantee: Only one server instance runs at a time
- Tab management: List and switch between tabs
- Wait command: Wait for user interaction (login, captcha, etc.)

Refactored to use browser-use native APIs instead of direct CDP calls.
"""

# ============================================================================
# CRITICAL: PyInstaller fixes MUST be at the very top, before any other imports
# ============================================================================
import sys
import os

def _fix_pyinstaller_importlib_resources():
    """Fix importlib.resources.files() for PyInstaller onefile mode.
    
    PyInstaller extracts data files to sys._MEIPASS, but importlib.resources
    doesn't know about this. We patch it to find prompt templates.
    """
    if not getattr(sys, 'frozen', False):
        return  # Not running from PyInstaller
    
    meipass = getattr(sys, '_MEIPASS', None)
    if not meipass:
        return
    
    import importlib.resources
    from pathlib import Path
    
    _original_files = importlib.resources.files
    
    class PyInstallerTraversable:
        """Wrapper that mimics importlib.resources.Traversable for PyInstaller."""
        def __init__(self, path):
            self._path = Path(path) if not isinstance(path, Path) else path
        
        @property
        def name(self):
            return self._path.name
        
        def joinpath(self, *args):
            return PyInstallerTraversable(self._path.joinpath(*args))
        
        def open(self, mode='r', encoding=None, errors=None):
            return self._path.open(mode=mode, encoding=encoding, errors=errors)
        
        def read_text(self, encoding='utf-8'):
            return self._path.read_text(encoding=encoding)
        
        def read_bytes(self):
            return self._path.read_bytes()
        
        def is_file(self):
            return self._path.is_file()
        
        def is_dir(self):
            return self._path.is_dir()
        
        def iterdir(self):
            for p in self._path.iterdir():
                yield PyInstallerTraversable(p)
        
        def __truediv__(self, other):
            return self.joinpath(other)
        
        def __str__(self):
            return str(self._path)
        
        def __fspath__(self):
            return str(self._path)
    
    def patched_files(package):
        """Patched importlib.resources.files for PyInstaller."""
        if isinstance(package, str):
            package_path = package.replace('.', os.sep)
            pyinstaller_path = Path(meipass) / package_path
            
            if pyinstaller_path.exists():
                return PyInstallerTraversable(pyinstaller_path)
        
        # Fall back to original
        try:
            return _original_files(package)
        except Exception:
            if isinstance(package, str):
                return PyInstallerTraversable(Path(meipass) / package.replace('.', os.sep))
            raise
    
    importlib.resources.files = patched_files

# Apply PyInstaller fix immediately
_fix_pyinstaller_importlib_resources()

# ============================================================================
# Now safe to do other imports
# ============================================================================

import urllib.request
# CRITICAL: Patch getproxies BEFORE any imports to disable macOS system proxy
urllib.request.getproxies = lambda: {}

import argparse
import asyncio
import fcntl
import json
import logging
import signal
import socket
import subprocess
import tempfile
import time
from pathlib import Path

# Clear proxy env vars
for var in ['ALL_PROXY', 'all_proxy', 'HTTP_PROXY', 'http_proxy',
            'HTTPS_PROXY', 'https_proxy', 'SOCKS_PROXY', 'socks_proxy']:
    os.environ.pop(var, None)

# Set up logging
logging.basicConfig(level=logging.WARNING, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

# Configuration
IDLE_TIMEOUT_SECONDS = 300  # 5 minutes
BROWSER_CHECK_INTERVAL = 15  # Check browser health every 15 seconds

# File paths
SOCKET_PATH = Path(tempfile.gettempdir()) / "browser-use-sidecar.sock"
PID_PATH = Path(tempfile.gettempdir()) / "browser-use-sidecar.pid"
LOCK_PATH = Path(tempfile.gettempdir()) / "browser-use-sidecar.lock"
LOG_PATH = Path(tempfile.gettempdir()) / "browser-use-sidecar.log"
CHROME_PID_PATH = Path(tempfile.gettempdir()) / "browser-use-sidecar-chrome.pid"


def cleanup_stale_files():
    """Clean up stale socket/pid files if process doesn't exist."""
    if PID_PATH.exists():
        try:
            pid = int(PID_PATH.read_text().strip())
            os.kill(pid, 0)  # Check if process exists
        except (OSError, ValueError):
            # Process doesn't exist, clean up
            PID_PATH.unlink(missing_ok=True)
            SOCKET_PATH.unlink(missing_ok=True)
            LOCK_PATH.unlink(missing_ok=True)


def force_kill_chrome():
    """Force kill any Chrome/Chromium processes spawned by sidecar."""
    # Method 1: Kill by saved PID
    if CHROME_PID_PATH.exists():
        try:
            chrome_pid = int(CHROME_PID_PATH.read_text().strip())
            try:
                os.killpg(chrome_pid, signal.SIGTERM)
                time.sleep(0.5)
                os.killpg(chrome_pid, signal.SIGKILL)
            except (OSError, ProcessLookupError):
                pass
            try:
                os.kill(chrome_pid, signal.SIGKILL)
            except (OSError, ProcessLookupError):
                pass
            CHROME_PID_PATH.unlink(missing_ok=True)
        except (OSError, ValueError):
            pass
    
    # Method 2: Kill Chromium processes using our profile directory
    try:
        for pid in find_chrome_pids_for_profile():
            if pid != os.getpid():
                try:
                    os.kill(pid, signal.SIGKILL)
                except (OSError, ValueError):
                    pass
    except Exception:
        pass
    
    # Method 3: Kill any chromium with remote debugging (last resort)
    try:
        subprocess.run(
            ['pkill', '-9', '-f', 'chromium.*--remote-debugging-port'],
            capture_output=True
        )
    except Exception:
        pass


def find_chrome_pids_for_profile() -> list[int]:
    """Find Chromium PIDs launched with our profile directory."""
    profile_marker = "Motive/browser/profiles"
    try:
        result = subprocess.run(
            ['pgrep', '-f', f'chromium.*{profile_marker}'],
            capture_output=True, text=True
        )
        pids = []
        if result.stdout.strip():
            for pid_str in result.stdout.strip().split('\n'):
                try:
                    pids.append(int(pid_str))
                except ValueError:
                    continue
        return pids
    except Exception:
        return []


def wait_for_chrome_exit(timeout_seconds: float = 5.0) -> bool:
    """Wait briefly for Chromium to exit before force killing."""
    start_time = time.time()
    while time.time() - start_time < timeout_seconds:
        if not find_chrome_pids_for_profile():
            return True
        time.sleep(0.2)
    return False


def is_server_running() -> bool:
    """Check if server is running and responsive."""
    cleanup_stale_files()
    
    if not PID_PATH.exists():
        return False
    
    try:
        pid = int(PID_PATH.read_text().strip())
        os.kill(pid, 0)
        
        if SOCKET_PATH.exists():
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            try:
                sock.settimeout(1.0)
                sock.connect(str(SOCKET_PATH))
                sock.close()
                return True
            except (socket.error, socket.timeout):
                try:
                    os.kill(pid, signal.SIGTERM)
                    time.sleep(0.3)
                    os.kill(pid, signal.SIGKILL)
                except OSError:
                    pass
                cleanup_stale_files()
                return False
        return False
    except (OSError, ValueError):
        cleanup_stale_files()
        return False


def kill_existing_server():
    """Kill any existing server process and Chrome."""
    cleanup_stale_files()
    
    if PID_PATH.exists():
        try:
            pid = int(PID_PATH.read_text().strip())
            os.kill(pid, signal.SIGTERM)
            for _ in range(20):
                time.sleep(0.1)
                try:
                    os.kill(pid, 0)
                except OSError:
                    break
            else:
                try:
                    os.kill(pid, signal.SIGKILL)
                except OSError:
                    pass
        except (OSError, ValueError):
            pass
    
    cleanup_stale_files()
    force_kill_chrome()


def send_to_server(request: dict, timeout: float = 60.0) -> dict:
    """Send request to server and get response."""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        sock.connect(str(SOCKET_PATH))
        sock.sendall(json.dumps(request).encode() + b'\n')
        
        data = b''
        while True:
            chunk = sock.recv(8192)
            if not chunk:
                break
            data += chunk
            if b'\n' in data:
                break
        
        return json.loads(data.decode().strip())
    finally:
        sock.close()


class BrowserServer:
    """Server that maintains browser session with auto-cleanup.
    
    Uses browser-use native APIs for all browser operations.
    Supports Agent mode for autonomous task execution with human-in-the-loop.
    """
    
    def __init__(self, headed: bool = True):
        self.headed = headed
        self.session = None  # BrowserSession
        self.running = True
        self.last_activity = time.time()
        self._lock_fd = None
        self._storage_state_path = None
        
        # Agent mode state
        self._agent_task = None  # asyncio.Task for running agent
        self._agent_instance = None  # Agent instance
        self._pending_question = None  # Question waiting for user response
        self._user_response_event = asyncio.Event()  # Signal when user responds
        self._user_response_value = None  # User's response value
    
    def acquire_lock(self) -> bool:
        """Acquire exclusive lock to ensure singleton."""
        try:
            self._lock_fd = open(LOCK_PATH, 'w')
            fcntl.flock(self._lock_fd.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except (IOError, OSError):
            if self._lock_fd:
                self._lock_fd.close()
                self._lock_fd = None
            return False
    
    def release_lock(self):
        """Release the exclusive lock."""
        if self._lock_fd:
            try:
                fcntl.flock(self._lock_fd.fileno(), fcntl.LOCK_UN)
                self._lock_fd.close()
            except:
                pass
            self._lock_fd = None
        LOCK_PATH.unlink(missing_ok=True)
    
    async def start_browser(self):
        """Start browser session with isolated profile, copying essential auth files."""
        from browser_use.browser.session import BrowserSession
        from browser_use.browser.profile import BrowserProfile
        # Use isolated Chrome profile for automation
        profile_dir = Path.home() / "Library" / "Application Support" / "Motive" / "browser" / "profiles" / "chrome-profile"
        profile_dir.mkdir(parents=True, exist_ok=True)
        default_subdir = profile_dir / "Default"
        default_subdir.mkdir(parents=True, exist_ok=True)
        
        self._storage_state_path = profile_dir / "storage_state.json"
        storage_state = str(self._storage_state_path) if self._storage_state_path.exists() else None

        profile = BrowserProfile(
            headless=not self.headed,
            user_data_dir=str(profile_dir),
            profile_directory="Default",
            channel='chromium',  # Use independent Chromium, not system Chrome
            keep_alive=True,  # Keep browser open after agent task completes
            enable_default_extensions=False,
            highlight_elements=False,
            paint_order_filtering=False,
            storage_state=storage_state,
        )
        logger.info(f"Browser profile: channel=chromium, user_data_dir={profile_dir}, headless={not self.headed}")
        
        # Retry browser startup up to 3 times
        max_retries = 3
        last_error = None
        
        for attempt in range(max_retries):
            try:
                self.session = BrowserSession(browser_profile=profile)
                await self.session.start()
                
                await asyncio.sleep(1)
                if await self.is_browser_alive():
                    print(f"Browser started successfully (attempt {attempt + 1})", flush=True)
                    return {"success": True, "message": "Browser started"}
                else:
                    raise RuntimeError("Browser started but health check failed")
                    
            except Exception as e:
                last_error = e
                logger.warning(f"Browser start attempt {attempt + 1} failed: {e}")
                
                if self.session:
                    try:
                        await self.session.stop()
                    except:
                        pass
                    self.session = None
                
                force_kill_chrome()
                
                if attempt < max_retries - 1:
                    await asyncio.sleep(2)
        
        raise RuntimeError(f"Failed to start browser after {max_retries} attempts: {last_error}")
    
    async def is_browser_alive(self) -> bool:
        """Check if browser session is still alive using native API."""
        if not self.session:
            return False
        
        try:
            # Try to get current page - this verifies browser is responsive
            page = await asyncio.wait_for(
                self.session.get_current_page(),
                timeout=5.0
            )
            return page is not None
        except asyncio.TimeoutError:
            logger.warning("Browser health check timeout")
            return False
        except Exception as e:
            err_str = str(e).lower()
            if any(x in err_str for x in ['target closed', 'session closed', 'browser closed', 'disconnected']):
                logger.warning(f"Browser appears dead: {e}")
                return False
            logger.warning(f"Health check error (assuming alive): {e}")
            return True
    
    def update_activity(self):
        """Update last activity timestamp."""
        self.last_activity = time.time()
    
    def is_idle_timeout(self) -> bool:
        """Check if idle timeout has been reached."""
        return (time.time() - self.last_activity) > IDLE_TIMEOUT_SECONDS
    
    async def handle_command(self, cmd: str, params: dict) -> dict:
        """Handle a browser command."""
        self.update_activity()
        
        try:
            if cmd == "open":
                return await self.cmd_open(params.get("url", ""))
            elif cmd == "state":
                return await self.cmd_state()
            elif cmd == "click":
                return await self.cmd_click(params.get("index", 0))
            elif cmd == "input":
                return await self.cmd_input(params.get("index", 0), params.get("text", ""))
            elif cmd == "type":
                return await self.cmd_type(params.get("text", ""))
            elif cmd == "keys":
                return await self.cmd_keys(params.get("key", ""))
            elif cmd == "scroll":
                return await self.cmd_scroll(params.get("direction", "down"))
            elif cmd == "back":
                return await self.cmd_back()
            elif cmd == "screenshot":
                return await self.cmd_screenshot(params.get("filename"))
            elif cmd == "close":
                return await self.cmd_close()
            elif cmd == "ping":
                return {"success": True, "message": "pong"}
            elif cmd == "tabs":
                return await self.cmd_tabs()
            elif cmd == "switch":
                return await self.cmd_switch(params.get("index", 0))
            elif cmd == "wait":
                return await self.cmd_wait(params.get("seconds", 30), params.get("message", ""))
            elif cmd == "refresh":
                return await self.cmd_refresh()
            elif cmd == "agent_task":
                return await self.cmd_agent_task(
                    params.get("task", ""),
                    params.get("max_steps", 50),
                    params.get("model", "anthropic")
                )
            elif cmd == "agent_continue":
                return await self.cmd_agent_continue(params.get("choice", ""))
            elif cmd == "agent_status":
                return await self.cmd_agent_status()
            elif cmd == "agent_cancel":
                return await self.cmd_agent_cancel()
            else:
                return {"error": f"Unknown command: {cmd}"}
        except Exception as e:
            logger.exception("Command error")
            return {"error": str(e)}
    
    async def cmd_open(self, url: str) -> dict:
        """Navigate to URL using browser-use NavigateToUrlEvent."""
        if not self.session:
            return {"error": "Browser not started"}
        
        if not await self.is_browser_alive():
            return {"error": "Browser is not responsive - may need to restart"}
        
        if not url.startswith(('http://', 'https://', 'file://')):
            url = 'https://' + url
        
        try:
            from browser_use.browser.events import NavigateToUrlEvent
            
            await asyncio.wait_for(
                self.session.event_bus.dispatch(NavigateToUrlEvent(url=url)),
                timeout=30.0
            )
            
            # Wait for page to be ready
            await asyncio.sleep(1.5)
            
            return {"success": True, "url": url}
        except asyncio.TimeoutError:
            return {"error": "Navigation timeout - page took too long to load"}
        except Exception as e:
            logger.error(f"Navigation failed: {e}")
            return {"error": f"Navigation failed: {e}"}
    
    async def cmd_state(self) -> dict:
        """Get page state with interactive elements using native API."""
        if not self.session:
            return {"error": "Browser not started"}
        
        if not await self.is_browser_alive():
            return {"error": "Browser is not responsive - may need to restart"}
        
        try:
            # Get tabs info
            tabs_info = await self._get_tabs_info()
            
            # Get page state using native API
            state_text = await asyncio.wait_for(
                self.session.get_state_as_text(),
                timeout=10.0
            )
            
            result = {"state": state_text}
            if tabs_info:
                result["current_tab"] = tabs_info.get("current_index", 0)
                result["total_tabs"] = tabs_info.get("total", 1)
            
            return result
        except asyncio.TimeoutError:
            return {"error": "Timeout getting page state - browser may be hung"}
        except Exception as e:
            logger.error(f"Failed to get state: {e}")
            return {"error": f"Failed to get state: {e}"}
    
    async def _get_tabs_info(self) -> dict:
        """Get information about all tabs using native API."""
        try:
            # Use browser-use's get_tabs method - returns list[TabInfo]
            tabs = await asyncio.wait_for(
                self.session.get_tabs(),
                timeout=5.0
            )
            
            if not tabs:
                return {}
            
            # Get current focus target
            current_target_id = self.session.agent_focus_target_id
            current_index = 0
            
            tab_list = []
            for i, tab in enumerate(tabs):
                # TabInfo has: url, title, target_id, parent_target_id
                tab_info = {
                    "index": i,
                    "title": tab.title if hasattr(tab, 'title') else '',
                    "url": tab.url if hasattr(tab, 'url') else '',
                    "targetId": tab.target_id if hasattr(tab, 'target_id') else ''
                }
                tab_list.append(tab_info)
                if tab_info["targetId"] == current_target_id:
                    current_index = i
            
            return {
                "tabs": tab_list,
                "current_index": current_index,
                "total": len(tabs)
            }
        except asyncio.TimeoutError:
            logger.warning("Timeout getting tabs info")
            return {}
        except Exception as e:
            logger.warning(f"Failed to get tabs info: {e}")
            return {}
    
    async def cmd_tabs(self) -> dict:
        """List all open tabs."""
        if not self.session:
            return {"error": "Browser not started"}
        
        tabs_info = await self._get_tabs_info()
        if not tabs_info:
            return {"tabs": [], "current": 0, "message": "Could not retrieve tabs"}
        
        return {
            "tabs": tabs_info.get("tabs", []),
            "current": tabs_info.get("current_index", 0),
            "total": tabs_info.get("total", 0)
        }
    
    async def cmd_switch(self, index: int) -> dict:
        """Switch to tab by index using SwitchTabEvent."""
        if not self.session:
            return {"error": "Browser not started"}
        
        try:
            tabs_info = await self._get_tabs_info()
            if not tabs_info or not tabs_info.get("tabs"):
                return {"error": "Could not get tabs list"}
            
            tabs = tabs_info["tabs"]
            if index < 0 or index >= len(tabs):
                return {"error": f"Invalid tab index {index}. Available: 0-{len(tabs)-1}"}
            
            target_id = tabs[index]["targetId"]
            
            from browser_use.browser.events import SwitchTabEvent
            await asyncio.wait_for(
                self.session.event_bus.dispatch(SwitchTabEvent(target_id=target_id)),
                timeout=10.0
            )
            
            await asyncio.sleep(0.2)
            
            return {
                "success": True,
                "switched_to": index,
                "url": tabs[index]["url"],
                "title": tabs[index]["title"]
            }
        except asyncio.TimeoutError:
            return {"error": "Tab switch timeout - browser may be unresponsive"}
        except Exception as e:
            logger.exception("Switch tab error")
            return {"error": f"Failed to switch tab: {e}"}
    
    async def cmd_click(self, index: int) -> dict:
        """Click element by index using ClickElementEvent."""
        if not self.session:
            return {"error": "Browser not started"}
        
        try:
            from browser_use.browser.events import ClickElementEvent
            
            node = await asyncio.wait_for(
                self.session.get_element_by_index(index),
                timeout=10.0
            )
            if node is None:
                return {"error": f"Element index {index} not found"}
            
            await asyncio.wait_for(
                self.session.event_bus.dispatch(ClickElementEvent(node=node)),
                timeout=10.0
            )
            await asyncio.sleep(0.5)
            
            return {"success": True, "clicked": index}
        except asyncio.TimeoutError:
            return {"error": "Click timeout - browser may be unresponsive"}
        except Exception as e:
            logger.exception("Click error")
            return {"error": f"Click failed: {e}"}
    
    async def cmd_input(self, index: int, text: str) -> dict:
        """Type text into element by index using native events."""
        if not self.session:
            return {"error": "Browser not started"}
        
        try:
            from browser_use.browser.events import ClickElementEvent, TypeTextEvent
            
            node = await asyncio.wait_for(
                self.session.get_element_by_index(index),
                timeout=10.0
            )
            if node is None:
                return {"error": f"Element index {index} not found"}
            
            # Click to focus
            await asyncio.wait_for(
                self.session.event_bus.dispatch(ClickElementEvent(node=node)),
                timeout=10.0
            )
            await asyncio.sleep(0.05)
            
            # Type text
            await asyncio.wait_for(
                self.session.event_bus.dispatch(TypeTextEvent(node=node, text=text)),
                timeout=10.0
            )
            await asyncio.sleep(0.05)
            
            return {"success": True, "index": index, "text": text}
        except asyncio.TimeoutError:
            return {"error": "Input timeout - browser may be unresponsive"}
        except Exception as e:
            logger.exception("Input error")
            return {"error": f"Input failed: {e}"}
    
    async def cmd_type(self, text: str) -> dict:
        """Type text into focused element using Page.evaluate."""
        if not self.session:
            return {"error": "Browser not started"}
        
        try:
            page = await asyncio.wait_for(
                self.session.get_current_page(),
                timeout=5.0
            )
            if not page:
                return {"error": "No active page"}
            
            # Use Page.evaluate to insert text into active element
            await asyncio.wait_for(
                page.evaluate(f'''() => {{
                    const el = document.activeElement;
                    if (el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable)) {{
                        el.value = (el.value || '') + {json.dumps(text)};
                        el.dispatchEvent(new Event('input', {{ bubbles: true }}));
                    }}
                }}'''),
                timeout=5.0
            )
            return {"success": True, "typed": text}
        except asyncio.TimeoutError:
            return {"error": "Type timeout - browser may be unresponsive"}
        except Exception as e:
            return {"error": f"Type failed: {e}"}
    
    async def cmd_keys(self, key: str) -> dict:
        """Press keyboard key using Page.press."""
        if not self.session:
            return {"error": "Browser not started"}
        
        try:
            page = await asyncio.wait_for(
                self.session.get_current_page(),
                timeout=5.0
            )
            if not page:
                return {"error": "No active page"}
            
            # Use Page.press for keyboard input
            await asyncio.wait_for(
                page.press(key),
                timeout=5.0
            )
            return {"success": True, "key": key}
        except asyncio.TimeoutError:
            return {"error": "Key press timeout - browser may be unresponsive"}
        except Exception as e:
            return {"error": f"Key press failed: {e}"}
    
    async def cmd_scroll(self, direction: str) -> dict:
        """Scroll page using ScrollEvent."""
        if not self.session:
            return {"error": "Browser not started"}
        
        try:
            from browser_use.browser.events import ScrollEvent
            
            # ScrollEvent: direction can be 'up' or 'down', amount is pixels
            amount = 500 if direction == "down" else -500
            
            await asyncio.wait_for(
                self.session.event_bus.dispatch(ScrollEvent(
                    coordinate=None,  # Scroll current viewport
                    direction=direction,
                    amount=abs(amount)
                )),
                timeout=5.0
            )
            return {"success": True, "direction": direction}
        except asyncio.TimeoutError:
            return {"error": "Scroll timeout - browser may be unresponsive"}
        except Exception as e:
            # Fallback to Page.evaluate if ScrollEvent doesn't work
            try:
                page = await self.session.get_current_page()
                if page:
                    amount = 500 if direction == "down" else -500
                    await page.evaluate(f'() => window.scrollBy(0, {amount})')
                    return {"success": True, "direction": direction}
            except:
                pass
            return {"error": f"Scroll failed: {e}"}
    
    async def cmd_back(self) -> dict:
        """Go back in history using GoBackEvent."""
        if not self.session:
            return {"error": "Browser not started"}
        
        try:
            from browser_use.browser.events import GoBackEvent
            
            await asyncio.wait_for(
                self.session.event_bus.dispatch(GoBackEvent()),
                timeout=10.0
            )
            await asyncio.sleep(0.5)
            return {"success": True}
        except asyncio.TimeoutError:
            return {"error": "Back navigation timeout - browser may be unresponsive"}
        except Exception as e:
            return {"error": f"Back navigation failed: {e}"}
    
    async def cmd_refresh(self) -> dict:
        """Refresh current page using Page.reload or RefreshEvent."""
        if not self.session:
            return {"error": "Browser not started"}
        
        try:
            # Try using Page.reload first (native browser-use API)
            page = await asyncio.wait_for(
                self.session.get_current_page(),
                timeout=5.0
            )
            if page:
                await asyncio.wait_for(
                    page.reload(),
                    timeout=10.0
                )
                await asyncio.sleep(1.0)
                return {"success": True, "message": "Page refreshed"}
            
            return {"error": "No active page to refresh"}
        except asyncio.TimeoutError:
            return {"error": "Refresh timeout - browser may be unresponsive"}
        except Exception as e:
            return {"error": f"Failed to refresh: {e}"}
    
    async def cmd_wait(self, seconds: int, message: str = "") -> dict:
        """Wait for user interaction (login, captcha, etc.)."""
        if not self.session:
            return {"error": "Browser not started"}
        
        wait_msg = message if message else "Waiting for user action"
        print(f"⏳ {wait_msg} ({seconds}s)...", flush=True)
        
        start_time = time.time()
        while time.time() - start_time < seconds:
            self.update_activity()
            await asyncio.sleep(1)
        
        return {
            "success": True,
            "waited": seconds,
            "message": f"Waited {seconds} seconds for: {wait_msg}"
        }
    
    async def cmd_screenshot(self, filename: str = None) -> dict:
        """Take screenshot using native API."""
        if not self.session:
            return {"error": "Browser not started"}
        
        import base64
        
        try:
            # Use Page.screenshot for native browser-use API
            page = await asyncio.wait_for(
                self.session.get_current_page(),
                timeout=5.0
            )
            if page:
                screenshot_b64 = await asyncio.wait_for(
                    page.screenshot(format='png'),
                    timeout=10.0
                )
                # Page.screenshot returns base64 string
                data = base64.b64decode(screenshot_b64) if isinstance(screenshot_b64, str) else screenshot_b64
            else:
                # Fallback to session method
                data = await self.session.take_screenshot(full_page=False)
            
            if filename:
                Path(filename).write_bytes(data)
                return {"success": True, "file": filename, "size": len(data)}
            
            b64 = base64.b64encode(data).decode() if isinstance(data, bytes) else data
            return {"success": True, "screenshot_base64_truncated": b64[:200] + "...", "size": len(data)}
        except Exception as e:
            return {"error": f"Screenshot failed: {e}"}
    
    async def cmd_close(self) -> dict:
        """Close browser and stop server."""
        # Cancel any running agent task
        if self._agent_task and not self._agent_task.done():
            self._agent_task.cancel()
            try:
                await self._agent_task
            except asyncio.CancelledError:
                pass

        await self._persist_storage_state()
        
        if self.session:
            try:
                await self.session.stop()
            except Exception:
                pass
            self.session = None
        
        if not wait_for_chrome_exit():
            force_kill_chrome()
        
        self.running = False
        return {"success": True, "message": "Browser closed, server stopping"}
    
    # ===== Agent Mode Commands =====
    
    async def cmd_agent_task(self, task: str, max_steps: int = 50, model: str = "auto") -> dict:
        """
        Start autonomous agent task execution with human-in-the-loop support.
        
        The agent will execute the task autonomously, but can ask for user input
        when it encounters situations requiring human decision.
        
        Returns:
        - {"status": "running", "message": "..."} - Task started
        - {"status": "need_input", "question": "...", "options": [...]} - Needs user choice
        - {"status": "completed", "success": bool, "result": "..."} - Task finished
        - {"status": "error", "error": "..."} - Task failed
        """
        if not task:
            return {"error": "Task description is required"}
        
        # Auto-start browser if not already started
        if not self.session:
            try:
                await self.start_browser()
            except Exception as e:
                return {"error": f"Failed to start browser: {e}"}
        
        # If agent is already running, return current status instead of erroring
        if self._agent_task and not self._agent_task.done():
            return await self.cmd_agent_status()
        
        # Reset state
        self._pending_question = None
        self._user_response_value = None
        self._user_response_event.clear()
        
        # Start agent task
        self._agent_task = asyncio.create_task(
            self._run_agent(task, max_steps, model)
        )
        
        # Wait briefly to see if it needs input or completes quickly
        try:
            await asyncio.wait_for(asyncio.shield(self._agent_task), timeout=2.0)
            # Task completed quickly
            return self._agent_task.result()
        except asyncio.TimeoutError:
            # Task still running, check if needs input
            if self._pending_question:
                return {
                    "status": "need_input",
                    "question": self._pending_question["question"],
                    "options": self._pending_question["options"],
                    "context": self._pending_question.get("context", "")
                }
            return {"status": "running", "message": "Agent task started, check status with agent_status"}
        except Exception as e:
            return {"status": "error", "error": str(e)}
    
    async def _run_agent(self, task: str, max_steps: int, model: str) -> dict:
        """Internal method to run the agent with human-in-the-loop support."""
        try:
            from browser_use import Agent
            from browser_use.agent.views import ActionResult
            
            # Create LLM based on model choice
            llm = self._create_llm(model)
            if llm is None:
                return {"status": "error", "error": f"Failed to create LLM for model: {model}"}
            
            # Create custom controller with ask_human action
            from browser_use import Controller
            controller = Controller()
            
            @controller.action(
                description="Ask the user to make a choice when you encounter multiple options or need clarification. "
                           "Use this when: selecting product variants (color, size), choosing between similar items, "
                           "confirming important actions, or when you need user preference."
            )
            async def ask_human(question: str, options: list[str], context: str = "") -> ActionResult:
                """Ask the user to choose from a list of options."""
                if not options or len(options) < 2:
                    return ActionResult(error="ask_human requires at least 2 options")
                
                # Set pending question
                self._pending_question = {
                    "question": question,
                    "options": options,
                    "context": context
                }
                
                # Wait for user response
                self._user_response_event.clear()
                await self._user_response_event.wait()
                
                # Get response and clear state
                response = self._user_response_value
                self._pending_question = None
                self._user_response_value = None
                
                return ActionResult(extracted_content=f"User selected: {response}")
            
            # System message extension to enforce ask_human usage
            ask_human_instruction = """
IMPORTANT RULE - Human-in-the-Loop:
You have access to an 'ask_human' action. You MUST use it in these situations:

1. **Product variants**: When a page has multiple options (colors, sizes, styles, configurations), 
   you MUST call ask_human with ALL available options from the page. Do NOT make selections yourself.

2. **Ambiguous choices**: When there are multiple similar items or unclear options, ask the user.

3. **Confirmations**: Before finalizing purchases, submissions, or irreversible actions, confirm with user.

4. **Missing information**: If the task doesn't specify a required choice, ask the user.

When calling ask_human:
- Extract ALL visible options from the page (read the DOM carefully)
- Provide clear, descriptive option labels
- Include context about what each option means

Example: If a product page shows colors "Red, Blue, Green" and sizes "S, M, L, XL", 
you should call ask_human twice - once for color selection, once for size selection.

NEVER skip user confirmation for variant selections. The user expects to make these choices.
"""
            
            # Create agent
            agent = Agent(
                task=task,
                llm=llm,
                browser=self.session,
                controller=controller,
                extend_system_message=ask_human_instruction,
            )
            self._agent_instance = agent
            
            # Run agent
            history = await agent.run(max_steps=max_steps)

            await self._persist_storage_state()
            
            self._agent_instance = None
            
            return {
                "status": "completed",
                "success": history.is_successful(),
                "result": history.final_result() or "Task completed",
                "steps": history.number_of_steps(),
                "urls": list(history.urls()) if history.urls() else []
            }
            
        except asyncio.CancelledError:
            self._agent_instance = None
            return {"status": "cancelled", "message": "Agent task was cancelled"}
        except Exception as e:
            self._agent_instance = None
            logger.exception("Agent task error")
            return {"status": "error", "error": str(e)}

    async def _persist_storage_state(self):
        """Persist browser storage state to reduce login loss across restarts."""
        if not self.session or not self._storage_state_path:
            return
        try:
            page = await asyncio.wait_for(
                self.session.get_current_page(),
                timeout=5.0
            )
            if page:
                await page.context.storage_state(path=str(self._storage_state_path))
        except Exception as e:
            logger.warning(f"Failed to persist storage state: {e}")
    
    def _create_llm(self, model: str):
        """Create LLM instance based on model choice.
        
        If model is "auto", automatically detect available API key.
        Supports custom base URLs via environment variables.
        """
        # Auto-detect model based on available API keys
        if model == "auto":
            if os.environ.get("BROWSER_USE_API_KEY"):
                model = "browser-use"
                logger.info("Auto-detected BROWSER_USE_API_KEY, using ChatBrowserUse")
            elif os.environ.get("ANTHROPIC_API_KEY"):
                model = "anthropic"
                logger.info("Auto-detected ANTHROPIC_API_KEY, using ChatAnthropic")
            elif os.environ.get("OPENAI_API_KEY"):
                model = "openai"
                logger.info("Auto-detected OPENAI_API_KEY, using ChatOpenAI")
            else:
                logger.error("No API key found. Set BROWSER_USE_API_KEY, ANTHROPIC_API_KEY, or OPENAI_API_KEY")
                return None
        
        try:
            if model == "browser-use" or model == "chatbrowseruse":
                # ChatBrowserUse requires BROWSER_USE_API_KEY
                from browser_use import ChatBrowserUse
                return ChatBrowserUse()
            elif model == "anthropic" or model == "claude":
                from langchain_anthropic import ChatAnthropic
                base_url = os.environ.get("ANTHROPIC_BASE_URL")
                if base_url:
                    return ChatAnthropic(model="claude-sonnet-4-20250514", base_url=base_url)
                return ChatAnthropic(model="claude-sonnet-4-20250514")
            elif model == "openai" or model == "gpt":
                from langchain_openai import ChatOpenAI
                base_url = os.environ.get("OPENAI_BASE_URL")
                if base_url:
                    return ChatOpenAI(model="gpt-4o", base_url=base_url)
                return ChatOpenAI(model="gpt-4o")
            else:
                logger.error(f"Unknown model: {model}")
                return None
        except Exception as e:
            logger.error(f"Failed to create LLM for {model}: {e}")
            return None
    
    async def cmd_agent_continue(self, choice: str) -> dict:
        """
        Continue agent execution with user's choice.
        
        Call this after receiving a 'need_input' status with the user's selection.
        """
        if not self._agent_task or self._agent_task.done():
            return {"error": "No agent task is waiting for input"}
        
        if not self._pending_question:
            return {"error": "Agent is not waiting for user input"}
        
        if not choice:
            return {"error": "Choice is required"}
        
        # Validate choice is one of the options (or allow custom)
        valid_options = self._pending_question.get("options", [])
        if choice not in valid_options:
            # Allow it anyway - might be a custom "Other" response
            logger.info(f"User provided custom choice: {choice}")
        
        # Set response and signal
        self._user_response_value = choice
        self._user_response_event.set()
        
        # Wait briefly to see if task needs more input or completes
        try:
            await asyncio.wait_for(asyncio.shield(self._agent_task), timeout=5.0)
            return self._agent_task.result()
        except asyncio.TimeoutError:
            if self._pending_question:
                return {
                    "status": "need_input",
                    "question": self._pending_question["question"],
                    "options": self._pending_question["options"],
                    "context": self._pending_question.get("context", "")
                }
            return {"status": "running", "message": "Agent continuing..."}
        except Exception as e:
            return {"status": "error", "error": str(e)}
    
    async def cmd_agent_status(self) -> dict:
        """Get current agent task status."""
        if not self._agent_task:
            return {"status": "idle", "message": "No agent task"}
        
        if self._agent_task.done():
            try:
                result = self._agent_task.result()
                return result
            except Exception as e:
                return {"status": "error", "error": str(e)}
        
        if self._pending_question:
            return {
                "status": "need_input",
                "question": self._pending_question["question"],
                "options": self._pending_question["options"],
                "context": self._pending_question.get("context", "")
            }
        
        return {"status": "running", "message": "Agent task in progress"}
    
    async def cmd_agent_cancel(self) -> dict:
        """Cancel the current agent task."""
        if not self._agent_task or self._agent_task.done():
            return {"success": True, "message": "No active agent task to cancel"}
        
        self._agent_task.cancel()
        try:
            await self._agent_task
        except asyncio.CancelledError:
            pass
        
        self._agent_instance = None
        self._pending_question = None
        
        return {"success": True, "message": "Agent task cancelled"}
    
    async def handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        """Handle a client connection."""
        try:
            data = await asyncio.wait_for(reader.readline(), timeout=60.0)
            if not data:
                return
            
            request = json.loads(data.decode().strip())
            cmd = request.get("command", "")
            params = request.get("params", {})
            
            response = await self.handle_command(cmd, params)
            
            writer.write(json.dumps(response).encode() + b'\n')
            await writer.drain()
        except asyncio.TimeoutError:
            pass
        except Exception as e:
            logger.exception("Client handler error")
            try:
                writer.write(json.dumps({"error": str(e)}).encode() + b'\n')
                await writer.drain()
            except:
                pass
        finally:
            writer.close()
            try:
                await writer.wait_closed()
            except:
                pass
    
    async def health_check_loop(self):
        """Periodically check browser health and idle timeout."""
        consecutive_failures = 0
        max_consecutive_failures = 3
        
        while self.running:
            await asyncio.sleep(BROWSER_CHECK_INTERVAL)
            
            # Skip health check and idle timeout if agent task is running
            # Agent tasks can take a long time and browser may appear unresponsive during operations
            if self._agent_task and not self._agent_task.done():
                consecutive_failures = 0  # Reset failure count during agent execution
                self.update_activity()  # Keep activity alive during agent task
                continue
            
            if self.is_idle_timeout():
                print(f"Idle timeout reached ({IDLE_TIMEOUT_SECONDS}s), shutting down...", flush=True)
                self.running = False
                break
            
            if self.session:
                if await self.is_browser_alive():
                    consecutive_failures = 0
                else:
                    consecutive_failures += 1
                    print(f"Browser health check failed ({consecutive_failures}/{max_consecutive_failures})", flush=True)
                    
                    if consecutive_failures >= max_consecutive_failures:
                        print("Browser appears to have closed or crashed, shutting down...", flush=True)
                        self.running = False
                        break
    
    async def run_server(self):
        """Run the server with health monitoring."""
        if not self.acquire_lock():
            print("Another server instance is running, exiting.", flush=True)
            return
        
        try:
            SOCKET_PATH.unlink(missing_ok=True)
            
            print("Starting browser...", flush=True)
            try:
                await self.start_browser()
            except Exception as e:
                print(f"FATAL: Failed to start browser: {e}", flush=True)
                import traceback
                traceback.print_exc()
                return
            
            if not await self.is_browser_alive():
                print("FATAL: Browser started but is not responsive", flush=True)
                return
            
            server = await asyncio.start_unix_server(
                self.handle_client,
                path=str(SOCKET_PATH)
            )
            
            PID_PATH.write_text(str(os.getpid()))
            
            print(f"Server running (PID: {os.getpid()}, idle timeout: {IDLE_TIMEOUT_SECONDS}s)", flush=True)
            
            def shutdown_handler(sig, frame):
                print(f"Received signal {sig}, shutting down...", flush=True)
                self.running = False
            
            signal.signal(signal.SIGTERM, shutdown_handler)
            signal.signal(signal.SIGINT, shutdown_handler)
            
            health_task = asyncio.create_task(self.health_check_loop())
            
            try:
                while self.running:
                    await asyncio.sleep(0.1)
            finally:
                health_task.cancel()
                try:
                    await health_task
                except asyncio.CancelledError:
                    pass
                
                server.close()
                await server.wait_closed()
                
                if self.session:
                    await self._persist_storage_state()
                    try:
                        await self.session.stop()
                    except:
                        pass
                
                if not wait_for_chrome_exit():
                    force_kill_chrome()
                
                print("Server stopped.", flush=True)
        finally:
            SOCKET_PATH.unlink(missing_ok=True)
            PID_PATH.unlink(missing_ok=True)
            CHROME_PID_PATH.unlink(missing_ok=True)
            self.release_lock()


def start_server_daemon(headed: bool):
    """Start server as background subprocess."""
    kill_existing_server()
    
    if getattr(sys, 'frozen', False):
        exe_path = sys.executable
    else:
        exe_path = sys.executable
    
    if getattr(sys, 'frozen', False):
        cmd = [exe_path, '--server']
    else:
        cmd = [exe_path, __file__, '--server']
    
    if headed:
        cmd.append('--headed')
    else:
        cmd.append('--headless')
    
    log_file = open(str(LOG_PATH), 'w')
    
    proc = subprocess.Popen(
        cmd,
        stdout=log_file,
        stderr=log_file,
        start_new_session=not headed,
    )
    
    for _ in range(150):
        time.sleep(0.1)
        if SOCKET_PATH.exists():
            time.sleep(0.5)
            return True
    
    if proc.poll() is not None:
        print(f"Server process exited with code {proc.returncode}", file=sys.stderr)
        try:
            with open(str(LOG_PATH), 'r') as f:
                log_content = f.read()
                if log_content:
                    print(f"Server log:\n{log_content}", file=sys.stderr)
        except:
            pass
        return False
    
    return False


def run_server_mode(headed: bool):
    """Run server directly (called with --server flag)."""
    import traceback
    try:
        print(f"Server starting... headed={headed}", flush=True)
        server = BrowserServer(headed=headed)
        asyncio.run(server.run_server())
    except Exception as e:
        print(f"Server error: {e}", flush=True)
        traceback.print_exc()
    finally:
        print("Server exiting", flush=True)
        if not wait_for_chrome_exit():
            force_kill_chrome()
        SOCKET_PATH.unlink(missing_ok=True)
        PID_PATH.unlink(missing_ok=True)
        CHROME_PID_PATH.unlink(missing_ok=True)
        LOCK_PATH.unlink(missing_ok=True)


def main():
    if '--server' in sys.argv:
        headed = '--headed' in sys.argv
        run_server_mode(headed)
        return
    
    parser = argparse.ArgumentParser(description="Browser automation CLI with persistent sessions")
    parser.add_argument("--headed", action="store_true", default=True, help="Run browser in headed mode (default)")
    parser.add_argument("--headless", action="store_true", help="Run browser in headless mode")
    parser.add_argument("--json", action="store_true", help="Output JSON only (no extra messages)")
    
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    p_open = subparsers.add_parser("open", help="Navigate to URL (starts browser if needed)")
    p_open.add_argument("url", help="URL to open")
    
    subparsers.add_parser("state", help="Get page state with clickable elements")
    
    p_click = subparsers.add_parser("click", help="Click element by index")
    p_click.add_argument("index", type=int, help="Element index from state")
    
    p_input = subparsers.add_parser("input", help="Click element and type text")
    p_input.add_argument("index", type=int, help="Element index")
    p_input.add_argument("text", help="Text to type")
    
    p_type = subparsers.add_parser("type", help="Type into currently focused element")
    p_type.add_argument("text", help="Text to type")
    
    p_keys = subparsers.add_parser("keys", help="Press keyboard key")
    p_keys.add_argument("key", help="Key name (Enter, Tab, Escape, etc.)")
    
    p_scroll = subparsers.add_parser("scroll", help="Scroll page")
    p_scroll.add_argument("direction", choices=["up", "down"], help="Scroll direction")
    
    subparsers.add_parser("back", help="Go back in browser history")
    
    subparsers.add_parser("refresh", help="Refresh current page")
    
    p_ss = subparsers.add_parser("screenshot", help="Take screenshot")
    p_ss.add_argument("filename", nargs="?", help="Output filename (optional)")
    
    subparsers.add_parser("close", help="Close browser and stop server")
    
    subparsers.add_parser("tabs", help="List all open tabs")
    
    p_switch = subparsers.add_parser("switch", help="Switch to tab by index")
    p_switch.add_argument("index", type=int, help="Tab index (from tabs command)")
    
    p_wait = subparsers.add_parser("wait", help="Wait for user action (login, captcha)")
    p_wait.add_argument("seconds", type=int, nargs="?", default=30, help="Seconds to wait (default 30)")
    p_wait.add_argument("--message", "-m", help="Message to display")
    
    subparsers.add_parser("sessions", help="List active sessions")
    
    subparsers.add_parser("kill", help="Force kill server and Chrome processes")
    
    # Agent mode commands
    p_agent_task = subparsers.add_parser("agent_task", help="Start autonomous agent task")
    p_agent_task.add_argument("task", help="Task description for the agent")
    p_agent_task.add_argument("--max-steps", type=int, default=50, help="Maximum steps (default 50)")
    p_agent_task.add_argument("--model", default="auto", 
                              choices=["auto", "anthropic", "openai", "browser-use"],
                              help="LLM to use (default: auto-detect from API key)")
    
    p_agent_continue = subparsers.add_parser("agent_continue", help="Continue agent with user choice")
    p_agent_continue.add_argument("choice", help="User's selected option")
    
    subparsers.add_parser("agent_status", help="Get agent task status")
    
    subparsers.add_parser("agent_cancel", help="Cancel running agent task")
    
    args = parser.parse_args()
    headed = not args.headless
    
    if args.command == "kill":
        kill_existing_server()
        force_kill_chrome()
        print(json.dumps({"success": True, "message": "Server and Chrome killed"}))
        return
    
    params = {}
    if args.command == "open":
        params["url"] = args.url
    elif args.command == "click":
        params["index"] = args.index
    elif args.command == "input":
        params["index"] = args.index
        params["text"] = args.text
    elif args.command == "type":
        params["text"] = args.text
    elif args.command == "keys":
        params["key"] = args.key
    elif args.command == "scroll":
        params["direction"] = args.direction
    elif args.command == "screenshot":
        params["filename"] = args.filename
    elif args.command == "switch":
        params["index"] = args.index
    elif args.command == "wait":
        params["seconds"] = args.seconds
        params["message"] = getattr(args, 'message', None) or ""
    elif args.command == "agent_task":
        params["task"] = args.task
        params["max_steps"] = getattr(args, 'max_steps', 50)
        params["model"] = getattr(args, 'model', 'anthropic')
    elif args.command == "agent_continue":
        params["choice"] = args.choice
    elif args.command == "sessions":
        if is_server_running():
            print(json.dumps({"sessions": ["default"]}))
        else:
            print(json.dumps({"sessions": []}))
        return
    
    if not is_server_running():
        if args.command == "close":
            print(json.dumps({"success": True, "message": "No server running"}))
            return
        
        if not args.json:
            print("Starting browser server...", file=sys.stderr)
        
        if not start_server_daemon(headed):
            print(json.dumps({"error": "Failed to start server"}))
            sys.exit(1)
        
        if not args.json:
            print("Server started.", file=sys.stderr)
    
    try:
        request = {"command": args.command, "params": params}
        result = send_to_server(request)
        print(json.dumps(result, ensure_ascii=False))
        
        if "error" in result:
            sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": f"Failed to communicate with server: {e}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()
