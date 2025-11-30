# Anycast DR Lab - Scripts

This directory contains automated setup scripts for all components of the anycast lab.

## Scripts Overview

### Setup Scripts (Auto-executed on deployment)

- **setup-router.sh** - Configures router interfaces and starts FRR
- **setup-pop1.sh** - Configures pop1 interfaces, FRR, and socat proxy to regionA
- **setup-pop2.sh** - Configures pop2 interfaces, FRR, and socat proxy to regionB
- **setup-client.sh** - Configures client network and installs utilities
- **setup-region.sh** - Configures backend servers and custom HTML pages

### Utility Scripts (Manual execution)

- **health-check.sh** - Comprehensive health check for the entire lab

## Usage

### Automated Setup

All setup scripts are automatically executed when you deploy the lab:

```bash
sudo containerlab deploy -t anycast-lab.yml
```

The scripts will:
1. Configure all network interfaces
2. Set up routing tables
3. Start BGP on router and PoPs
4. Install and configure socat proxies
5. Set up backend web servers with custom content

### Health Check

Run the health check to verify everything is working:

```bash
bash scripts/health-check.sh
```

This will verify:
- Lab deployment status
- BGP session establishment
- Route advertisement
- Proxy services
- HTTP connectivity

## Script Details

### setup-pop1.sh & setup-pop2.sh

These scripts:
- Configure three interfaces (transit, backend, loopback)
- Add the anycast IP to loopback
- Set up return routes for bidirectional traffic
- Start FRR (BGP daemon)
- Install socat
- Start TCP proxy from anycast IP to backend server

### setup-region.sh

This script:
- Installs iproute2 for network configuration
- Configures backend network interface
- Creates custom HTML page identifying the region

### health-check.sh

Comprehensive diagnostics including:
- Container status
- BGP session state
- Route selection
- Proxy service status
- End-to-end HTTP connectivity

## Troubleshooting

If health check fails:

1. **BGP not established**: Wait 30 seconds after deployment for BGP to converge
2. **Proxy not running**: Check logs with `sudo docker exec clab-anycast-lab-pop1 cat /var/log/socat.log`
3. **HTTP not working**: Verify backend servers are running nginx

## Make Scripts Executable

```bash
chmod +x scripts/*.sh
```
