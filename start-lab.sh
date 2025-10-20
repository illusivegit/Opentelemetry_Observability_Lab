#!/bin/bash

# OpenTelemetry Observability Lab - Startup Script
# Aligned with Jenkins pipeline deployment pattern
echo "=================================="
echo "OpenTelemetry Observability Lab"
echo "=================================="
echo ""

# Configuration - can be overridden by environment variable
# This allows single source of truth when used in Jenkins pipeline
PROJECT="${PROJECT:-lab}"

echo "📦 Using project name: ${PROJECT}"
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
docker compose -p ${PROJECT} down -v 2>/dev/null

# Start services (aligned with Jenkins pipeline)
echo ""
echo "🚀 Starting services with project name: ${PROJECT}"
echo "   (This matches the Jenkins pipeline deployment pattern)"
echo ""
export DOCKER_BUILDKIT=1
    # ------------------------------------------------------------------------------
    # Enable Docker BuildKit for consistent and enhanced build behavior
    # ------------------------------------------------------------------------------

    # 1. Overrides Local Defaults
    #    Not all systems have Docker BuildKit enabled by default. By explicitly
    #    exporting DOCKER_BUILDKIT=1, we ensure that Docker uses the BuildKit engine
    #    regardless of the user's local Docker configuration or version. This avoids
    #    discrepancies between environments where BuildKit may or may not be active.

    # 2. Standardizes Build Features
    #    BuildKit supports advanced Dockerfile syntax such as:
    #      - RUN --mount=type=secret
    #      - COPY --chmod
    #    These features are not supported by the legacy builder. Without BuildKit,
    #    such instructions may fail silently or be ignored, leading to unpredictable
    #    or broken builds. Enabling BuildKit ensures these features work as intended.

    # 3. Aligns CI/CD and Local Builds
    #    In continuous integration environments like Jenkins, BuildKit may already be
    #    preconfigured. By enabling it explicitly in this script, we guarantee that
    #    local development builds behave the same way as those in CI/CD pipelines.
    #    This alignment reduces "works on my machine" issues and improves reliability.

    # 4. Improves Caching and Performance
    #    BuildKit introduces a smarter caching mechanism that speeds up builds and
    #    reduces redundant steps. It enables parallel execution and better reuse of
    #    intermediate layers, resulting in faster and more reproducible builds across
    #    different machines and environments.

    # 5. Supports Secure Features
    #    BuildKit allows secure handling of sensitive data during builds, including:
    #      - Secrets management via --mount=type=secret
    #      - SSH forwarding for accessing private repositories
    #    These capabilities are unavailable in the legacy builder. Enabling BuildKit
    #    ensures that secure workflows and advanced build scenarios are supported
    #    consistently and safely.

    # ------------------------------------------------------------------------------
docker compose -p ${PROJECT} up -d --build

# Wait for services to be healthy
echo ""
echo "⏳ Waiting for services to start..."
sleep 10

# Display container status (aligned with Jenkins pipeline)
echo ""
echo "📋 Container Status:"
docker compose -p ${PROJECT} ps

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
echo "   - View logs:    docker compose -p ${PROJECT} logs -f [service-name]"
echo "   - Stop lab:     docker compose -p ${PROJECT} down"
echo "   - Restart:      docker compose -p ${PROJECT} restart [service-name]"
echo "   - List status:  docker compose -p ${PROJECT} ps"
echo ""
echo "⚠️  Note: When using project name '${PROJECT}', always include '-p ${PROJECT}'"
echo "   in your docker compose commands for proper container management."
echo ""
echo "=================================="
