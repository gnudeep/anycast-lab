#!/bin/bash
# Health check script for anycast lab

echo "========================================="
echo "Anycast Lab Health Check"
echo "========================================="
echo ""

# Check if lab is running
if ! sudo containerlab inspect -t anycast-lab.yml &>/dev/null; then
    echo "❌ Lab is not running. Deploy with: sudo containerlab deploy -t anycast-lab.yml"
    exit 1
fi

echo "✓ Lab is running"
echo ""

# Check BGP status
echo "=== BGP Status ==="
BGP_OUTPUT=$(sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp summary" 2>/dev/null | grep -E "10.0.1.2|10.0.2.2")
if echo "$BGP_OUTPUT" | grep -q "Established\|[0-9]"; then
    echo "✓ BGP sessions established"
    echo "$BGP_OUTPUT"
else
    echo "❌ BGP sessions not established"
fi
echo ""

# Check routes
echo "=== Anycast Route ==="
ROUTE_OUTPUT=$(sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp 203.0.113.10/32" 2>/dev/null)
if echo "$ROUTE_OUTPUT" | grep -q "best"; then
    BEST_PATH=$(echo "$ROUTE_OUTPUT" | grep "best" | grep -oE "65001|65002")
    if [ "$BEST_PATH" = "65001" ]; then
        echo "✓ Best path: pop1 (AS 65001) → Region A"
    else
        echo "✓ Best path: pop2 (AS 65002) → Region B"
    fi
else
    echo "❌ No route to anycast IP"
fi
echo ""

# Check proxy services
echo "=== Proxy Services ==="
POP1_PROXY=$(sudo docker exec clab-anycast-lab-pop1 netstat -tlnp 2>/dev/null | grep "203.0.113.10:80" | grep socat)
POP2_PROXY=$(sudo docker exec clab-anycast-lab-pop2 netstat -tlnp 2>/dev/null | grep "203.0.113.10:80" | grep socat)

if [ -n "$POP1_PROXY" ]; then
    echo "✓ pop1 proxy is running"
else
    echo "❌ pop1 proxy is not running"
fi

if [ -n "$POP2_PROXY" ]; then
    echo "✓ pop2 proxy is running"
else
    echo "❌ pop2 proxy is not running"
fi
echo ""

# Test HTTP connectivity
echo "=== HTTP Connectivity Test ==="
HTTP_RESPONSE=$(sudo docker exec clab-anycast-lab-client1 curl -s -m 5 http://203.0.113.10 2>/dev/null)
if echo "$HTTP_RESPONSE" | grep -q "Welcome to Region"; then
    REGION=$(echo "$HTTP_RESPONSE" | grep -o "Region [AB]" | head -1)
    echo "✓ HTTP service is working"
    echo "  Response from: $REGION"
else
    echo "❌ HTTP service is not responding"
fi
echo ""

# Summary
echo "========================================="
echo "Health Check Complete"
echo "========================================="
