#!/bin/sh
# Startup script for client1

# Install required packages
apk add --no-cache curl iproute2 bind-tools > /dev/null 2>&1

# Configure network interface
ip addr add 10.0.0.2/24 dev eth1

# Remove default route if exists and add route via router
ip route del default 2>/dev/null || true
ip route add default via 10.0.0.1

echo "client1 setup complete"
