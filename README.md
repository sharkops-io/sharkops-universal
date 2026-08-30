# SharkOps Universal Helm Chart

A universal Helm chart for deploying any Docker container on Kubernetes. This chart provides a consistent and reusable deployment pattern for any containerized application.

## Features

- **Universal Design**: Deploy any Docker container with minimal configuration
- **Deployment or DaemonSet**: one pod spec, either controller — `kind: DaemonSet` for node-level agents
- **Pod and Container Security Contexts**: both levels, so PodSecurity `baseline`/`restricted` are satisfiable
- **Self-Contained**: No external dependencies, uses custom templates for maximum flexibility
- **Flexible Configuration**: Support for multiple volumes, environment variables, and probes
- **Security First**: Proper security contexts and user/group management
- **Production Ready**: Includes health checks, resource limits, and ingress support
- **Comprehensive Testing**: Unit tests and integration tests included
- **Environment Management**: Support for ConfigMaps, Secrets, and envFrom
- **Persistence Options**: Flexible volume management with existing PVC support
- **GPU Support**: Runtime class and extra volume configuration for NVIDIA GPU workloads
- **Prometheus Metrics**: Optional ServiceMonitor for scraping by Prometheus Operator

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- (optional) Persistent volume support (for data persistence)
- (optional) Prometheus Operator CRDs, if `serviceMonitor.enabled: true`

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

### Command/Args Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `command` | Overrides the image ENTRYPOINT. Empty renders nothing. | `[]` |
| `args` | Arguments passed to the container. Required for images whose entrypoint is a multi-subcommand binary (e.g. `itzg/mc-monitor` needs `export-for-prometheus`). Empty renders nothing. | `[]` |

### Workload Kind (Deployment or DaemonSet)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `kind` | Controller to render — `Deployment` or `DaemonSet` | `Deployment` |

The pod template is identical for both. Every value that shapes the pod — image, command/args, env, volumes, probes, resources, `nodeSelector`, `tolerations`, `affinity`, `extraVolumes`/`extraVolumeMounts`, `extraContainers` — applies unchanged. Only the controller-level fields differ:

| | Deployment | DaemonSet |
|---|---|---|
| Pod count | `replicas` | one per matching node |
| Rollout | `strategy` | `updateStrategy` |
| Rollout types | `RollingUpdate`, `Recreate` | `RollingUpdate`, `OnDelete` |

Use `DaemonSet` for something that must run on every node rather than somewhere in the cluster: a node agent, a log shipper, a device plugin.

```yaml
kind: DaemonSet

image:
  repository: intel/intel-gpu-plugin
  tag: "0.36.0"

# No Service and no HTTP endpoint — both must be turned off explicitly, or the
# default probe targets a port named `http` that no longer exists.
service:
  ports: []
healthCheck:
  enabled: false
```

**Wrong-kind values are render errors, not silent no-ops.** Setting `replicas` on a `DaemonSet`, or a `strategy.type` that belongs to the other kind, fails `helm template` with a message naming the key — rather than rendering cleanly and deploying something the values don't describe:

```
Error: sharkops-universal: replicas (3) has no meaning for kind: DaemonSet --
one pod per matching node is the definition. Use nodeSelector/affinity to
choose nodes.
```

**`updateStrategy` is a separate key from `strategy`, deliberately.** The two have the same shape but incompatible defaults: apps/v1 rejects a DaemonSet whose `maxUnavailable` **and** `maxSurge` are both non-zero (*"may not be set to a non-zero value when maxSurge is non-zero"*), so reusing `strategy`'s `1`/`1` default would make every DaemonSet render perfectly and then fail at apply. `updateStrategy` defaults to the DaemonSet-legal `maxUnavailable: 1` / `maxSurge: 0`, and the illegal pair is caught at render time.

### Deployment Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicas` | Number of pod replicas (**`kind: Deployment` only**) | `1` |
| `revisionHistoryLimit` | Number of old ReplicaSets/ControllerRevisions to keep for rollbacks | `1` |
| `strategy.type` | Deployment strategy type — `RollingUpdate` or `Recreate` (**`kind: Deployment` only**) | `RollingUpdate` |
| `strategy.rollingUpdate.maxUnavailable` | Maximum unavailable pods during update (RollingUpdate only) | `1` |
| `strategy.rollingUpdate.maxSurge` | Maximum pods that can be created above desired count (RollingUpdate only) | `1` |
| `updateStrategy.type` | DaemonSet rollout type — `RollingUpdate` or `OnDelete` (**`kind: DaemonSet` only**) | `RollingUpdate` |
| `updateStrategy.rollingUpdate.maxUnavailable` | Pods taken down at a time during a rollout | `1` |
| `updateStrategy.rollingUpdate.maxSurge` | Pods surged above one-per-node; must be `0` unless `maxUnavailable` is `0` | `0` |

**Note on `Recreate`**: use it for a single-replica app on a ReadWriteOnce volume. The default `maxSurge: 1` starts the replacement pod before the old one is gone, and when the two land on different nodes the new pod blocks on `Multi-Attach error for volume ...` until the old attachment releases — an unbounded stall during which the app is down. The `rollingUpdate` block is rendered **only** for `type: RollingUpdate`, since apps/v1 rejects the field alongside `Recreate`. On chart versions before 0.23.0, `Recreate` renders cleanly and then fails at apply; use `strategy.rollingUpdate.maxSurge: 0` there instead, which is equivalent at `replicas: 1`.

**Note**: The `revisionHistoryLimit` controls how many old ReplicaSets (or, for a DaemonSet, ControllerRevisions) are kept after upgrades. This helps with rollback capabilities but also prevents old revisions from accumulating indefinitely. The default of `1` keeps the current revision plus one previous version.

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.ports` | Service ports array | `[{name: http, port: 80, targetPort: 80, protocol: TCP, type: ClusterIP}]` |
| `service.ports[].type` | Service type for this specific port (optional) | Uses `service.type` |
| `service.ports[].serviceName` | Service name for this specific port (optional) | Uses `common.names.fullname` |
| `service.annotations` | Service annotations | `{}` |
| `service.ipFamilyPolicy` | IP family policy for dual-stack (`SingleStack`, `PreferDualStack`, `RequireDualStack`) | `""` (omitted) |
| `service.ipFamilies` | Ordered list of IP families (`IPv4`, `IPv6`) | `[]` (omitted) |

### Per-Port Service Types

Each port can specify its own service type, allowing for flexible networking configurations:

- **ClusterIP**: Internal cluster access only (default)
- **NodePort**: Expose on each node's IP at a static port
- **LoadBalancer**: Expose via cloud provider's load balancer
- **ExternalName**: Map to external service

When ports have different service types, separate Kubernetes services are created for each type.

### Per-Service Naming

Each port can specify its own service name, allowing for multiple services with custom names:

```yaml
service:
  ports:
    - name: http
      port: 80
      targetPort: 80
      serviceName: "web-service"  # Custom service name
    - name: api
      port: 8080
      targetPort: 8080
      serviceName: "api-service"   # Another custom service name
```

**Note**: If no `serviceName` is specified, the service will use `common.names.fullname` as the default name.

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Ingress hosts | `[]` |
| `ingress.hosts[].paths[].serviceName` | Service name to route to (optional) | Uses `common.names.fullname` |
| `ingress.hosts[].paths[].servicePort` | Service port to route to (optional) | Uses first service port |
| `ingress.tls` | Ingress TLS configuration | `[]` |
| `additionalIngresses` | Additional ingress resources for other ports | `[]` |

### Custom Service Routing

You can route ingress traffic to different services by specifying `serviceName` and `servicePort`:

```yaml
service:
  ports:
    - name: web
      port: 80
      targetPort: 80
      serviceName: web-service
    - name: api
      port: 8080
      targetPort: 8080
      serviceName: api-service

ingress:
  enabled: true
  hosts:
    - host: example.com
      paths:
        - path: /
          pathType: Prefix
          serviceName: web-service  # Route to web service
          servicePort: 80
        - path: /api
          pathType: Prefix
          serviceName: api-service  # Route to API service
          servicePort: 8080
```

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
| `loadBalancers[].externalTrafficPolicy` | External traffic policy (Local/Cluster) | Optional |
| `loadBalancers[].ipFamilyPolicy` | IP family policy for dual-stack (`SingleStack`, `PreferDualStack`, `RequireDualStack`) | Optional |
| `loadBalancers[].ipFamilies` | Ordered list of IP families (`IPv4`, `IPv6`) | Optional |
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

**External Traffic Policy:**

Control how external traffic is routed to your pods:

```yaml
loadBalancers:
  # Local: Preserves source IP, routes to pods on same node
  - name: local-traffic
    enabled: true
    port: 8080
    targetPort: 8080
    externalTrafficPolicy: Local
  
  # Cluster: Routes to any pod, may lose source IP
  - name: cluster-traffic
    enabled: true
    port: 9090
    targetPort: 9090
    externalTrafficPolicy: Cluster
```

**Traffic Policy Options:**
- **`Local`**: Preserves source IP, routes to pods on the same node as the LoadBalancer
- **`Cluster`**: Routes to any pod in the cluster, may lose source IP but better load distribution

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

### Dual-Stack (IPv4 + IPv6)

Kubernetes dual-stack support lets services receive both IPv4 and IPv6 addresses. This requires a dual-stack cluster. Use `ipFamilyPolicy` and `ipFamilies` on either the main service or individual LoadBalancer entries.

**`ipFamilyPolicy` options:**
- **`SingleStack`**: Single IP family only (default Kubernetes behaviour when omitted)
- **`PreferDualStack`**: Request dual-stack; falls back to single-stack if the cluster doesn't support it
- **`RequireDualStack`**: Require dual-stack; the service will fail to create on a single-stack cluster

**Main service:**

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

**LoadBalancer service:**

```yaml
loadBalancers:
  - name: external
    enabled: true
    port: 8080
    targetPort: 8080
    protocol: TCP
    ipFamilyPolicy: RequireDualStack
    ipFamilies:
      - IPv4
      - IPv6
```

The first entry in `ipFamilies` is the primary family used for the ClusterIP. Omitting `ipFamilies` while setting `ipFamilyPolicy: PreferDualStack` lets Kubernetes pick the order based on cluster defaults.

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
`healthCheck` sets the HTTP endpoint **both** probes use. Set it once there
rather than twice below; per-probe `httpGet` values override it for that probe
only.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `healthCheck.enabled` | Master switch — `false` drops BOTH probes | `true` |
| `healthCheck.path` | Shared probe path | `/` |
| `healthCheck.port` | Shared probe port **name** (from `service.ports[]`) | `http` |
| `livenessProbe.enabled` | Enable liveness probe | `true` |
| `livenessProbe.httpGet.path` | Override the shared path, liveness only | *(inherits `healthCheck.path`)* |
| `livenessProbe.httpGet.port` | Override the shared port, liveness only | *(inherits `healthCheck.port`)* |
| `livenessProbe.initialDelaySeconds` | Initial delay before first check | `10` |
| `livenessProbe.periodSeconds` | Check interval | `10` |
| `livenessProbe.timeoutSeconds` | Check timeout | `5` |
| `livenessProbe.failureThreshold` | Failure threshold | `3` |
| `readinessProbe.enabled` | Enable readiness probe | `true` |
| `readinessProbe.httpGet.path` | Override the shared path, readiness only | *(inherits `healthCheck.path`)* |
| `readinessProbe.httpGet.port` | Override the shared port, readiness only | *(inherits `healthCheck.port`)* |
| `readinessProbe.initialDelaySeconds` | Initial delay before first check | `2` |
| `readinessProbe.periodSeconds` | Check interval | `5` |
| `readinessProbe.timeoutSeconds` | Check timeout | `3` |
| `readinessProbe.failureThreshold` | Failure threshold | `3` |

```yaml
# One endpoint, both probes:
healthCheck:
  path: /healthz
  port: http

# Different endpoints per probe:
healthCheck:
  path: /healthz
livenessProbe:
  httpGet:
    path: /alive
```

**Timing stays per-probe.** Liveness and readiness want different
`initialDelaySeconds`, so there is deliberately no shared timing on
`healthCheck`.

> **Changed in 0.17.0** — `healthCheck` previously had **no effect at all**:
> it was declared in `values.yaml` with path/port/timeouts and referenced
> nowhere in the chart, so setting `healthCheck.path` rendered cleanly and
> silently left the probes on `/`. It now drives both probes.
> `healthCheck.initialDelaySeconds`, `periodSeconds`, `timeoutSeconds` and
> `failureThreshold` were removed rather than wired up (see above); they did
> nothing before and do nothing now, so they are gone rather than left looking
> meaningful. Charts that only set `livenessProbe`/`readinessProbe`, or set
> nothing, render byte-identical output.

### Grafana Dashboards

Ships dashboards as ConfigMaps labelled for the kube-prometheus-stack Grafana
sidecar, so a dashboard lives in the same repo — and the same diff — as the
exporter whose metrics it queries.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `grafanaDashboards.enabled` | Create dashboard ConfigMaps | `false` |
| `grafanaDashboards.dashboards` | Map of name → dashboard JSON string | `{}` |
| `grafanaDashboards.label` | Sidecar watch label | `grafana_dashboard` |
| `grafanaDashboards.labelValue` | Sidecar watch label value | `"1"` |
| `grafanaDashboards.labels` | Extra labels (e.g. `grafana_folder`) | `{}` |
| `grafanaDashboards.annotations` | Extra annotations | `{}` |

Each entry becomes its own ConfigMap named `<release>-<key>`, with the JSON
under data key `<key>.json` — one object per dashboard so they don't share the
1 MiB etcd object limit.

In a helmfile values file, use the `.gotmpl` extension so the JSON can stay a
real, diffable file on disk:

```yaml
grafanaDashboards:
  enabled: true
  dashboards:
    my-app: |
      {{ readFile "dashboards/my-app.json" | indent 6 | trim }}
```

**Do not use `extraObjects` for dashboards.** `extraObjects` renders each
object through `tpl`, and Grafana's `legendFormat` syntax is `{{label}}` — a
dashboard containing `"legendFormat": "{{decision}}"` fails outright with
`error calling tpl: ... function "decision" not defined`. This template emits
the JSON verbatim, which is the whole reason it exists separately.

Requires the Grafana sidecar to be watching the namespace: with
`NAMESPACE=ALL` any namespace works, otherwise only Grafana's own. Mismatch
here means the ConfigMap is created and silently ignored.

### Security Context

Two separate blocks, carrying different fields. They are **not** interchangeable.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `securityContext.runAsUser` | User ID to run as (pod-level) | `1000` |
| `securityContext.runAsGroup` | Group ID to run as (pod-level) | `1000` |
| `securityContext.fsGroup` | File system group (pod-level) | `1000` |
| `containerSecurityContext` | Container-level context, applied to the **main container only** | `{}` (omitted) |

`runAsUser`/`runAsGroup`/`fsGroup` are pod-spec fields. `allowPrivilegeEscalation`, `capabilities`, `readOnlyRootFilesystem` and `seLinuxOptions` exist **only** at container level — PodSecurity's `baseline` and `restricted` profiles name those specifically, so they cannot be satisfied from the pod block:

```yaml
containerSecurityContext:
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
```

It is deliberately not applied to the `oauth2-proxy` sidecar, which has its own spec.

**Clearing the pod-level defaults needs explicit nulls.** Helm merges maps, so `securityContext: {}` leaves `runAsUser: 1000` fully intact — it renders and looks like it worked. To actually run a container as the image ships it:

```yaml
securityContext:
  runAsUser: null
  runAsGroup: null
  fsGroup: null
```

The same applies to any other map in these values, `env.values` included.

### Scheduling Priority

| Parameter | Description | Default |
|-----------|-------------|---------|
| `priorityClassName` | PriorityClass for the pod | `""` (omitted) |

Mostly relevant to `kind: DaemonSet`. A node agent should generally outlive the workloads it serves under node pressure — a device plugin evicted off a node takes its advertised resource with it, and every pod requesting that resource goes `Pending`:

```yaml
priorityClassName: system-node-critical
```

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

### Runtime Class

| Parameter | Description | Default |
|-----------|-------------|---------|
| `runtimeClassName` | Pod runtime class (e.g. `nvidia` for GPU workloads) | `""` (omitted) |

Set to `nvidia` when using the [NVIDIA device plugin](https://github.com/NVIDIA/k8s-device-plugin) to ensure the container runtime can access the GPU:

```yaml
runtimeClassName: nvidia
```

### Extra Volumes and Volume Mounts

These inject arbitrary Kubernetes volumes into the pod spec and the main container. Any Kubernetes volume type is supported (`emptyDir`, `hostPath`, `configMap`, `nfs`, etc.).

| Parameter | Description | Default |
|-----------|-------------|---------|
| `extraVolumes` | List of volumes added to `spec.volumes` | `[]` |
| `extraVolumeMounts` | List of volume mounts added to the main container | `[]` |

```yaml
extraVolumes:
  - name: dshm
    emptyDir:
      medium: Memory
      sizeLimit: 1Gi

extraVolumeMounts:
  - name: dshm
    mountPath: /dev/shm
```

### Service Account

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create service account | `true` |
| `serviceAccount.annotations` | Service account annotations | `{}` |
| `serviceAccount.name` | Service account name | `""` (auto-generated) |

### ServiceMonitor (Prometheus Operator)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceMonitor.enabled` | Create a ServiceMonitor | `false` |
| `serviceMonitor.labels` | Extra labels on the ServiceMonitor (see warning below) | `{}` |
| `serviceMonitor.annotations` | ServiceMonitor annotations | `{}` |
| `serviceMonitor.namespace` | Namespace to create it in | `""` (release namespace) |
| `serviceMonitor.jobLabel` | Service label to use as the Prometheus `job` label | `""` |
| `serviceMonitor.namespaceSelector` | Namespaces to search for the Service | `{}` (own namespace) |
| `serviceMonitor.targetLabels` | Service labels to copy onto metrics | `[]` |
| `serviceMonitor.podTargetLabels` | Pod labels to copy onto metrics | `[]` |
| `serviceMonitor.endpoints` | Scrape endpoints, passed through verbatim | `[{port: http, path: /metrics, interval: 30s, scrapeTimeout: 10s}]` |

## Prometheus ServiceMonitor

Set `serviceMonitor.enabled: true` to expose the app's metrics to a Prometheus
Operator install. Requires the `monitoring.coreos.com/v1` CRDs to already exist.

```yaml
service:
  ports:
    - name: metrics
      port: 9130
      targetPort: 9130
      protocol: TCP

serviceMonitor:
  enabled: true
  labels:
    release: kube-prometheus-stack
  endpoints:
    - port: metrics
      path: /metrics
      interval: 60s
```

**The `release` label is usually required, not decorative.** A Prometheus
deployed by kube-prometheus-stack only adopts ServiceMonitors matching its
`serviceMonitorSelector`, which defaults to `release: <prometheus-release-name>`.
Leave it off and the object is created successfully, appears in
`kubectl get servicemonitor`, and is then **silently never scraped** — no error
anywhere. Check what your cluster actually selects on:

```bash
kubectl -n monitoring get prometheus \
  -o jsonpath='{.items[0].spec.serviceMonitorSelector}'
```

Two other things worth knowing:

- `endpoints[].port` is a port **name** from `service.ports[]`, not a number.
  A numeric value renders fine and then matches nothing.
- `endpoints` is passed straight through to the CRD, so any endpoint field the
  ServiceMonitor spec supports works here — `scheme`, `tlsConfig`,
  `bearerTokenSecret`, `basicAuth`, `relabelings`, `metricRelabelings`.

To verify the target is actually being scraped once deployed, check Prometheus's
target list rather than trusting that the object exists:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
curl -s localhost:9090/api/v1/targets | grep <your-app>
```

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

## oauth2-proxy Sidecar (Authelia SSO)

The chart can inject an [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) sidecar to protect any app with Authelia OIDC authentication. When enabled, the sidecar intercepts all traffic at the pod level before it reaches the app — no ingress annotation changes required.

**How it works:**
- The sidecar listens on port 4180 and proxies authenticated requests to `localhost:<app port>`
- The Kubernetes Service's `targetPort` is automatically overridden to 4180
- The ingress config stays unchanged (still points to the same service port number)
- A shared `.example.com` cookie means login once = access to all protected services

### Prerequisites

1. Authelia must be running with the `oauth2-proxy` OIDC client configured (see `authelia/values.yaml`)
2. The `oauth2-proxy-credentials` secret must exist in the **app's namespace**

### Step 1 — Create the credentials secret

Add to the app's manifest file (e.g. `myapp.yaml` referenced by `EXTRA_MANIFEST_FILE` in `.gitlab-ci.yml`):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: oauth2-proxy-credentials
  namespace: <your-app-namespace>
stringData:
  client-secret: "<same value as authelia namespace>"
  cookie-secret: "<same value as authelia namespace>"
```

### Step 2 — Enable in values.yaml

```yaml
oauth2proxy:
  enabled: true
  redirectUrl: https://yourapp.example.com/oauth2/callback
```

### Step 3 — Register the redirect URI in Authelia

Add one line to `authelia/values.yaml` under `configMap.identity_providers.oidc.clients[0].redirect_uris`:

```yaml
- https://yourapp.example.com/oauth2/callback
```

### Configuration reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `oauth2proxy.enabled` | Inject the oauth2-proxy sidecar | `false` |
| `oauth2proxy.image.repository` | oauth2-proxy image | `quay.io/oauth2-proxy/oauth2-proxy` |
| `oauth2proxy.image.tag` | oauth2-proxy image tag | `v7.9.0` |
| `oauth2proxy.issuerUrl` | Authelia OIDC issuer URL | `https://auth.example.com` |
| `oauth2proxy.clientId` | OIDC client ID | `oauth2-proxy` |
| `oauth2proxy.redirectUrl` | Callback URL for this app — **required when enabled** | `""` |
| `oauth2proxy.cookieDomain` | Shared cookie domain | `.example.com` |
| `oauth2proxy.existingSecret` | Secret name with `client-secret` and `cookie-secret` keys | `oauth2-proxy-credentials` |

### Full example

```yaml
image:
  repository: lscr.io/linuxserver/sonarr
  tag: latest

service:
  ipFamilyPolicy: PreferDualStack
  ports:
    - name: http
      port: 8989
      targetPort: 8989
      protocol: TCP

ingress:
  enabled: true
  className: cilium
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: sonarr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: sonarr-tls
      hosts:
        - sonarr.example.com

oauth2proxy:
  enabled: true
  redirectUrl: https://sonarr.example.com/oauth2/callback
```

---

## Examples

### GPU Workload (NVIDIA)

```yaml
image:
  repository: my-org/my-gpu-app
  tag: latest

runtimeClassName: nvidia

resources:
  limits:
    nvidia.com/gpu: "1"
  requests:
    nvidia.com/gpu: "1"

nodeSelector:
  nvidia.com/gpu.present: "true"

extraVolumes:
  - name: dshm
    emptyDir:
      medium: Memory
      sizeLimit: 1Gi

extraVolumeMounts:
  - name: dshm
    mountPath: /dev/shm
```

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
