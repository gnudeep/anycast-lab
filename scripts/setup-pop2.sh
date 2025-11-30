#!/bin/sh
# Startup script for pop2

# Wait for interfaces to be ready
sleep 2

# Configure network interfaces
ip addr add 10.0.2.2/24 dev eth1
ip addr add 10.20.1.1/24 dev eth2
ip addr add 203.0.113.10/32 dev lo

# Add route back to client network
ip route add 10.0.0.0/24 via 10.0.2.1

# Start FRR
sleep 1
/usr/lib/frr/frrinit.sh start

# Wait for FRR to start
sleep 3

# Install socat for proxying
apk add --no-cache socat > /dev/null 2>&1

# Start socat proxy to forward anycast IP traffic to regionB backend
nohup socat TCP4-LISTEN:80,bind=203.0.113.10,fork,reuseaddr TCP4:10.20.1.10:80 > /var/log/socat.log 2>&1 &

echo "pop2 setup complete"
