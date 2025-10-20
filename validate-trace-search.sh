#!/bin/bash
# Trace Search Validation Script
# Tests Tempo search API and validates Grafana dashboard configuration

set -e

PROJECT="${PROJECT:-lab}"
LAB_HOST="${LAB_HOST:-localhost}"

echo "========================================"
echo "Trace Search Validation Script"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# 1. Check if containers are running
echo "1. Checking container status..."
TEMPO_STATUS=$(docker compose -p ${PROJECT} ps tempo --format json 2>/dev/null | jq -r '.[0].State // "not running"' 2>/dev/null || echo "not running")
GRAFANA_STATUS=$(docker compose -p ${PROJECT} ps grafana --format json 2>/dev/null | jq -r '.[0].State // "not running"' 2>/dev/null || echo "not running")

if [ "$TEMPO_STATUS" = "running" ]; then
    print_status 0 "Tempo container is running"
else
    print_status 1 "Tempo container is NOT running (Status: $TEMPO_STATUS)"
    echo "   Run: docker compose -p ${PROJECT} up -d tempo"
    exit 1
fi

if [ "$GRAFANA_STATUS" = "running" ]; then
    print_status 0 "Grafana container is running"
else
    print_status 1 "Grafana container is NOT running (Status: $GRAFANA_STATUS)"
    echo "   Run: docker compose -p ${PROJECT} up -d grafana"
    exit 1
fi

echo ""

# 2. Check Tempo configuration for search_enabled
echo "2. Checking Tempo configuration..."
if grep -q "search_enabled: true" otel-collector/tempo.yml; then
    print_status 0 "search_enabled is set to true in tempo.yml"
else
    print_status 1 "search_enabled is NOT enabled in tempo.yml"
    echo "   Add 'search_enabled: true' to otel-collector/tempo.yml"
    exit 1
fi

echo ""

# 3. Test Tempo health endpoint
echo "3. Testing Tempo health endpoint..."
TEMPO_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://${LAB_HOST}:3200/ready || echo "000")
if [ "$TEMPO_HEALTH" = "200" ]; then
    print_status 0 "Tempo health endpoint responding (HTTP 200)"
else
    print_status 1 "Tempo health endpoint not responding (HTTP $TEMPO_HEALTH)"
    echo "   Check: docker compose -p ${PROJECT} logs tempo"
    exit 1
fi

echo ""

# 4. Test Tempo search API
echo "4. Testing Tempo search API..."
echo "   Querying for recent traces (limit 5)..."

SEARCH_RESULT=$(curl -s "http://${LAB_HOST}:3200/api/search?limit=5&start=$(date -d '1 hour ago' +%s)&end=$(date +%s)" || echo '{"error": "curl failed"}')

# Check if we got a valid JSON response
if echo "$SEARCH_RESULT" | jq empty 2>/dev/null; then
    TRACE_COUNT=$(echo "$SEARCH_RESULT" | jq '.traces | length // 0' 2>/dev/null || echo "0")

    if [ "$TRACE_COUNT" -gt 0 ]; then
        print_status 0 "Tempo search API returned $TRACE_COUNT traces"
        echo ""
        echo "   Sample trace IDs:"
        echo "$SEARCH_RESULT" | jq -r '.traces[0:3][] | "   - \(.traceID) (service: \(.rootServiceName // "unknown"))"' 2>/dev/null || echo "   (Unable to parse trace details)"
    else
        print_status 1 "Tempo search API returned 0 traces"
        echo "   This may be normal if no traces have been generated yet"
        echo "   Generate traffic by visiting: http://${LAB_HOST}:8080"
        echo "   Then re-run this script"
    fi
else
    print_status 1 "Tempo search API returned invalid response"
    echo "   Response: $SEARCH_RESULT"
    exit 1
fi

echo ""

# 5. Check Grafana datasource configuration
echo "5. Checking Grafana datasource configuration..."
if grep -q 'uid: tempo' grafana/provisioning/datasources/datasources.yml; then
    print_status 0 "Tempo datasource has stable UID 'tempo'"
else
    print_status 1 "Tempo datasource UID not set correctly"
    echo "   Ensure grafana/provisioning/datasources/datasources.yml has 'uid: tempo'"
    exit 1
fi

if grep -q '"datasource": {"type": "tempo", "uid": "tempo"}' grafana/dashboards/end-to-end-tracing.json; then
    print_status 0 "Dashboard panels correctly reference Tempo datasource"
else
    print_status 1 "Dashboard panels may have incorrect datasource reference"
    echo "   Check grafana/dashboards/end-to-end-tracing.json"
fi

echo ""

# 6. Check dashboard query configuration
echo "6. Checking Trace Search panel configuration..."
if grep -q '"queryType": "traceqlSearch"' grafana/dashboards/end-to-end-tracing.json; then
    print_status 0 "Trace Search panel uses correct queryType (traceqlSearch)"
elif grep -q '"queryType": "traceql"' grafana/dashboards/end-to-end-tracing.json; then
    print_status 1 "Trace Search panel uses old queryType (traceql)"
    echo "   Consider updating to 'traceqlSearch' for better search functionality"
else
    print_status 1 "Trace Search panel queryType not found"
fi

echo ""

# 7. Final recommendations
echo "========================================"
echo "Validation Complete"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Generate traffic: Visit http://${LAB_HOST}:8080 and create some tasks"
echo "2. View Trace Search: http://${LAB_HOST}:3000/d/end-to-end-tracing/"
echo "3. If Trace Search is still empty, check Grafana panel editor:"
echo "   - Ensure Query Type is set to 'Search' or 'TraceQL Search'"
echo "   - Try a simple TraceQL query: {}"
echo "   - Check time range (last 1 hour should show recent traces)"
echo ""
echo "Troubleshooting commands:"
echo "  docker compose -p ${PROJECT} logs tempo --tail 50"
echo "  docker compose -p ${PROJECT} logs grafana --tail 50"
echo "  curl 'http://${LAB_HOST}:3200/api/search?limit=20' | jq"
echo ""
