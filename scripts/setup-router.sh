#!/bin/sh
# Startup script for router

# Wait for interfaces to be ready
sleep 2

# Configure network interfaces
ip addr add 10.0.0.1/24 dev eth1
ip addr add 10.0.1.1/24 dev eth2
ip addr add 10.0.2.1/24 dev eth3

# Start FRR
sleep 1
/usr/lib/frr/frrinit.sh start

echo "router setup complete"
