#!/bin/bash
# Diagnostic script for Grafana metrics dropdown issue
# This verifies that Prometheus's label API endpoint is accessible from Grafana

echo "=========================================="
echo "Grafana → Prometheus Connectivity Check"
echo "=========================================="
echo ""

# Check if containers are running
echo "1. Checking if containers are running..."
docker ps --filter "name=grafana" --filter "name=prometheus" --format "table {{.Names}}\t{{.Status}}"
echo ""

# Check Grafana can reach Prometheus basic endpoint
echo "2. Testing Grafana → Prometheus basic connectivity..."
docker exec grafana sh -c 'command -v curl >/dev/null 2>&1 || apk add --no-cache curl >/dev/null 2>&1'
docker exec grafana curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "http://prometheus:9090/-/ready"
echo ""

# Check the critical label/__name__/values endpoint (GET method)
echo "3. Testing metric names endpoint (GET - what Builder needs)..."
START=$(date -d "1 hour ago" +%s 2>/dev/null || date -v-1H +%s)
END=$(date +%s)
docker exec grafana curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
  "http://prometheus:9090/api/v1/label/__name__/values?start=$START&end=$END"
echo ""

# Actually fetch some metric names to see if we get data
echo "4. Fetching actual metric names (should see a list)..."
docker exec grafana curl -s "http://prometheus:9090/api/v1/label/__name__/values" | head -c 500
echo ""
echo ""

# Check if a normal instant query works (Code mode)
echo "5. Testing instant query endpoint (what Code mode uses)..."
docker exec grafana curl -s "http://prometheus:9090/api/v1/query?query=up" | head -c 400
echo ""
echo ""

# Check Prometheus time vs system time
echo "6. Checking for time skew..."
echo "   VM system time:       $(date)"
echo "   Prometheus container: $(docker exec prometheus date)"
echo ""

# Check if Prometheus has scraped any data recently
echo "7. Checking if Prometheus has recent data..."
docker exec grafana curl -s "http://prometheus:9090/api/v1/query?query=up" | \
  grep -o '"result":\[[^]]*\]' | head -c 300
echo ""
echo ""

echo "=========================================="
echo "Current Grafana Prometheus datasource config:"
echo "=========================================="
docker exec grafana cat /etc/grafana/provisioning/datasources/datasources.yml | grep -A 8 "name: Prometheus"
echo ""

echo "=========================================="
echo "Diagnosis complete!"
echo "=========================================="
