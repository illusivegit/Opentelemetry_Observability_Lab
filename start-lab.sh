#!/bin/bash

# OpenTelemetry Observability Lab - Startup Script
echo "=================================="
echo "OpenTelemetry Observability Lab"
echo "=================================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

echo "✅ Docker is running"
echo ""

# Check if docker compose is available
if ! docker compose version &> /dev/null; then
    echo "❌ Error: docker compose is not installed. Please install it and try again."
    exit 1
fi

echo "✅ docker compose is available"
echo ""

# Stop any existing containers
echo "🧹 Cleaning up existing containers..."
docker compose down -v 2>/dev/null

# Start services
echo ""
echo "🚀 Starting services..."
docker compose up -d

# Wait for services to be healthy
echo ""
echo "⏳ Waiting for services to start..."
sleep 10

# Check service health
echo ""
echo "🔍 Checking service health..."
echo ""

# Check OTEL Collector
if curl -s http://localhost:13133 > /dev/null 2>&1; then
    echo "✅ OpenTelemetry Collector: Healthy"
else
    echo "⚠️  OpenTelemetry Collector: Starting..."
fi

# Check Backend
if curl -s http://localhost:5000/health > /dev/null 2>&1; then
    echo "✅ Flask Backend: Healthy"
else
    echo "⚠️  Flask Backend: Starting..."
fi

# Check Grafana
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo "✅ Grafana: Healthy"
else
    echo "⚠️  Grafana: Starting..."
fi

# Check Prometheus
if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo "✅ Prometheus: Healthy"
else
    echo "⚠️  Prometheus: Starting..."
fi

# Check Tempo
if curl -s http://localhost:3200/ready > /dev/null 2>&1; then
    echo "✅ Tempo: Healthy"
else
    echo "⚠️  Tempo: Starting..."
fi

# Check Loki
if curl -s http://localhost:3100/ready > /dev/null 2>&1; then
    echo "✅ Loki: Healthy"
else
    echo "⚠️  Loki: Starting..."
fi

echo ""
echo "=================================="
echo "🎉 Lab is ready!"
echo "=================================="
echo ""
echo "📊 Access Points:"
echo "   Frontend:    http://localhost:8080"
echo "   Grafana:     http://localhost:3000"
echo "   Prometheus:  http://localhost:9090"
echo "   Tempo:       http://localhost:3200"
echo ""
echo "📚 Next Steps:"
echo "   1. Open the frontend: http://localhost:8080"
echo "   2. Create some tasks to generate telemetry"
echo "   3. View traces in Grafana: http://localhost:3000"
echo "   4. Check the SLI/SLO Dashboard"
echo ""
echo "💡 Tips:"
echo "   - View logs: docker compose logs -f [service-name]"
echo "   - Stop lab:  docker compose down"
echo "   - Restart:   docker compose restart [service-name]"
echo ""
echo "=================================="
