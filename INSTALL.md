# Installation Guide for Ubuntu 24.04

This guide provides step-by-step instructions to set up the required environment for running the Anycast DR Lab on Ubuntu 24.04.

## Prerequisites

- Ubuntu 24.04 LTS (tested on 24.04)
- Sudo/root access
- Internet connection

## Step 1: Install Docker

### Remove old Docker versions (if any)

```bash
sudo apt-get remove docker docker-engine docker.io containerd runc
```

### Install Docker using the official script

```bash
# Download and run Docker installation script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to the docker group (to run Docker without sudo)
sudo usermod -aG docker $USER

# Apply the group changes (or log out and back in)
newgrp docker
```

### Verify Docker installation

```bash
docker --version
# Expected: Docker version 27.x.x or higher

docker run hello-world
# Should download and run a test container
```

### Configure Docker (optional but recommended)

```bash
# Enable Docker to start on boot
sudo systemctl enable docker
sudo systemctl start docker

# Verify Docker service status
sudo systemctl status docker
```

## Step 2: Install Containerlab

### Install Containerlab using the official script

```bash
# Download and install Containerlab
bash -c "$(curl -sL https://get.containerlab.dev)"
```

### Verify Containerlab installation

```bash
sudo containerlab version
# Expected: version 0.50.0 or higher (tested with 0.71.1)
```

### Alternative: Install specific version

```bash
# Install specific version (e.g., 0.71.1)
bash -c "$(curl -sL https://get.containerlab.dev)" -- -v 0.71.1
```

## Step 3: Pull Required Docker Images

Pre-pull the Docker images to speed up first deployment:

```bash
# Pull FRR routing image (for router, pop1, pop2)
docker pull frrouting/frr:v8.4.0

# Pull Nginx image (for regionA, regionB)
docker pull nginx:1.29.3

# Pull Alpine Linux image (for client)
docker pull alpine:3.22.2
```

### Verify downloaded images

```bash
docker images
# Should show:
# frrouting/frr    v8.4.0
# nginx            1.29.3
# alpine           3.22.2
```

## Step 4: Install Additional Tools (Optional)

These tools are useful for troubleshooting and testing:

```bash
# Install network utilities
sudo apt-get update
sudo apt-get install -y \
    net-tools \
    iputils-ping \
    traceroute \
    tcpdump \
    curl \
    wget \
    git \
    tree

# Install text editor (if needed)
sudo apt-get install -y vim nano
```

## Step 5: Clone the Repository

```bash
# Clone the anycast-lab repository
git clone https://github.com/gnudeep/anycast-lab.git
cd anycast-lab

# Make scripts executable
chmod +x scripts/*.sh
```

## Step 6: Verify Installation

Run a quick verification:

```bash
# Check all prerequisites
echo "=== System Check ==="
echo "OS: $(lsb_release -d | cut -f2)"
echo "Docker: $(docker --version)"
echo "Containerlab: $(sudo containerlab version | grep version | awk '{print $2}')"
echo ""
echo "Docker Images:"
docker images | grep -E "frrouting|nginx|alpine"
```

Expected output:
```
=== System Check ===
OS: Ubuntu 24.04.x LTS
Docker: Docker version 27.x.x
Containerlab: 0.71.1

Docker Images:
frrouting/frr    v8.4.0    ...
nginx            1.29.3    ...
alpine           3.22.2    ...
```

## Step 7: Deploy the Lab

```bash
# Deploy the lab
sudo containerlab deploy -t anycast-lab.yml

# Wait 30 seconds for BGP convergence
sleep 30

# Run health check
bash scripts/health-check.sh
```

## Tested Docker Image Versions

The following Docker image versions have been tested and verified to work:

| Image            | Tag/Version | Purpose              | Pull Command                        |
|------------------|-------------|----------------------|-------------------------------------|
| frrouting/frr    | v8.4.0      | BGP routing daemon   | `docker pull frrouting/frr:v8.4.0`  |
| nginx            | 1.29.3      | Web server backends  | `docker pull nginx:1.29.3`          |
| alpine           | 3.22.2      | Client container     | `docker pull alpine:3.22.2`         |

**Note**: Using `latest` tags will pull the most recent versions, but for reproducibility, use the specific versions listed above.

## Troubleshooting

### Docker permission denied

```bash
# If you get "permission denied" errors
sudo usermod -aG docker $USER
newgrp docker
# Or log out and log back in
```

### Containerlab not found

```bash
# Add to PATH (if installed but not found)
export PATH=$PATH:/usr/local/bin
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
```

### Container network issues

```bash
# Reset Docker network
sudo systemctl restart docker

# Clean up old containers/networks
docker system prune -a
```

### Port conflicts

```bash
# Check if ports are already in use
sudo ss -tlnp | grep -E ':80|:179'

# Stop conflicting services if needed
```

## Cleanup

To remove the lab and free up resources:

```bash
# Destroy the lab
sudo containerlab destroy -t anycast-lab.yml

# Remove unused Docker images (optional)
docker image prune -a

# Remove unused networks and volumes
docker system prune -a --volumes
```

## System Requirements

**Minimum:**
- CPU: 2 cores
- RAM: 4 GB
- Disk: 10 GB free space

**Recommended:**
- CPU: 4 cores
- RAM: 8 GB
- Disk: 20 GB free space

## Next Steps

Once installation is complete:

1. Follow the [README.md](README.md) for lab usage
2. Run the health check: `bash scripts/health-check.sh`
3. Test failover: `bash scripts/demo-failover.sh`
4. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues

## References

- [Docker Installation Guide](https://docs.docker.com/engine/install/ubuntu/)
- [Containerlab Documentation](https://containerlab.dev/install/)
- [FRR Documentation](https://docs.frrouting.org/)
