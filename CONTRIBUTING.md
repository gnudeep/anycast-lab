# Contributing to Anycast DR Lab

Thank you for your interest in contributing to this project!

## How to Contribute

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes**
4. **Test thoroughly**: 
   - Deploy the lab: `sudo containerlab deploy -t anycast-lab.yml`
   - Run health check: `bash scripts/health-check.sh`
   - Test failover: `bash scripts/demo-failover.sh`
5. **Commit your changes**: `git commit -m "Description of changes"`
6. **Push to your fork**: `git push origin feature/your-feature-name`
7. **Submit a Pull Request**

## Areas for Contribution

- Additional routing protocols (OSPF, IS-IS)
- Enhanced monitoring and metrics
- Load balancing configurations
- Additional test scenarios
- Documentation improvements
- Bug fixes and optimizations

## Code Style

- Shell scripts: Follow existing formatting
- Configuration files: Maintain consistent indentation
- Documentation: Clear, concise, with examples

## Testing Guidelines

- Always test changes in a clean deployment
- Verify BGP convergence
- Test failover scenarios
- Document any new features or changes

## Questions?

Feel free to open an issue for discussion before starting major changes.
