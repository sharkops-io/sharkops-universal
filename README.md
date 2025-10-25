# SharkOps Universal Helm Chart

A universal Helm chart for deploying any Docker container on Kubernetes. This chart provides a consistent and reusable deployment pattern for any containerized application.

## Features

- **Universal Design**: Deploy any Docker container with minimal configuration
- **Self-Contained**: No external dependencies, uses custom templates for maximum flexibility
- **Flexible Configuration**: Support for multiple volumes, environment variables, and probes
- **Security First**: Proper security contexts and user/group management
- **Production Ready**: Includes health checks, resource limits, and ingress support
- **Comprehensive Testing**: Unit tests and integration tests included
- **Environment Management**: Support for ConfigMaps, Secrets, and envFrom
- **Persistence Options**: Flexible volume management with existing PVC support

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- (optional) Persistent volume support (for data persistence)

## Installation

### Install the Chart

#### From GitLab Container Registry (OCI)

The OCI registry approach is the modern, recommended way to distribute Helm charts. Our chart is publicly accessible:

```bash
# Install latest version from OCI registry (no authentication required)
helm install my-app oci://registry.gitlab.com/sharkops/helm-charts/sharkops-universal/sharkops-universal

# Install specific version
helm install my-app oci://registry.gitlab.com/sharkops/helm-charts/sharkops-universal/sharkops-universal --version 1.0.0

# Install with custom values
helm install my-app oci://registry.gitlab.com/sharkops/helm-charts/sharkops-universal/sharkops-universal \
  -f examples/plex.yaml

# Install with custom values and specific version
helm install my-app oci://registry.gitlab.com/sharkops/helm-charts/sharkops-universal/sharkops-universal \
  --version 1.0.0 \
  -f examples/plex.yaml

# Pull chart for inspection
helm pull oci://registry.gitlab.com/sharkops/helm-charts/sharkops-universal/sharkops-universal --version 1.0.0

# Show chart information
helm show chart oci://registry.gitlab.com/sharkops/helm-charts/sharkops-universal/sharkops-universal
```

#### From Local Chart

```bash
# Install with default values
helm install my-app ./sharkops-universal

# Install with custom values
helm install my-app ./sharkops-universal -f examples/plex.yaml

# Install with custom image
helm install my-app ./sharkops-universal \
  --set image.repository=nginxinc/nginx-unprivileged \
  --set image.tag=alpine
```

## Configuration

### Chart Metadata

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override the chart name | `""` |
| `fullnameOverride` | Override the full name | `""` |

### Image Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Docker image repository | `""` |
| `image.tag` | Image tag | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.pullSecrets` | Image pull secrets | `[]` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.ports` | Service ports array | `[{name: http, port: 80, targetPort: 80, protocol: TCP, type: ClusterIP}]` |
| `service.ports[].type` | Service type for this specific port (optional) | Uses `service.type` |
| `service.annotations` | Service annotations | `{}` |

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
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Ingress hosts | `[]` |
| `ingress.tls` | Ingress TLS configuration | `[]` |
| `additionalIngresses` | Additional ingress resources for other ports | `[]` |

### LoadBalancer Services

| Parameter | Description | Default |
|-----------|-------------|---------|
| `loadBalancers` | LoadBalancer services for additional ports | `[]` |
| `loadBalancers[].name` | LoadBalancer service name | Required |
| `loadBalancers[].enabled` | Enable this LoadBalancer | `true` |
| `loadBalancers[].port` | External port (single port mode) | Optional |
| `loadBalancers[].targetPort` | Target port (single port mode) | Optional |
| `loadBalancers[].protocol` | Protocol (single port mode) | `TCP` |
| `loadBalancers[].ports` | Multiple ports array | `[]` |
| `loadBalancers[].ports[].name` | Port name | Required |
| `loadBalancers[].ports[].port` | External port | Required |
| `loadBalancers[].ports[].targetPort` | Target port | Required |
| `loadBalancers[].ports[].protocol` | Protocol | `TCP` |
| `loadBalancers[].loadBalancerIP` | Specific IP for LoadBalancer (MetalLB, etc.) | Optional |
| `loadBalancers[].annotations` | LoadBalancer annotations | `{}` |

**LoadBalancer IP (MetalLB, etc.):**

You can specify a specific IP for the LoadBalancer service:

```yaml
loadBalancers:
  - name: external
    enabled: true
    port: 8080
    targetPort: 8080
    loadBalancerIP: 192.168.1.100
    annotations:
      metallb.universe.tf/address-pool: production
```

**Multiple Protocols on Same Port:**

You can expose the same internal port with different protocols using the `ports` array:

```yaml
loadBalancers:
  - name: multi-protocol
    enabled: true
    ports:
      - name: tcp-8080
        port: 8080
        targetPort: 8080
        protocol: TCP
      - name: udp-8080
        port: 8080
        targetPort: 8080
        protocol: UDP
```

### Persistence Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable persistence | `false` |
| `persistence.size` | Storage size | `1Gi` |
| `persistence.mountPath` | Mount path | `/config` |
| `persistence.storageClass` | Storage class | `""` (uses default) |
| `persistence.accessMode` | Access mode | `ReadWriteOnce` |
| `persistence.existingClaim` | Use existing PVC | `""` (creates new PVC) |
| `persistence.volumes` | Additional volumes with persistence | `[]` |

#### Additional Volumes

Each volume in `persistence.volumes` can have its own persistence configuration:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.volumes[].name` | Volume name | Required |
| `persistence.volumes[].mountPath` | Mount path | Required |
| `persistence.volumes[].subPath` | Sub path | `""` |
| `persistence.volumes[].persistence.enabled` | Enable persistence for this volume | `false` |
| `persistence.volumes[].persistence.size` | Storage size | Required if enabled |
| `persistence.volumes[].persistence.storageClass` | Storage class | `""` (uses default) |
| `persistence.volumes[].persistence.accessMode` | Access mode | `ReadWriteOnce` |
| `persistence.volumes[].persistence.existingClaim` | Use existing PVC | `""` (creates new PVC) |

### Environment Variables and Secrets

The chart supports multiple ways to manage environment variables and secrets:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `env.values` | Direct environment variables (key-value pairs) | `{}` |
| `env.configMaps` | Environment variables from ConfigMaps | `[]` |
| `env.secrets` | Environment variables from Secrets | `[]` |
| `envFrom` | Load all environment variables from ConfigMaps/Secrets (standard Kubernetes syntax) | `[]` |
| `secretMounts` | Mount secrets as files | `[]` |

#### Direct Environment Variables

Set environment variables directly in values.yaml:

```yaml
env:
  values:
    LOG_LEVEL: "info"
    DEBUG: "true"
    APP_MODE: "production"
    PUID: 1000
    PGID: 1000
    TZ: "UTC"
```

#### Environment Variables from ConfigMaps

Reference ConfigMaps for environment variables:

```yaml
env:
  configMaps:
    - name: "app-config"  # All keys from this ConfigMap
    - name: "global-config"
      keys: ["GLOBAL_SETTING", "FEATURE_FLAG"]  # Specific keys only
```

#### Environment Variables from Secrets

Reference Secrets for environment variables:

```yaml
env:
  secrets:
    - name: "app-secrets"
      keys: ["DB_PASSWORD", "API_KEY"]  # Specific keys only
    - name: "global-secrets"  # All keys from this Secret
```

#### envFrom (Standard Kubernetes Syntax)

Use the standard Kubernetes `envFrom` syntax to load all environment variables from ConfigMaps/Secrets:

```yaml
envFrom:
  - configMapRef:
      name: "app-config"
  - secretRef:
      name: "app-secrets"
  - configMapRef:
      name: "global-config"
      optional: true  # Don't fail if ConfigMap doesn't exist
```

This is the most efficient way to load all environment variables from a ConfigMap or Secret at once.

#### Secret Mounts

Mount secrets as files instead of environment variables:

```yaml
secretMounts:
  - name: "ssl-certs"
    secretName: "ssl-secret"
    mountPath: "/etc/ssl/certs"
    defaultMode: 0400
  - name: "config-files"
    secretName: "app-config-secret"
    mountPath: "/etc/app/config"
    subPath: "config.yaml"  # Mount specific key as file
    defaultMode: 0600
```

### Health Checks and Probes

| Parameter | Description | Default |
|-----------|-------------|---------|
| `healthCheck.enabled` | Enable generic health check | `true` |
| `healthCheck.path` | Health check path | `/` |
| `healthCheck.port` | Health check port | `80` |
| `healthCheck.initialDelaySeconds` | Initial delay | `30` |
| `healthCheck.periodSeconds` | Check interval | `10` |
| `healthCheck.timeoutSeconds` | Check timeout | `5` |
| `healthCheck.failureThreshold` | Failure threshold | `3` |
| `livenessProbe.enabled` | Enable liveness probe | `true` |
| `livenessProbe.httpGet.path` | HTTP path for liveness check | `/` |
| `livenessProbe.httpGet.port` | HTTP port for liveness check | `http` |
| `livenessProbe.initialDelaySeconds` | Initial delay before first check | `10` |
| `livenessProbe.periodSeconds` | Check interval | `10` |
| `livenessProbe.timeoutSeconds` | Check timeout | `5` |
| `livenessProbe.failureThreshold` | Failure threshold | `3` |
| `readinessProbe.enabled` | Enable readiness probe | `true` |
| `readinessProbe.httpGet.path` | HTTP path for readiness check | `/` |
| `readinessProbe.httpGet.port` | HTTP port for readiness check | `http` |
| `readinessProbe.initialDelaySeconds` | Initial delay before first check | `2` |
| `readinessProbe.periodSeconds` | Check interval | `5` |
| `readinessProbe.timeoutSeconds` | Check timeout | `3` |
| `readinessProbe.failureThreshold` | Failure threshold | `3` |

**Note**: Probes are optional. When not configured, Kubernetes will use default behavior. See examples for probe configuration patterns.

### Security Context

| Parameter | Description | Default |
|-----------|-------------|---------|
| `securityContext.runAsUser` | User ID to run as | `1000` |
| `securityContext.runAsGroup` | Group ID to run as | `1000` |
| `securityContext.fsGroup` | File system group | `1000` |

### Resources

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources` | Resource requests and limits | `null` (optional) |
| `resources.limits.cpu` | CPU limit | Optional |
| `resources.limits.memory` | Memory limit | Optional |
| `resources.requests.cpu` | CPU request | Optional |
| `resources.requests.memory` | Memory request | Optional |

### Node Selector

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodeSelector` | Node selector labels | `{}` |

### Tolerations

| Parameter | Description | Default |
|-----------|-------------|---------|
| `tolerations` | Pod tolerations | `[]` |
| `tolerations[].key` | Taint key | Required |
| `tolerations[].operator` | Taint operator | `Equal` |
| `tolerations[].value` | Taint value | Optional |
| `tolerations[].effect` | Taint effect | Required |
| `tolerations[].tolerationSeconds` | Toleration duration | Optional |

### Affinity

| Parameter | Description | Default |
|-----------|-------------|---------|
| `affinity` | Pod affinity rules | `{}` |
| `affinity.podAffinity` | Pod affinity rules | Optional |
| `affinity.podAntiAffinity` | Pod anti-affinity rules | Optional |
| `affinity.nodeAffinity` | Node affinity rules | Optional |

### Service Account

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create service account | `true` |
| `serviceAccount.annotations` | Service account annotations | `{}` |
| `serviceAccount.name` | Service account name | `""` (auto-generated) |

## Using Existing PVCs

You can use pre-existing PVCs instead of creating new ones. This is useful when you have manually created PVCs or want to share storage between deployments.

### Main Persistence with Existing PVC

```yaml
persistence:
  enabled: true
  existingClaim: "my-existing-config-pvc"  # Use existing PVC
```

### Additional Volumes with Existing PVCs

```yaml
persistence:
  volumes:
    - name: downloads
      mountPath: /downloads
      persistence:
        enabled: true
        existingClaim: "my-existing-downloads-pvc"  # Use existing PVC
    - name: media
      mountPath: /media
      persistence:
        enabled: true
        existingClaim: "my-existing-media-pvc"  # Use existing PVC
```

### Mixed Configuration

You can mix existing PVCs with new ones:

```yaml
persistence:
  enabled: true
  existingClaim: "my-existing-config-pvc"  # Use existing PVC for main config
  volumes:
    - name: downloads
      mountPath: /downloads
      persistence:
        enabled: true
        size: 10Gi  # Create new PVC for downloads
    - name: media
      mountPath: /media
      persistence:
        enabled: true
        existingClaim: "my-existing-media-pvc"  # Use existing PVC for media
```

## Examples

### Nginx (Generic Container)

```yaml
image:
  repository: nginxinc/nginx-unprivileged
  tag: alpine

service:
  ports:
    - name: http
      port: 8080
      targetPort: 8080
      protocol: TCP

env:
  values:
    NGINX_ENTRYPOINT_QUIET_LOGS: "1"
```

### Plex Media Server (LinuxServer.io)

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

persistence:
  enabled: true
  size: 10Gi
  mountPath: /config
  volumes:
    - name: downloads
      mountPath: /downloads
      persistence:
        enabled: true
        size: 100Gi
    - name: media
      mountPath: /media
      persistence:
        enabled: true
        size: 500Gi

env:
  values:
    PUID: 1000
    PGID: 1000
    TZ: America/New_York
    VERSION: docker
    PLEX_CLAIM: "claim-xxxxxxxxxxxxxxxxxxxx"

livenessProbe:
  enabled: true
  httpGet:
    path: /web
    port: 32400

readinessProbe:
  enabled: true
  httpGet:
    path: /web
    port: 32400
```

### Radarr (LinuxServer.io)

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

persistence:
  enabled: true
  size: 5Gi
  mountPath: /config
  volumes:
    - name: downloads
      mountPath: /downloads
      persistence:
        enabled: true
        size: 50Gi
    - name: movies
      mountPath: /movies
      persistence:
        enabled: true
        size: 200Gi

env:
  values:
    PUID: 1000
    PGID: 1000
    TZ: America/New_York
    UMASK_SET: 002
```

### Tautulli (LinuxServer.io)

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

persistence:
  enabled: true
  size: 5Gi
  mountPath: /config

env:
  values:
    PUID: 1000
    PGID: 1000
    TZ: America/New_York
    UMASK_SET: 002
```

## Testing

The chart includes comprehensive testing capabilities:

### Unit Tests

```bash
# Run unit tests
helm unittest --strict -f "tests/*.yaml" .

# Install helm-unittest if needed
helm plugin install https://github.com/helm-unittest/helm-unittest
```

Unit tests are located in the `tests/` directory and use `helm-unittest` to validate:
- Deployment creation and configuration
- Service creation and port configuration  
- PVC creation and existing claim support
- Environment variable and secret management
- Template rendering with various values

### Integration Tests

```bash
# Run integration tests with chart-testing
ct lint --all
ct install --all

# Install chart-testing manually
# See: https://github.com/helm/chart-testing
```

Integration tests use `chart-testing` to:
- Lint all chart files
- Test installation in a real Kubernetes environment
- Validate against multiple Kubernetes versions

### Example Testing

```bash
# Test with specific examples
helm template test . -f examples/plex.yaml
helm template test . -f examples/nginx.yaml
helm template test . -f examples/env-secrets.yaml
```

### CI/CD Testing

The GitLab CI pipeline automatically runs:
- **Lint**: Chart syntax and template validation
- **Unit Tests**: helm-unittest validation
- **Example Tests**: All example configurations
- **Integration Tests**: chart-testing validation
- **Package**: Chart packaging
- **Deploy**: OCI registry deployment

## Development

### Prerequisites

- Helm 3.0+
- Python 3.11+ (for helm-unittest)
- chart-testing (for integration tests)

### Running Tests

```bash
# Unit tests
helm unittest --strict -f "tests/*.yaml" .

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

- **Source Code**: [https://gitlab.com/sharkops/helm-charts/sharkops-universal](https://gitlab.com/sharkops/helm-charts/sharkops-universal)
- **Issues**: [GitLab Issues](https://gitlab.com/sharkops/helm-charts/sharkops-universal/-/issues)
- **Merge Requests**: [GitLab Merge Requests](https://gitlab.com/sharkops/helm-charts/sharkops-universal/-/merge_requests)

## Contributing

1. Fork the repository on GitLab
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a merge request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
