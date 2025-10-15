# Guestbook Helm Chart

This Helm chart deploys the guestbook application that connects to Redis.

## Prerequisites

The Redis chart must be deployed first:

```bash
helm install guestbook-redis ./guestbook-redis
```

## Installation

Deploy the guestbook application:

```bash
helm install guestbook ./guestbook
```

## Configuration

### Redis Connection

The chart is configured to connect to Redis using the `REDIS_HOST` environment variable.

**Note for Rancher Desktop Users:**
Due to DNS resolution issues in Rancher Desktop, the default configuration uses the Redis service's ClusterIP directly instead of the DNS name. If you're using a production Kubernetes cluster with reliable DNS, you can use the service name instead.

**Current Redis configuration in values.yaml (for Rancher Desktop):**
```yaml
redis:
  host: "10.43.226.175"  # Direct ClusterIP (Rancher Desktop workaround)
```

**For production clusters with working DNS:**
```yaml
redis:
  host: "guestbook-redis.default.svc.cluster.local"
```

### Custom Redis Release Name

If you deployed Redis with a different release name, you need to update the Redis host value:

```bash
# If you deployed Redis as:
helm install my-redis ./guestbook-redis

# Then deploy guestbook with:
helm install guestbook ./guestbook --set redis.host=my-redis-guestbook-redis
```

Or create a custom values file:

```yaml
# custom-values.yaml
redis:
  host: "my-redis-guestbook-redis"
```

And install with:
```bash
helm install guestbook ./guestbook -f custom-values.yaml
```

## Environment Variables

The guestbook pod receives the following environment variable:
- `REDIS_HOST`: The hostname of the Redis service

## Service

The guestbook application is exposed via a LoadBalancer service on port 8080.

To get the external IP:
```bash
kubectl get svc guestbook-service
```

## Uninstallation

```bash
helm uninstall guestbook
helm uninstall guestbook-redis
