#!/usr/bin/env python3
"""Test if socksio can be imported"""
import sys

try:
    import socksio
    print(f"SUCCESS: socksio imported from {socksio.__file__}")
    print(f"socksio version: {getattr(socksio, '__version__', 'unknown')}")
except ImportError as e:
    print(f"FAILED to import socksio: {e}")
    sys.exit(1)

try:
    import httpcore._sync.socks_proxy
    print("SUCCESS: httpcore socks_proxy imported")
except ImportError as e:
    print(f"FAILED to import httpcore socks: {e}")

print("All imports OK!")
