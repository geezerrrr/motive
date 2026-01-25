"""PyInstaller runtime hook for browser-use-sidecar.

This hook runs BEFORE any other code in the bundled application,
including when subprocess spawns a new Python instance.

It handles:
1. Disabling system proxy detection (prevents SOCKS proxy errors)
2. Fixing importlib.resources for PyInstaller (for loading prompt templates)
"""
import urllib.request
import os
import sys

# Monkey-patch getproxies to return empty dict, disabling all system proxy detection
# This is necessary because macOS reads proxy settings from System Configuration
# framework, which httpx/urllib uses, causing SOCKS proxy errors.
urllib.request.getproxies = lambda: {}

# Clear proxy environment variables
for var in ['ALL_PROXY', 'all_proxy', 'HTTP_PROXY', 'http_proxy',
            'HTTPS_PROXY', 'https_proxy', 'SOCKS_PROXY', 'socks_proxy']:
    os.environ.pop(var, None)

# Fix importlib.resources for PyInstaller bundled applications
# PyInstaller extracts data files to sys._MEIPASS, but importlib.resources
# doesn't know about this. We need to patch it to find the prompt templates.
def _fix_importlib_resources():
    """Patch importlib.resources.files to work with PyInstaller."""
    if not getattr(sys, 'frozen', False):
        return  # Not running from PyInstaller, no fix needed
    
    import importlib.resources
    from pathlib import Path
    
    # Get the directory where PyInstaller extracts files
    meipass = getattr(sys, '_MEIPASS', None)
    if not meipass:
        return
    
    # Save original function
    _original_files = importlib.resources.files
    
    def patched_files(package):
        """Patched version of importlib.resources.files for PyInstaller."""
        # Convert package name to path (e.g., 'browser_use.agent.system_prompts' -> 'browser_use/agent/system_prompts')
        if isinstance(package, str):
            package_path = package.replace('.', '/')
            pyinstaller_path = Path(meipass) / package_path
            
            # If the path exists in PyInstaller's temp directory, use it
            if pyinstaller_path.exists():
                return pyinstaller_path
        
        # Fall back to original behavior
        try:
            return _original_files(package)
        except Exception:
            # If original also fails, try PyInstaller path again
            if isinstance(package, str):
                return Path(meipass) / package.replace('.', '/')
            raise
    
    importlib.resources.files = patched_files

_fix_importlib_resources()
