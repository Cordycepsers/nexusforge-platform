/**
 * Metrics Middleware
 * Prometheus metrics collection
 */

package middleware

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	httpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "nexusforge_go_http_request_duration_seconds",
			Help:    "Duration of HTTP requests in seconds",
			Buckets: []float64{0.001, 0.01, 0.1, 0.5, 1, 2, 5},
		},
		[]string{"method", "path", "status"},
	)

	httpRequestTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "nexusforge_go_http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "path", "status"},
	)

	activeConnections = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "nexusforge_go_active_connections",
			Help: "Number of active connections",
		},
	)
)

// Metrics returns a gin middleware for collecting Prometheus metrics
func Metrics() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Skip metrics endpoint itself
		if c.Request.URL.Path == "/metrics" {
			c.Next()
			return
		}

		start := time.Now()
		activeConnections.Inc()

		c.Next()

		duration := time.Since(start).Seconds()
		status := strconv.Itoa(c.Writer.Status())
		path := c.FullPath()
		if path == "" {
			path = c.Request.URL.Path
		}

		httpRequestDuration.WithLabelValues(c.Request.Method, path, status).Observe(duration)
		httpRequestTotal.WithLabelValues(c.Request.Method, path, status).Inc()
		activeConnections.Dec()
	}
}
