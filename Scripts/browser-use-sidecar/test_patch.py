#!/usr/bin/env python3
"""Test if getproxies patch works"""
import urllib.request

# Patch getproxies
urllib.request.getproxies = lambda: {}

# Verify patch
from urllib.request import getproxies
print(f"getproxies() = {getproxies()}")

# Now test httpx
import httpx
print("httpx imported successfully")

# Try to get environment proxies
from httpx._utils import get_environment_proxies
print(f"get_environment_proxies() = {get_environment_proxies()}")

# Try creating a client
client = httpx.Client()
print("Client created successfully!")
client.close()
