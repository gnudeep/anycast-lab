# Anycast DR Lab

This is a Containerlab-based network topology demonstrating anycast IP routing with disaster recovery (DR) capabilities using BGP and FRR (Free Range Routing).

## Overview

The lab simulates an anycast architecture where multiple Points of Presence (PoPs) advertise the same IP address (`203.0.113.10/32`) to a central router. This setup enables:

- **Load distribution**: Traffic naturally flows to the closest PoP based on routing metrics
- **High availability**: If one PoP fails, traffic automatically routes to the remaining PoP(s)
- **Disaster recovery**: Geographic redundancy across multiple regions

## Topology

```
                    ┌─────────────┐
                    │   client1   │
                    │ 10.0.0.2/24 │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │   router    │
                    │  10.0.0.1   │ (AS 65000)
                    │  10.0.1.1   │
                    │  10.0.2.1   │
                    └──┬───────┬──┘
                       │       │
           ┌───────────┘       └───────────┐
           │                               │
    ┌──────┴──────┐                  ┌─────┴───────┐
    │    pop1     │                  │    pop2     │
    │ 10.0.1.2/24 │ (AS 65001)       │ 10.0.2.2/24 │ (AS 65002)
    │ 10.10.1.1   │                  │ 10.20.1.1   │
    │ 203.0.113.10│                  │ 203.0.113.10│
    └──────┬──────┘                  └──────┬──────┘
           │                                │
    ┌──────┴──────┐                  ┌─────┴───────┐
    │   regionA   │                  │   regionB   │
    │ 10.10.1.10  │                  │ 10.20.1.10  │
    └─────────────┘                  └─────────────┘
```

### Components

- **router**: Central BGP router (AS 65000) that receives anycast routes from both PoPs
- **pop1**: Point of Presence 1 in Region A (AS 65001) advertising `203.0.113.10/32`
- **pop2**: Point of Presence 2 in Region B (AS 65002) advertising `203.0.113.10/32`
- **regionA/regionB**: Backend servers (nginx) in each region
- **client1**: Test client to verify anycast routing

## Prerequisites

### Required Software

- **Operating System**: Linux (tested on Ubuntu/Debian)
- **Docker**: v20.10+ (tested with v27.5.1)
- **Containerlab**: v0.50+ (tested with v0.71.1)
- **Sudo/root access**: Required for containerlab and Docker operations

### Tested Versions

| Component    | Version      | Purpose                          |
|--------------|--------------|----------------------------------|
| Containerlab | 0.71.1       | Network topology orchestration   |
| Docker       | 27.5.1       | Container runtime                |
| FRR          | 8.4          | BGP routing daemon               |
| Nginx        | 1.29.3       | Backend web servers              |
| Alpine Linux | 3.22.2       | Client container OS              |

### Installation

If you don't have the prerequisites installed:

```bash
# Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Containerlab
bash -c "$(curl -sL https://get.containerlab.dev)"

# Verify installations
docker --version
containerlab version
```

## Deployment

### Quick Start

```bash
# Deploy the lab
sudo containerlab deploy -t anycast-lab.yml

# Wait for BGP convergence (30 seconds)
sleep 30

# Run health check
bash scripts/health-check.sh

# Test HTTP connectivity
sudo docker exec clab-anycast-lab-client1 curl http://203.0.113.10
```

All configurations are applied automatically via startup scripts in the `scripts/` directory. No manual configuration required!

### Automated Setup

The lab uses automated setup scripts that run on container startup:

- **setup-router.sh**: Configures router interfaces and starts FRR/BGP
- **setup-pop1.sh**: Configures pop1 network, FRR, and socat proxy to regionA
- **setup-pop2.sh**: Configures pop2 network, FRR, and socat proxy to regionB
- **setup-client.sh**: Configures client routing and installs utilities
- **setup-region.sh**: Configures backend servers with custom HTML pages

See `scripts/README.md` for detailed information about each script.

### Health Check Script

The health check script validates the entire lab deployment:

```bash
bash scripts/health-check.sh
```

This verifies:
- ✅ Lab deployment status
- ✅ BGP session establishment
- ✅ Route advertisements and best path selection
- ✅ Socat proxy services on both PoPs
- ✅ End-to-end HTTP connectivity

**Expected output:**
```
=========================================
Anycast Lab Health Check
=========================================

✓ Lab is running

=== BGP Status ===
✓ BGP sessions established
10.0.1.2        4      65001  ...  1 (Policy) N/A
10.0.2.2        4      65002  ...  1 (Policy) N/A

=== Anycast Route ===
✓ Best path: pop1 (AS 65001) → Region A

=== Proxy Services ===
✓ pop1 proxy is running
✓ pop2 proxy is running

=== HTTP Connectivity Test ===
✓ HTTP service is working
  Response from: Region A

=========================================
Health Check Complete
=========================================
```

### Manual Verification

If you want to verify components manually:

```bash
# Check BGP sessions on router
sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp summary"

# Check received routes
sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp"

# Check which path is selected as best
sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp 203.0.113.10/32"

# Check routing table
sudo docker exec clab-anycast-lab-router vtysh -c "show ip route 203.0.113.10/32"

# Verify proxy is running on pop1
sudo docker exec clab-anycast-lab-pop1 ps aux | grep socat

# Check proxy logs
sudo docker exec clab-anycast-lab-pop1 cat /var/log/socat.log
```

### Test Anycast Routing

```bash
# From client, ping the anycast IP
sudo docker exec clab-anycast-lab-client1 ping -c 4 203.0.113.10

# Trace route to see which PoP is being used
sudo docker exec clab-anycast-lab-client1 traceroute 203.0.113.10

# Access the web service on the anycast IP
sudo docker exec clab-anycast-lab-client1 curl http://203.0.113.10
```

**Expected HTTP Response:**

The response shows which regional backend server handled your request:

```html
<!DOCTYPE html><html><head><title>Region A</title></head>
<body>
  <h1>Welcome to Region A</h1>
  <p>You are connected to the backend server in Region A</p>
  <p>Anycast IP: 203.0.113.10</p>
  <p>Served via POP1</p>
</body></html>
```

You'll see either "Region A" (via pop1) or "Region B" (via pop2) depending on which BGP path is selected as best.

**Validation Steps:**

1. **Check BGP Path Selection:**
   ```bash
   sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp 203.0.113.10/32"
   ```
   
   Expected output shows both paths with one marked as "best":
   ```
   BGP routing table entry for 203.0.113.10/32
   Paths: (2 available, best #1, table default)
     65001
       10.0.1.2 from 10.0.1.2 (10.0.1.2)
         Origin IGP, metric 0, valid, external, best (Older Path)
     65002
       10.0.2.2 from 10.0.2.2 (10.0.2.2)
         Origin IGP, metric 0, valid, external
   ```

2. **Verify Active Path:**
   ```bash
   sudo docker exec clab-anycast-lab-router vtysh -c "show ip route 203.0.113.10/32"
   ```
   
   Expected output:
   ```
   B>* 203.0.113.10/32 [20/0] via 10.0.1.2, eth2, weight 1, 00:05:23
   ```
   The ">" indicates the active route installed in the routing table.

3. **Test Multiple Times:**
   ```bash
   for i in {1..5}; do 
     sudo docker exec clab-anycast-lab-client1 curl -s http://203.0.113.10 | grep -o "Region [AB]"
   done
   ```
   
   All requests should consistently go to the same region (the one with the best BGP path).

### Test DR Failover

This demonstrates automatic disaster recovery when a PoP fails:

```bash
# Kill BGP on pop1 to simulate failure
sudo docker exec clab-anycast-lab-pop1 pkill bgpd

# Wait for BGP to detect the failure and converge (10-15 seconds)
sleep 10

# Verify router now uses pop2 as best path (automatic failover)
sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp 203.0.113.10/32"
```

**Expected failover behavior:**

1. BGP session from router to pop1 goes down
2. Router marks the path via pop1 as invalid
3. Router automatically switches to pop2 as the new best path
4. All traffic now flows through pop2 to regionB

**Validate failover:**

```bash
# Check BGP sessions - pop1 should be down
sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp summary"

# Expected output shows pop1 session in "Active" or "Idle" state:
# 10.0.1.2    4   65001   ...   Active
# 10.0.2.2    4   65002   ...   1        (now best path)

# Traffic should still reach the anycast IP via pop2
sudo docker exec clab-anycast-lab-client1 ping -c 4 203.0.113.10

# Web service should now respond from pop2/regionB backend
sudo docker exec clab-anycast-lab-client1 curl http://203.0.113.10 | grep -o "Region [AB]"
# Expected output: Region B
```

**Restore the failed PoP:**

```bash
# Restart FRR on pop1
sudo docker exec clab-anycast-lab-pop1 /usr/lib/frr/frrinit.sh start

# Wait for BGP to re-establish (10-15 seconds)
sleep 15

# Verify both paths are available again
sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp summary"

# Expected output shows both sessions established:
# 10.0.1.2    4   65001   ...   1
# 10.0.2.2    4   65002   ...   1

# Check which path is now best
sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp 203.0.113.10/32"

# Note: After restoration, pop2 may remain the best path due to 
# the "Older Path" tie-breaker (it's been active longer)
```

**Failover Timing:**

- **Detection**: ~10 seconds (BGP hold time)
- **Convergence**: ~1-2 seconds (route recalculation)
- **Total Downtime**: ~10-15 seconds for automatic failover

**Key Observations:**

1. Failover is fully automatic - no manual intervention needed
2. The anycast IP remains reachable during and after failover
3. Applications see transparent failover to the backup region
4. When both paths are available, BGP selects best based on tie-breakers
5. "Older Path" tie-breaker provides stability (prevents flapping)

### Modify Path Selection

To prefer pop2 over pop1 using Local Preference (higher value wins):

```bash
# On router, create a route-map to prefer pop2
sudo docker exec clab-anycast-lab-router vtysh -c "configure terminal" \
  -c "route-map PREFER_POP2 permit 10" \
  -c "set local-preference 200" \
  -c "exit" \
  -c "route-map ACCEPT_ALL permit 10" \
  -c "exit" \
  -c "router bgp 65000" \
  -c "address-family ipv4 unicast" \
  -c "neighbor 10.0.2.2 route-map PREFER_POP2 in" \
  -c "exit-address-family"

# Clear BGP to apply changes
sudo docker exec clab-anycast-lab-router vtysh -c "clear ip bgp * soft in"

# Verify pop2 is now best path (Local Pref 200 vs default 100)
sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp 203.0.113.10/32"
```

### Cleanup

```bash
sudo containerlab destroy -t anycast-lab.yml
```

## Configuration Details

### Router (AS 65000)

- **Role**: Central transit router
- **BGP Peers**: 
  - pop1 (10.0.1.2, AS 65001)
  - pop2 (10.0.2.2, AS 65002)
- **Routing Policy**: Accepts all routes from PoPs via `ACCEPT_ALL` route-map
- **Path Selection**: Uses standard BGP best path selection algorithm

Configuration file: `router/frr.conf`

#### BGP Best Path Selection

When the router learns the same route (`203.0.113.10/32`) from both pop1 and pop2, it uses the BGP best path selection algorithm to choose which path to install in the routing table:

1. **Highest Weight** (Cisco-specific, not used in FRR by default)
2. **Highest Local Preference** (default: 100, same for both paths)
3. **Locally Originated Routes** (neither path is locally originated)
4. **Shortest AS Path** (both paths have AS path length of 1: either 65001 or 65002)
5. **Lowest Origin Type** (both are IGP origin, same)
6. **Lowest MED** (Multi-Exit Discriminator) (not set, defaults to 0 for both)
7. **eBGP over iBGP** (both are eBGP, same)
8. **Lowest IGP Metric to Next-Hop** (both next-hops are directly connected, same cost)
9. **Oldest Route** (tie-breaker for stability)
10. **Lowest Router ID** (**This is the deciding factor**)
    - pop1 router ID: `10.0.1.2`
    - pop2 router ID: `10.0.2.2`
    - **Winner: pop1** (10.0.1.2 < 10.0.2.2)
11. Lowest Neighbor Address (only if router IDs are identical)

In this lab, since all other attributes are equal, the router selects **pop1** as the best path because it has the lower router ID (`10.0.1.2`). The route via pop2 is kept as a backup path in the BGP table but not installed in the FIB.

**Verification:**
```bash
# View BGP paths with the best path marked with ">"
sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp 203.0.113.10/32"

# Output shows:
# *> via 10.0.1.2 (pop1) - best path, installed in routing table
# *  via 10.0.2.2 (pop2) - valid backup path
```

**To influence path selection**, you can use:
- **Local Preference** (higher wins): Set on inbound routes to prefer one PoP
- **AS Path Prepending**: Have one PoP prepend its AS to make the path longer
- **MED (Metric)**: Have PoPs advertise different MEDs (lower wins)
- **Weight** (FRR/Cisco): Set locally on the router for specific neighbors

### Pop1 (AS 65001)

- **Role**: Regional PoP in Region A
- **BGP Peer**: router (10.0.1.1, AS 65000)
- **Advertised Routes**: `203.0.113.10/32` (anycast IP on loopback)
- **Routing Policy**: Advertises routes via `ALLOW_OUT` route-map
- **Backend**: Connected to regionA servers

Configuration file: `pop1/frr.conf`

### Pop2 (AS 65002)

- **Role**: Regional PoP in Region B
- **BGP Peer**: router (10.0.2.1, AS 65000)
- **Advertised Routes**: `203.0.113.10/32` (anycast IP on loopback)
- **Routing Policy**: Advertises routes via `ALLOW_OUT` route-map
- **Backend**: Connected to regionB servers

Configuration file: `pop2/frr.conf`

## Key Configuration Concepts

### Anycast IP Assignment

Both pop1 and pop2 have the same IP address (`203.0.113.10/32`) assigned to their loopback interfaces:

```bash
ip addr add 203.0.113.10/32 dev lo
```

This same IP is then advertised via BGP, allowing the router to choose the best path based on routing metrics.

### Web Service Proxying to Backend Servers

Each PoP runs **socat** as a TCP proxy on the anycast IP (`203.0.113.10:80`) that forwards requests to backend nginx servers:
- **pop1** (`203.0.113.10`) → proxies to → **regionA** (`10.10.1.10`)
- **pop2** (`203.0.113.10`) → proxies to → **regionB** (`10.20.1.10`)

This demonstrates a realistic anycast architecture where:
- Edge PoPs (pop1/pop2) advertise the anycast IP via BGP
- Client requests reach the "nearest" PoP (best BGP path)
- PoPs proxy/forward requests to regional backend servers
- Services remain available even if one PoP fails (automatic DR failover)
- Backend servers can be scaled independently from the anycast layer

### Return Path Routing

For bidirectional communication to work, PoPs need routes back to the client network:
```bash
# On pop1 and pop2
ip route add 10.0.0.0/24 via 10.0.x.1
```

This ensures that response packets can find their way back to the client through the router.

### eBGP Peering

External BGP (eBGP) is used between different autonomous systems:
- Router ↔ Pop1: AS 65000 ↔ AS 65001
- Router ↔ Pop2: AS 65000 ↔ AS 65002

### Route-Maps

**Important**: FRR 8.4 requires explicit outbound route-maps for eBGP neighbors. Without them, routes won't be advertised even if they're in the BGP table.

- `ACCEPT_ALL` (router): Permits all incoming routes from PoPs
- `ALLOW_OUT` (pop1/pop2): Permits outbound route advertisements to router

## Troubleshooting

If routes are not being received, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed diagnostic steps.

### Common Issues

1. **No routes received from PoPs**: Check for missing outbound route-maps on pop1/pop2
2. **BGP session not established**: Verify IP connectivity and correct neighbor IPs
3. **Routes in BGP table but not in routing table**: Check for route filtering or invalid next-hops

### Useful Commands

```bash
# Access FRR shell on any node
sudo docker exec -it clab-anycast-lab-<node> vtysh

# View BGP configuration
show running-config

# Check BGP neighbor details
show bgp neighbor <ip>

# View BGP routes with details and see which path is selected
show ip bgp <prefix>

# Check which PoP is currently serving traffic
sudo docker exec clab-anycast-lab-client1 curl -s http://203.0.113.10

# View detailed BGP path selection for the anycast route
sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp 203.0.113.10/32"

# Enable BGP debugging
debug bgp updates
debug bgp neighbor-events

# Reset BGP sessions
clear ip bgp *
clear ip bgp * soft [in|out]
```

## Network Addressing

| Node    | Interface | IP Address      | Purpose                    |
|---------|-----------|-----------------|----------------------------|
| router  | eth1      | 10.0.0.1/24     | Client-facing network      |
| router  | eth2      | 10.0.1.1/24     | Transit to pop1            |
| router  | eth3      | 10.0.2.1/24     | Transit to pop2            |
| pop1    | eth1      | 10.0.1.2/24     | Transit to router          |
| pop1    | eth2      | 10.10.1.1/24    | Backend (Region A)         |
| pop1    | lo        | 203.0.113.10/32 | Anycast IP                 |
| pop2    | eth1      | 10.0.2.2/24     | Transit to router          |
| pop2    | eth2      | 10.20.1.1/24    | Backend (Region B)         |
| pop2    | lo        | 203.0.113.10/32 | Anycast IP                 |
| client1 | eth1      | 10.0.0.2/24     | Client network             |
| regionA | eth1      | 10.10.1.10/24   | Region A backend           |
| regionB | eth1      | 10.20.1.10/24   | Region B backend           |

## Use Cases

This lab demonstrates patterns useful for:

- **Global content delivery**: Route users to the nearest edge location
- **Distributed services**: DNS, API endpoints, load balancers
- **Multi-region applications**: Geographic redundancy with automatic failover
- **DDoS mitigation**: Distribute attack traffic across multiple locations
- **Latency optimization**: Minimize round-trip time by routing to nearest PoP

## References

- [FRRouting Documentation](https://docs.frrouting.org/)
- [Containerlab Documentation](https://containerlab.dev/)
- [BGP RFC 4271](https://www.rfc-editor.org/rfc/rfc4271)
- [Anycast Overview (Cloudflare)](https://www.cloudflare.com/learning/cdn/glossary/anycast-network/)
