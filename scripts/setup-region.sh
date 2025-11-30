#!/bin/bash
# Startup script for regionA and regionB

REGION=$1
IP=$2

if [ "$REGION" = "A" ]; then
    CONTENT='<!DOCTYPE html><html><head><title>Region A</title></head><body><h1>Welcome to Region A</h1><p>You are connected to the backend server in Region A</p><p>Anycast IP: 203.0.113.10</p><p>Served via POP1</p></body></html>'
else
    CONTENT='<!DOCTYPE html><html><head><title>Region B</title></head><body><h1>Welcome to Region B</h1><p>You are connected to the backend server in Region B</p><p>Anycast IP: 203.0.113.10</p><p>Served via POP2</p></body></html>'
fi

# Wait for container to be ready
sleep 2

# Install iproute2
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq > /dev/null 2>&1
apt-get install -y iproute2 -qq > /dev/null 2>&1

# Configure network interface
ip addr add ${IP}/24 dev eth1

# Create custom index page
echo "$CONTENT" > /usr/share/nginx/html/index.html

echo "region${REGION} setup complete"
