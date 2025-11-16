# X-Road Helm Charts - VanillaCore Mirror

This repository contains Helm charts and configurations for deploying X-Road Information Mediator components.

## Repository Structure

- `bb-im/` - Main X-Road components for BB-IM cluster
  - `test-ca/` - Test Certificate Authority (trust anchor)
  - `x-road-csx/` - Central Server Helm chart
  - `x-road-ssx/` - Security Server Helm chart
  - `hurl-auto-config/` - Automated configuration scripts
  - `example-service/` - Example API services for testing
- `add-im/` - Additional IM cluster configurations
- `bastion/` - Bastion host Helm chart

## Branching Strategy

- **main** - Mirrors the original upstream state from source repository
- **dev** - Active development with infrastructure adaptations for our deployment

## Usage

See `DEPLOYMENT_GUIDE.md` for deployment instructions.

## Upstream Sync

The main branch tracks the original X-Road deployment configurations. Changes should be made in dev branch and merged via pull requests.

To sync from upstream:
```bash
# On source server
git pull origin main

# Push to this mirror
git push vanillacore main
```

## License

X-Road is licensed under the MIT License. See original X-Road repository for details.
