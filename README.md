# LinuxServer.io Universal Helm Chart

A universal Helm chart for deploying LinuxServer.io Docker images on Kubernetes. This chart provides a consistent and reusable deployment pattern for all LinuxServer.io applications.

## Features

- **Universal Design**: Deploy any LinuxServer.io Docker image with minimal configuration
- **Self-Contained**: No external dependencies, uses custom templates for maximum flexibility
- **Flexible Configuration**: Support for multiple volumes, environment variables, and probes
- **Security First**: Proper security contexts and user/group management
- **Production Ready**: Includes health checks, resource limits, and ingress support
- **Comprehensive Testing**: Unit tests and integration tests included

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Persistent volume support (for data persistence)

## Installation

### Install the Chart

#### From Local Chart

```bash
# Install with default values
helm install my-app ./linuxserver-universal

# Install with custom values
helm install my-app ./linuxserver-universal -f examples/plex.yaml

# Install with custom image
helm install my-app ./linuxserver-universal \
  --set image.repository=lscr.io/linuxserver/plex \
  --set image.tag=latest
```

#### From GitLab Container Registry (OCI)

```bash
# Add GitLab registry
helm registry login registry.gitlab.com

# Install from OCI registry
helm install my-app oci://registry.gitlab.com/sharkops/helm-charts/linuxserver-universal

# Install with custom values
helm install my-app oci://registry.gitlab.com/sharkops/helm-charts/linuxserver-universal \
  -f examples/plex.yaml
```

## Configuration

### Image Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | LinuxServer.io image repository | `""` |
| `image.tag` | Image tag | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.ports` | Service ports array | `[{name: http, port: 80, targetPort: 80, protocol: TCP, type: ClusterIP}]` |
| `service.ports[].type` | Service type for this specific port (optional) | Uses `service.type` |

### Per-Port Service Types

Each port can specify its own service type, allowing for flexible networking configurations:

- **ClusterIP**: Internal cluster access only (default)
- **NodePort**: Expose on each node's IP at a static port
- **LoadBalancer**: Expose via cloud provider's load balancer
- **ExternalName**: Map to external service

When ports have different service types, separate Kubernetes services are created for each type.

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `additionalIngresses` | Additional ingress resources for other ports | `[]` |
| `loadBalancers` | LoadBalancer services for additional ports (deprecated - use per-port types) | `[]` |

### Persistence Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable persistence | `true` |
| `persistence.size` | Storage size | `1Gi` |
| `persistence.mountPath` | Mount path | `/config` |

### LinuxServer.io Specific Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `linuxserver.env.PUID` | User ID | `1000` |
| `linuxserver.env.PGID` | Group ID | `1000` |
| `linuxserver.env.TZ` | Timezone | `UTC` |
| `linuxserver.volumes` | Additional volumes | `[]` |
| `linuxserver.volumeClaims` | Additional PVCs | `[]` |
| `linuxserver.livenessProbe.enabled` | Enable liveness probe | `true` |
| `linuxserver.readinessProbe.enabled` | Enable readiness probe | `true` |

## Examples

### Plex Media Server

```yaml
image:
  repository: lscr.io/linuxserver/plex
  tag: latest

service:
  ports:
    - name: http
      port: 32400
      targetPort: 32400
      protocol: TCP
ingress:
  enabled: true
  hosts:
    - host: plex.example.com
      paths:
        - path: /
          pathType: Prefix

linuxserver:
  env:
    PUID: 1000
    PGID: 1000
    TZ: America/New_York
    PLEX_CLAIM: "claim-xxxxxxxxxxxxxxxxxxxx"
  volumeClaims:
    - name: downloads
      size: 100Gi
    - name: media
      size: 500Gi
```

### Radarr

```yaml
image:
  repository: lscr.io/linuxserver/radarr
  tag: latest

service:
  ports:
    - name: http
      port: 7878
      targetPort: 7878
      protocol: TCP
ingress:
  enabled: true
  hosts:
    - host: radarr.example.com
      paths:
        - path: /
          pathType: Prefix

linuxserver:
  env:
    PUID: 1000
    PGID: 1000
    TZ: America/New_York
  volumeClaims:
    - name: downloads
      size: 50Gi
    - name: movies
      size: 200Gi
```

### Tautulli

```yaml
image:
  repository: lscr.io/linuxserver/tautulli
  tag: latest

service:
  ports:
    - name: http
      port: 8181
      targetPort: 8181
      protocol: TCP
ingress:
  enabled: true
  hosts:
    - host: tautulli.example.com
      paths:
        - path: /
          pathType: Prefix

linuxserver:
  env:
    PUID: 1000
    PGID: 1000
    TZ: America/New_York
```

### Deluge

```yaml
image:
  repository: lscr.io/linuxserver/deluge
  tag: latest

service:
  ports:
    - name: web
      port: 8112
      targetPort: 8112
      protocol: TCP
    - name: daemon
      port: 58846
      targetPort: 58846
      protocol: TCP
    - name: incoming
      port: 58946
      targetPort: 58946
      protocol: TCP
      type: LoadBalancer  # This port gets its own LoadBalancer service
ingress:
  enabled: true
  hosts:
    - host: deluge.example.com
      paths:
        - path: /
          pathType: Prefix
# Additional ingress for daemon port
additionalIngresses:
  - name: daemon
    enabled: true
    className: "nginx"
    hosts:
      - host: deluge-daemon.example.com
        paths:
          - path: /
            pathType: Prefix
    port: daemon  # Port name from service

linuxserver:
  env:
    PUID: 1000
    PGID: 1000
    TZ: America/New_York
    DELUGE_LOGLEVEL: info
  volumeClaims:
    - name: downloads
      size: 100Gi
```

## Testing

### Unit Tests

```bash
# Install helm-unittest
pip install helm-unittest

# Run unit tests
helm unittest tests/
```

### Integration Tests

```bash
# Install chart-testing
# See: https://github.com/helm/chart-testing

# Run integration tests
ct install --all
```

## Development

### Prerequisites

- Helm 3.0+
- Python 3.11+ (for helm-unittest)
- chart-testing (for integration tests)

### Running Tests

```bash
# Unit tests
helm unittest tests/

# Lint
helm lint .

# Template test
helm template . --debug

# Dry run
helm install --dry-run --debug test-release .
```

### CI/CD

This chart includes GitLab CI configuration for:

- Linting and unit testing
- Chart testing with example values
- Integration testing with chart-testing
- OCI chart packaging and deployment to GitLab Container Registry

## Repository

- **Source Code**: [https://gitlab.com/sharkops/helm-charts/linuxserver-universal](https://gitlab.com/sharkops/helm-charts/linuxserver-universal)
- **Issues**: [GitLab Issues](https://gitlab.com/sharkops/helm-charts/linuxserver-universal/-/issues)
- **Merge Requests**: [GitLab Merge Requests](https://gitlab.com/sharkops/helm-charts/linuxserver-universal/-/merge_requests)

## Contributing

1. Fork the repository on GitLab
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a merge request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [LinuxServer.io](https://www.linuxserver.io/) for providing excellent Docker images
- The Kubernetes and Helm communities
