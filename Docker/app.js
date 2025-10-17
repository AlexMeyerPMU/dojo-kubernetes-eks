const express = require('express');
const redis = require('redis');
const promClient = require('prom-client');
const os = require('os');

// Create Redis client
const redisClient = redis.createClient({
    url: `redis://${process.env.REDIS_HOST || 'localhost'}:6379`
});

// Prometheus metrics
const httpRequestsTotal = new promClient.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'endpoint']
});

const httpRequestDuration = new promClient.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'endpoint']
});

const redisOperationsTotal = new promClient.Counter({
    name: 'redis_operations_total',
    help: 'Total number of Redis operations',
    labelNames: ['operation']
});

const app = express();

// Middleware to count total HTTP requests
app.use((req, res, next) => {
    httpRequestsTotal.labels(req.method, req.path).inc();
    next();
});

app.get('/lrange/:key', async (req, res) => {
    const end = httpRequestDuration.labels(req.method, '/lrange').startTimer();
    try {
        const key = req.params.key;
        const members = await redisClient.lRange(key, 0, -1);
        res.json(members);
        redisOperationsTotal.labels('lrange').inc();
    } catch (error) {
        res.status(500).send(error.message);
    } finally {
        end();
    }
});

app.get('/rpush/:key/:value', async (req, res) => {
    const end = httpRequestDuration.labels(req.method, '/rpush').startTimer();
    try {
        const { key, value } = req.params;
        await redisClient.rPush(key, value);
        const members = await redisClient.lRange(key, 0, -1);
        res.json(members);
        redisOperationsTotal.labels('rpush').inc();
    } catch (error) {
        res.status(500).send(error.message);
    } finally {
        end();
    }
});

app.get('/info', async (req, res) => {
    const end = httpRequestDuration.labels(req.method, '/info').startTimer();
    try {
        const info = await redisClient.info();
        res.send(info);
        redisOperationsTotal.labels('info').inc();
    } catch (error) {
        res.status(500).send(error.message);
    } finally {
        end();
    }
});

app.get('/env', (req, res) => {
    const end = httpRequestDuration.labels(req.method, '/env').startTimer();
    try {
        res.json(process.env);
    } catch (error) {
        res.status(500).send(error.message);
    } finally {
        end();
    }
});

app.get('/healthz', async (req, res) => {
    const end = httpRequestDuration.labels(req.method, '/healthz').startTimer();
    try {
        await redisClient.ping();
        res.sendStatus(200);
        redisOperationsTotal.labels('ping').inc();
    } catch (error) {
        res.status(500).send(error.message);
    } finally {
        end();
    }
});

// Prometheus metrics endpoint
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', promClient.register.contentType);
    res.end(await promClient.register.metrics());
});

async function main() {
    await redisClient.connect();

    app.listen(3000, () => {
        console.log('Server is running on port 3000');
    });
}

main().catch(console.error);

process.on('SIGINT', async () => {
    await redisClient.quit();
    process.exit(0);
});