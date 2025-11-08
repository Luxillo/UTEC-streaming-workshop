#!/bin/bash

# 🚀 DataOps: Automated Pipeline Setup
# Automatiza el setup completo del pipeline de streaming

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}🚀 DataOps: Automated Pipeline Setup${RESET}"
echo "========================================"

# 1. Validar prerequisitos
echo -e "${YELLOW}📋 Validating prerequisites...${RESET}"
if ! command -v confluent &> /dev/null; then
    echo -e "${RED}❌ Confluent CLI not found${RESET}"
    exit 1
fi

# Instalar dependencias Python
echo -e "${YELLOW}📦 Installing Python dependencies...${RESET}"
pip3 install confluent-kafka avro-python3 fastavro --quiet || echo "Dependencies already installed"

# 2. Setup environment
echo -e "${YELLOW}🔧 Setting up environment...${RESET}"
KAFKA_DIR="$(pwd)/scripts/kafka"

if [ ! -d "$KAFKA_DIR" ]; then
    echo -e "${RED}❌ Kafka scripts directory not found: $KAFKA_DIR${RESET}"
    exit 1
fi

cd "$KAFKA_DIR"
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env file not found. Please configure your API keys${RESET}"
    exit 1
fi
source .env

# 3. Create topics
echo -e "${YELLOW}📊 Creating Kafka topics...${RESET}"
confluent kafka topic create crypto-prices --partitions 3 --config retention.ms=604800000 --config cleanup.policy=delete || true
confluent kafka topic create crypto-prices-exploded --partitions 3 --config retention.ms=604800000 --config cleanup.policy=delete || true

# 4. Deploy connector
echo -e "${YELLOW}🔌 Deploying HTTP Source Connector...${RESET}"
./deploy-connector.sh

# 5. Validate setup
echo -e "${YELLOW}✅ Validating setup...${RESET}"
./validate-connector.sh

echo -e "${GREEN}🎉 Pipeline setup completed successfully!${RESET}"
echo -e "${BLUE}💡 Next steps:${RESET}"
echo -e "   1. Run data quality tests: ./dataops/tests/run-data-quality-tests.sh"
echo -e "   2. Start monitoring: ./dataops/monitoring/start-monitoring.sh"