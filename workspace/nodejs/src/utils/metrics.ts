/**
 * Prometheus Metrics
 * Application metrics collection
 */

import { Request, Response, NextFunction } from 'express';
import client from 'prom-client';
import { config } from '../config';

// Create a Registry
const register = new client.Registry();

// Add default metrics
client.collectDefaultMetrics({
  register,
  prefix: 'nexusforge_nodejs_',
});

// Custom metrics
const httpRequestDuration = new client.Histogram({
  name: 'nexusforge_nodejs_http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.001, 0.01, 0.1, 0.5, 1, 2, 5],
  registers: [register],
});

const httpRequestTotal = new client.Counter({
  name: 'nexusforge_nodejs_http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

const activeConnections = new client.Gauge({
  name: 'nexusforge_nodejs_active_connections',
  help: 'Number of active connections',
  registers: [register],
});

/**
 * Metrics middleware
 */
export const metricsMiddleware = (req: Request, res: Response, next: NextFunction): void => {
  if (!config.monitoring.enableMetrics) {
    next();
    return;
  }

  // Skip metrics endpoint itself
  if (req.path === '/metrics') {
    next();
    return;
  }

  const startTime = Date.now();

  // Increment active connections
  activeConnections.inc();

  // Record metrics when response finishes
  res.on('finish', () => {
    const duration = (Date.now() - startTime) / 1000;

    const labels = {
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode.toString(),
    };

    httpRequestDuration.observe(labels, duration);
    httpRequestTotal.inc(labels);
    activeConnections.dec();
  });

  next();
};

/**
 * Metrics endpoint handler
 */
export const metricsEndpoint = async (req: Request, res: Response): Promise<void> => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
};

// Export metrics for testing
export { register, httpRequestDuration, httpRequestTotal, activeConnections };
