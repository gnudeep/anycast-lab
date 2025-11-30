# Troubleshooting: BGP Routes Not Being Received

## Issue Description

The router was not receiving BGP routes from pop1 and pop2, despite BGP sessions being established. The `show ip bgp summary` command showed `0 (Policy)` for received prefixes from both neighbors.

## Root Cause

The issue was caused by **missing outbound route-maps on pop1 and pop2**. In FRR 8.4, when using eBGP peering, routes are not advertised by default without an explicit outbound policy configured. This is a security feature to prevent accidental route leaks.

### Symptoms Observed

1. BGP sessions were in `Established` state
2. `show ip bgp summary` showed:
   - `State/PfxRcd` = `0 (Policy)` on the router side
   - Both sent and received showed `(Policy)` on pop1/pop2 side
3. `show bgp neighbor <ip>` revealed:
   - "Outbound updates discarded due to missing policy"
   - "No AFI/SAFI activated for peer" (initially)
4. Routes were present in pop1/pop2's BGP table but not advertised
5. The `neighbor activate` commands, while configured in the static files, were not appearing in the running configuration (FRR considers them implicit when other address-family config exists)

## Solution

Added explicit outbound route-maps on both pop1 and pop2 to permit route advertisements:

### Configuration Changes

**On pop1:**
```
route-map ALLOW_OUT permit 10
exit

router bgp 65001
  address-family ipv4 unicast
    neighbor 10.0.1.1 route-map ALLOW_OUT out
  exit-address-family
```

**On pop2:**
```
route-map ALLOW_OUT permit 10
exit

router bgp 65002
  address-family ipv4 unicast
    neighbor 10.0.2.1 route-map ALLOW_OUT out
  exit-address-family
```

## Verification

After applying the fix:

```bash
# Check BGP summary on router
sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp summary"
```

Expected output shows `State/PfxRcd` = `1` for both neighbors instead of `0 (Policy)`.

```bash
# Check BGP routes
sudo docker exec clab-anycast-lab-router vtysh -c "show ip bgp"
```

Expected output shows the anycast route `203.0.113.10/32` with two paths:
- Via 10.0.1.2 (pop1) - marked as best path with `>`
- Via 10.0.2.2 (pop2) - available as backup

```bash
# Check routing table
sudo docker exec clab-anycast-lab-router vtysh -c "show ip route 203.0.113.10/32"
```

Expected output shows the route installed in the FIB via the best path.

## Key Learnings

1. **FRR eBGP Default Behavior**: FRR 8.4 requires explicit outbound policies for eBGP neighbors to prevent accidental route advertisements.

2. **Implicit Neighbor Activation**: When a neighbor has any address-family configuration (like route-maps), FRR considers it implicitly activated, so the `neighbor activate` command doesn't appear in `show running-config`.

3. **Policy Indicators**: The `(Policy)` message in BGP summary indicates missing inbound or outbound policies, not necessarily that policies are configured and blocking routes.

4. **Configuration Persistence**: FRR's `service integrated-vtysh-config` can overwrite bind-mounted configuration files with its normalized version, which may strip seemingly redundant commands.

## Prevention

When configuring eBGP peering in FRR:

1. Always configure outbound route-maps (even simple permit-all maps) for eBGP neighbors
2. Use `show bgp neighbor <ip>` to check for policy-related messages
3. Verify routes are actually being sent/received, not just that sessions are established
4. Test route advertisement after any BGP configuration change with `clear ip bgp * soft out`
