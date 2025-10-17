# Metrics Sidecar Implementation

## Overview

This document describes the sidecar container pattern implemented for metrics collection in both the guestbook and guestbook-redis Helm charts. The sidecar pattern follows Kubernetes best practices by separating concerns - the main application container focuses on business logic while a dedicated sidecar container handles metrics exposure.

## Benefits of the Sidecar Pattern

1. **Separation of Concerns**: Main application code doesn't need to implement metrics endpoints
2. **Flexibility**: Easy to swap or upgrade metrics exporters without touching application code
3. **Resource Isolation**: Metrics collection has dedicated resource limits
4. **Standardization**: Consistent metrics format across different application types
5. **Security**: Reduced attack surface on main application container

## Implementation Details

### Guestbook Chart

#### Sidecar Container
- **Image**: `nginx:1.25-alpine`
- **Purpose**: Acts as a reverse proxy for the guestbook application's `/metrics` endpoint
- **Port**: 9090
- **Configuration**: Proxies requests from port 9090 to the main container's `http://localhost:3000/metrics`

#### Files Modified/Created
- `values.yaml`: Added metrics.sidecar configuration
- `templates/deployment.yaml`: Added metrics-proxy sidecar container with nginx
- `templates/service.yaml`: Added metrics port (9090)
- `templates/servicemonitor.yaml`: Updated to scrape from sidecar's metrics port
- `templates/metrics-configmap.yaml`: **New file** - Nginx configuration for proxying metrics

#### Configuration
```yaml
metrics:
  enabled: true
  sidecar:
    enabled: true
    image:
      repository: nginx
      tag: "1.25-alpine"
      pullPolicy: IfNotPresent
    port: 9090
    resources:
      limits:
        cpu: 50m
        memory: 64Mi
      requests:
        cpu: 10m
        memory: 32Mi
```

#### Why Nginx Reverse Proxy?
The guestbook application already exposes Prometheus-compatible metrics on `/metrics`. The nginx sidecar acts as a dedicated metrics gateway that:
- Provides a separate port for metrics collection (port isolation)
- Adds health check endpoint (`/health`)
- Can be enhanced with rate limiting, authentication, or caching if needed
- Follows the sidecar pattern while respecting existing application capabilities

### Guestbook-Redis Chart

#### Sidecar Container
- **Image**: `oliver006/redis_exporter:v1.55.0`
- **Purpose**: Exports Redis metrics in Prometheus format
- **Port**: 9121
- **Configuration**: Connects to `localhost:6379` to collect Redis metrics

#### Files Created/Modified
- `values.yaml`: Added metrics.sidecar configuration
- `templates/deployment.yaml`: Added redis-exporter sidecar container
- `templates/service.yaml`: Added metrics port (9121)
- `templates/servicemonitor.yaml`: **New file** - Created ServiceMonitor for Redis

#### Configuration
```yaml
metrics:
  enabled: true
  sidecar:
    enabled: true
    image:
      repository: oliver006/redis_exporter
      tag: "v1.55.0"
      pullPolicy: IfNotPresent
    port: 9121
    resources:
      limits:
        cpu: 50m
        memory: 64Mi
      requests:
        cpu: 10m
        memory: 32Mi
```

## How It Works

### Architecture

```
┌─────────────────────────────────────────┐
│              Pod                        │
│                                         │
│  ┌──────────────┐  ┌─────────────────┐ │
│  │              │  │                 │ │
│  │ Application  │  │ Metrics         │ │
│  │ Container    │──│ Exporter        │ │
│  │              │  │ (Sidecar)       │ │
│  │ Port: 3000   │  │                 │ │
│  │ /metrics     │  │ Port: 9090      │ │
│  │              │  │ /metrics        │ │
│  └──────────────┘  └─────────────────┘ │
│         │                    │          │
└─────────┼────────────────────┼──────────┘
          │                    │
          │                    │
          └────────────────────┴──────────
                               │
                               │
                    ┌──────────▼─────────┐
                    │   ServiceMonitor   │
                    │   (Prometheus)     │
                    └────────────────────┘
```

### Data Flow

1. **Application Container**: Runs the main application and exposes metrics on `/metrics` endpoint
2. **Sidecar Container**: 
   - Scrapes metrics from the application container (via localhost)
   - Transforms/enriches the metrics if needed
   - Exposes Prometheus-compatible metrics on its own port
3. **Service**: Exposes both application port and metrics port
4. **ServiceMonitor**: Configures Prometheus to scrape metrics from the sidecar's port

## Usage

### Deploying Guestbook with Metrics Sidecar

```bash
# Install with default sidecar enabled
helm install guestbook ./Kubernetes/guestbook

# Or upgrade existing installation
helm upgrade guestbook ./Kubernetes/guestbook
```

### Deploying Guestbook-Redis with Metrics Sidecar

```bash
# Install with default sidecar enabled
helm install guestbook-redis ./Kubernetes/guestbook-redis

# Or upgrade existing installation
helm upgrade guestbook-redis ./Kubernetes/guestbook-redis
```

### Disabling Sidecar (if needed)

If you want to disable the sidecar and use direct application metrics:

```bash
# For guestbook
helm install guestbook ./Kubernetes/guestbook --set metrics.sidecar.enabled=false

# For guestbook-redis
helm install guestbook-redis ./Kubernetes/guestbook-redis --set metrics.sidecar.enabled=false
```

## Verifying the Setup

### Check if Sidecar is Running

```bash
# For guestbook
kubectl get pods -l app=guestbook
kubectl describe pod <guestbook-pod-name>

# For guestbook-redis
kubectl get pods -l app.kubernetes.io/name=guestbook-redis
kubectl describe pod <redis-pod-name>
```

You should see two containers in each pod.

### Check ServiceMonitor

```bash
# For guestbook
kubectl get servicemonitor guestbook-servicemonitor -o yaml

# For guestbook-redis
kubectl get servicemonitor -l app.kubernetes.io/name=guestbook-redis -o yaml
```

### Verify Metrics Endpoint

```bash
# Port-forward to access metrics directly
kubectl port-forward <pod-name> 9090:9090  # for guestbook
kubectl port-forward <pod-name> 9121:9121  # for redis

# Then access metrics
curl http://localhost:9090/metrics  # guestbook metrics
curl http://localhost:9121/metrics  # redis metrics
```

### Check Prometheus Targets

In Prometheus UI, navigate to Status → Targets and verify that both `guestbook` and `guestbook-redis` targets are showing as "UP".

## Resource Consumption

The sidecar containers have minimal resource requirements:

- **CPU**: 10m (request) to 50m (limit)
- **Memory**: 32Mi (request) to 64Mi (limit)

These lightweight sidecars add minimal overhead to your pods while providing comprehensive metrics collection.

## Troubleshooting

### Sidecar Container Not Starting

Check the pod events and logs:
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name> -c metrics-proxy     # guestbook
kubectl logs <pod-name> -c redis-exporter    # redis
```

### Prometheus Not Scraping Metrics

1. Verify ServiceMonitor is created and has the correct labels
2. Check that the service has the metrics port exposed
3. Ensure Prometheus has the correct service monitor selector
4. Check Prometheus operator logs for any issues

### No Metrics Available

1. Verify the application container is exposing metrics on its endpoint
2. Check sidecar container logs for connection errors
3. Ensure the sidecar configuration points to the correct application endpoint

## Future Enhancements

Possible improvements to consider:

1. Add custom metrics configuration via ConfigMaps
2. Implement metric filtering or transformation
3. Add authentication for metrics endpoints
4. Configure alert rules based on collected metrics
5. Add dashboards for visualizing metrics in Grafana
