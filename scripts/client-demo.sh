#!/bin/sh
# Client-side demo script
# Run this INSIDE the client container to demonstrate anycast behavior
# Usage: sudo docker exec -it clab-anycast-lab-client1 sh /client-demo.sh

ANYCAST_IP="203.0.113.10"

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
    echo ""
}

print_step() {
    echo ">>> $1"
}

print_header "Anycast Service Demo from Client"

print_step "1. Testing connectivity to anycast IP: $ANYCAST_IP"
echo ""

if ping -c 3 -W 2 $ANYCAST_IP > /dev/null 2>&1; then
    echo "✓ Anycast IP is reachable"
else
    echo "✗ Cannot reach anycast IP"
    exit 1
fi

print_step "2. Making 10 HTTP requests to show consistent routing"
echo ""

for i in $(seq 1 10); do
    RESPONSE=$(curl -s http://$ANYCAST_IP 2>/dev/null)
    REGION=$(echo "$RESPONSE" | grep -o "Region [AB]" | head -1)
    POP=$(echo "$RESPONSE" | grep -o "POP[12]" | head -1)
    
    if [ -n "$REGION" ]; then
        printf "Request %2d: %s via %s\n" $i "$REGION" "$POP"
    else
        printf "Request %2d: FAILED\n" $i
    fi
    
    sleep 0.5
done

echo ""
print_step "3. Showing full response from one request"
echo ""

curl -s http://$ANYCAST_IP

echo ""
echo ""
print_header "Demo Complete"

echo "What you're seeing:"
echo "  • All requests go to the SAME region (best BGP path)"
echo "  • The edge PoP proxies requests to backend servers"
echo "  • Response shows which region served your request"
echo ""
echo "To test failover:"
echo "  • Run: bash scripts/demo-failover.sh (from host)"
echo "  • Or manually kill BGP on active PoP"
echo "  • Traffic will automatically switch to backup region"
echo ""
