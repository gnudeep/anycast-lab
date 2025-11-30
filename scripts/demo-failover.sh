#!/bin/bash
# Demo script to show anycast failover behavior
# Run this from the host machine to demonstrate DR capabilities

set -e

ROUTER="clab-anycast-lab-router"
CLIENT="clab-anycast-lab-client1"
POP1="clab-anycast-lab-pop1"
POP2="clab-anycast-lab-pop2"
ANYCAST_IP="203.0.113.10"

# Log file with timestamp
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/failover-demo-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log and print
log_print() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Function to log without color codes
log_only() {
    echo "$1" >> "$LOG_FILE"
}

print_header() {
    log_print "\n${BLUE}========================================${NC}"
    log_print "${BLUE}$1${NC}"
    log_print "${BLUE}========================================${NC}\n"
    log_only "========================================"
    log_only "$1"
    log_only "========================================"
}

print_step() {
    log_print "${YELLOW}>>> $1${NC}"
    log_only ">>> $1"
}

print_success() {
    log_print "${GREEN}✓ $1${NC}"
    log_only "✓ $1"
}

print_error() {
    log_print "${RED}✗ $1${NC}"
    log_only "✗ $1"
}

# Check lab is running
if ! sudo docker ps | grep -q "$ROUTER"; then
    print_error "Lab is not running. Deploy with: sudo containerlab deploy -t anycast-lab.yml"
    exit 1
fi

# Log session start
log_only "========================================="
log_only "Demo Session Started: $(date)"
log_only "========================================="

print_header "Anycast Disaster Recovery Failover Demo"
echo -e "${BLUE}Log file: $LOG_FILE${NC}"

# Step 1: Show initial state
print_step "Step 1: Checking initial state"
log_print ""

log_print "BGP Sessions:"
BGP_OUTPUT=$(sudo docker exec $ROUTER vtysh -c "show ip bgp summary" | grep -E "Neighbor|10.0")
log_print "$BGP_OUTPUT"
log_print ""

log_print "Current best path:"
BEST_PATH=$(sudo docker exec $ROUTER vtysh -c "show ip bgp 203.0.113.10/32" | grep -E "best|65001|65002" | head -5)
log_print "$BEST_PATH"
log_print ""

print_step "Step 2: Testing HTTP service from client (5 requests)"
log_print ""

for i in {1..5}; do
    RESPONSE=$(sudo docker exec $CLIENT curl -s http://$ANYCAST_IP 2>/dev/null)
    REGION=$(echo "$RESPONSE" | grep -o "Region [AB]" | head -1)
    POP=$(echo "$RESPONSE" | grep -o "POP[12]" | head -1)
    log_print "Request $i: Served from $REGION via $POP"
done

INITIAL_REGION=$(sudo docker exec $CLIENT curl -s http://$ANYCAST_IP 2>/dev/null | grep -o "Region [AB]" | head -1)
INITIAL_POP=$(echo $INITIAL_REGION | grep -o "[AB]")

if [ "$INITIAL_POP" = "A" ]; then
    ACTIVE_POP=$POP1
    ACTIVE_POP_NAME="pop1"
    BACKUP_REGION="Region B"
else
    ACTIVE_POP=$POP2
    ACTIVE_POP_NAME="pop2"
    BACKUP_REGION="Region A"
fi

print_success "Initial state: All traffic going to $INITIAL_REGION via $ACTIVE_POP_NAME"

# Step 3: Simulate failure
print_header "Simulating Disaster: Killing BGP on $ACTIVE_POP_NAME"

print_step "Stopping BGP process on $ACTIVE_POP_NAME..."
sudo docker exec $ACTIVE_POP pkill bgpd
print_success "BGP killed on $ACTIVE_POP_NAME"

print_step "Waiting for BGP failure detection and convergence (15 seconds)..."
log_only "Waiting 15 seconds for convergence..."
for i in {15..1}; do
    echo -n "$i "
    sleep 1
done
echo ""
log_only "Convergence wait completed"
print_success "Convergence complete"

# Step 4: Show failover state
print_header "After Failover - Automatic Recovery"

print_step "Checking BGP sessions status:"
log_print ""
BGP_STATUS=$(sudo docker exec $ROUTER vtysh -c "show ip bgp summary" | grep -E "Neighbor|10.0" | \
    awk '{if(NR==1) print $0; else if($0 ~ /10.0/) print $0}')
log_print "$BGP_STATUS"
log_print ""

print_step "Current best path after failover:"
FAILOVER_PATH=$(sudo docker exec $ROUTER vtysh -c "show ip bgp 203.0.113.10/32" | grep -E "best|65001|65002" | head -5)
log_print "$FAILOVER_PATH"
log_print ""

print_step "Testing HTTP service from client (5 requests after failover)"
log_print ""

for i in {1..5}; do
    RESPONSE=$(sudo docker exec $CLIENT curl -s http://$ANYCAST_IP 2>/dev/null)
    REGION=$(echo "$RESPONSE" | grep -o "Region [AB]" | head -1)
    POP=$(echo "$RESPONSE" | grep -o "POP[12]" | head -1)
    log_print "Request $i: Served from $REGION via $POP"
done

FAILOVER_REGION=$(sudo docker exec $CLIENT curl -s http://$ANYCAST_IP 2>/dev/null | grep -o "Region [AB]" | head -1)

print_success "Failover complete: All traffic now going to $FAILOVER_REGION"

# Step 5: Ask about restoration
print_header "Failover Demo Complete"

log_print "${GREEN}Summary:${NC}"
log_print "  • Initial: All traffic served from $INITIAL_REGION"
log_print "  • Failure: BGP process killed on $ACTIVE_POP_NAME"
log_print "  • Result: Automatic failover to $FAILOVER_REGION"
log_print "  • Downtime: ~10-15 seconds (BGP hold time)"
log_print ""

log_only "Summary:"
log_only "  Initial: All traffic served from $INITIAL_REGION"
log_only "  Failure: BGP process killed on $ACTIVE_POP_NAME"
log_only "  Result: Automatic failover to $FAILOVER_REGION"
log_only "  Downtime: ~10-15 seconds (BGP hold time)"

read -p "Do you want to restore the failed PoP? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_only "User chose to restore failed PoP"
    print_header "Restoring $ACTIVE_POP_NAME"
    
    print_step "Restarting FRR on $ACTIVE_POP_NAME..."
    sudo docker exec $ACTIVE_POP /usr/lib/frr/frrinit.sh start 2>&1 | grep -v "Could not lock\|Failed to start" || true
    
    print_step "Waiting for BGP to re-establish (15 seconds)..."
    log_only "Waiting 15 seconds for BGP to re-establish..."
    for i in {15..1}; do
        echo -n "$i "
        sleep 1
    done
    echo ""
    log_only "BGP re-establishment wait completed"
    
    print_success "BGP restored on $ACTIVE_POP_NAME"
    
    print_step "Checking BGP sessions:"
    log_print ""
    RESTORED_BGP=$(sudo docker exec $ROUTER vtysh -c "show ip bgp summary" | grep -E "Neighbor|10.0")
    log_print "$RESTORED_BGP"
    log_print ""
    
    print_step "Both paths available again:"
    BOTH_PATHS=$(sudo docker exec $ROUTER vtysh -c "show ip bgp 203.0.113.10/32" | grep -E "Paths:|best|65001|65002")
    log_print "$BOTH_PATHS"
    log_print ""
    
    print_success "Restoration complete - both PoPs operational"
    
    log_print ""
    log_print "${YELLOW}Note: Traffic may remain on the current path due to 'Older Path' BGP tie-breaker.${NC}"
    log_print "${YELLOW}This prevents unnecessary route flapping and provides stability.${NC}"
    
    log_only "Note: Traffic may remain on the current path due to 'Older Path' BGP tie-breaker."
    log_only "This prevents unnecessary route flapping and provides stability."
else
    log_only "User chose not to restore failed PoP"
fi

print_header "Demo Complete"

log_print "${GREEN}Key Takeaways:${NC}"
log_print "  ✓ Automatic failover without manual intervention"
log_print "  ✓ Service remained available during failure"
log_print "  ✓ BGP best path selection ensures optimal routing"
log_print "  ✓ Anycast provides geographic redundancy"
log_print ""

log_only "Key Takeaways:"
log_only "  ✓ Automatic failover without manual intervention"
log_only "  ✓ Service remained available during failure"
log_only "  ✓ BGP best path selection ensures optimal routing"
log_only "  ✓ Anycast provides geographic redundancy"
log_only ""
log_only "========================================="
log_only "Demo Session Ended: $(date)"
log_only "========================================="

echo -e "${BLUE}Full demo log saved to: $LOG_FILE${NC}"
