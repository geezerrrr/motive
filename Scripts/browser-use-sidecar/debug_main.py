#!/usr/bin/env python3
"""Debug script to test socksio import in PyInstaller bundle"""

import os
import sys

print("=== Debug: Testing socksio import ===")

# Try importing socksio
try:
    import socksio
    print(f"SUCCESS: socksio imported from {socksio.__file__}")
except ImportError as e:
    print(f"FAILED: socksio import error: {e}")

# Try importing socksio.socks5
try:
    import socksio.socks5
    print("SUCCESS: socksio.socks5 imported")
except ImportError as e:
    print(f"FAILED: socksio.socks5 import error: {e}")

# Try importing httpcore socks
try:
    import httpcore._sync.socks_proxy
    print("SUCCESS: httpcore._sync.socks_proxy imported")
except ImportError as e:
    print(f"FAILED: httpcore socks import error: {e}")

# Now try to actually create httpx client with proxy
print("\n=== Testing httpx with SOCKS proxy ===")
try:
    import httpx
    # Force create a transport with SOCKS proxy
    from httpx._transports.default import HTTPTransport
    proxy = httpx.Proxy("socks5://127.0.0.1:7897")
    transport = HTTPTransport(proxy=proxy)
    print("SUCCESS: HTTPTransport with SOCKS proxy created")
except ImportError as e:
    print(f"FAILED: {e}")
except Exception as e:
    print(f"OTHER ERROR: {type(e).__name__}: {e}")

print("\n=== Done ===")
