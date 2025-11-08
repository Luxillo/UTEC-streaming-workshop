#!/bin/bash

# 🧪 DataOps: Run Data Quality Tests
# Ejecuta tests de calidad de datos en el pipeline

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}🧪 DataOps: Data Quality Tests${RESET}"
echo "================================"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 not found${RESET}"
    exit 1
fi

# Install dependencies if needed
echo -e "${YELLOW}📦 Installing dependencies...${RESET}"
pip3 install confluent-kafka --quiet || echo "Dependencies already installed"

# Set environment variables
echo -e "${YELLOW}🔧 Setting up environment...${RESET}"
cd ../../scripts/kafka
if [ -f ".env" ]; then
    source .env
    export KAFKA_BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_SERVERS:-pkc-your-cluster.region.aws.confluent.cloud:9092}"
fi

cd ../../dataops/tests

# Run data quality tests
echo -e "${YELLOW}🔍 Running data quality tests...${RESET}"
python3 data-quality-tests.py

# Check results
if [ -f "data-quality-report.json" ]; then
    echo -e "${GREEN}✅ Data quality tests completed${RESET}"
    echo -e "${BLUE}📄 Report generated: data-quality-report.json${RESET}"
    
    # Extract success rate
    SUCCESS_RATE=$(python3 -c "import json; report=json.load(open('data-quality-report.json')); print(report['summary']['success_rate'])")
    
    if (( $(echo "$SUCCESS_RATE >= 80" | bc -l) )); then
        echo -e "${GREEN}🎉 Data quality: GOOD (${SUCCESS_RATE}%)${RESET}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  Data quality: NEEDS ATTENTION (${SUCCESS_RATE}%)${RESET}"
        exit 1
    fi
else
    echo -e "${RED}❌ Data quality tests failed${RESET}"
    exit 1
fi