#!/bin/bash

# 📊 DataOps: Start Pipeline Monitoring
# Inicia el monitoreo continuo del pipeline

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}📊 DataOps: Pipeline Monitoring${RESET}"
echo "================================="

# Check dependencies
echo -e "${YELLOW}📦 Checking dependencies...${RESET}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 not found${RESET}"
    exit 1
fi

# Install Python dependencies
pip3 install confluent-kafka --quiet || echo "Dependencies already installed"

# Set environment variables
echo -e "${YELLOW}🔧 Setting up environment...${RESET}"
cd ../../scripts/kafka
if [ -f ".env" ]; then
    source .env
    export KAFKA_BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_SERVERS:-pkc-your-cluster.region.aws.confluent.cloud:9092}"
fi

cd ../../dataops/monitoring

# Start monitoring
echo -e "${YELLOW}🚀 Starting pipeline monitoring...${RESET}"
echo -e "${BLUE}💡 Monitoring will run for 5 minutes. Press Ctrl+C to stop early.${RESET}"

python3 pipeline-monitor.py

echo -e "${GREEN}✅ Monitoring completed${RESET}"

# Show results
if [ -f "pipeline-monitoring-report.json" ]; then
    echo -e "${BLUE}📄 Monitoring report generated${RESET}"
    
    # Extract key metrics
    TOTAL_MESSAGES=$(python3 -c "import json; report=json.load(open('pipeline-monitoring-report.json')); print(report['summary']['total_messages'])")
    AVG_THROUGHPUT=$(python3 -c "import json; report=json.load(open('pipeline-monitoring-report.json')); print(f\"{report['summary']['avg_throughput']:.2f}\")")
    TOTAL_ERRORS=$(python3 -c "import json; report=json.load(open('pipeline-monitoring-report.json')); print(report['summary']['total_errors'])")
    
    echo -e "${GREEN}📊 Summary:${RESET}"
    echo -e "   📈 Total Messages: ${TOTAL_MESSAGES}"
    echo -e "   ⚡ Avg Throughput: ${AVG_THROUGHPUT} msg/sec"
    echo -e "   ❌ Total Errors: ${TOTAL_ERRORS}"
    
    if [ "$TOTAL_ERRORS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Errors detected. Check pipeline-monitor.log for details${RESET}"
    fi
else
    echo -e "${RED}❌ No monitoring report generated${RESET}"
fi