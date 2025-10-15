# Guestbook Redis Helm Chart

This Helm chart deploys Redis 7.2.4 for use with the guestbook application.

## Overview

This chart deploys a single Redis instance that can be accessed by the guestbook application within the Kubernetes cluster.

## Configuration

The chart is configured with the following key settings:

- **Redis Version**: 7.2.4
- **Service Type**: ClusterIP (internal cluster access only)
- **Port**: 6379 (standard Redis port)
- **Resources**: 
  - CPU: 100m request/limit
  - Memory: 128Mi request/limit
- **Probes**:
  - Liveness: TCP socket check on Redis port
  - Readiness: Redis CLI ping command

## Installation

To install the chart:

```bash
helm install redis ./guestbook-redis
```

Or with a custom release name:

```bash
helm install my-redis ./guestbook-redis
```

## Accessing Redis from Guestbook

The Redis service will be accessible within the cluster at:

```
<release-name>-guestbook-redis:6379
```

For example, if you installed with the release name `redis`, the service will be:

```
redis-guestbook-redis:6379
```

If you used the default release name `guestbook-redis`, the service will be:

```
guestbook-redis:6379
```

## Connecting from Guestbook Chart

In your guestbook application, configure the Redis connection using the service name as the hostname:

- **Host**: `<release-name>-guestbook-redis` (or the service name shown after installation)
- **Port**: `6379`

Example connection string:
```
redis://<release-name>-guestbook-redis:6379
```

## Customization

You can override values in `values.yaml` by creating a custom values file or using `--set` flags:

```bash
helm install redis ./guestbook-redis --set replicaCount=2
```

Or with a custom values file:

```bash
helm install redis ./guestbook-redis -f custom-values.yaml
```

## Uninstallation

To uninstall/delete the deployment:

```bash
helm uninstall redis
```

## Values

Key values that can be configured:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of Redis replicas | `1` |
| `image.repository` | Redis image repository | `redis` |
| `image.tag` | Redis image tag | `7.2.4` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Redis service port | `6379` |
| `resources.limits.cpu` | CPU limit | `100m` |
| `resources.limits.memory` | Memory limit | `128Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
