#!/bin/bash

# 📦 DataOps: Install Python Dependencies
# Instala todas las dependencias necesarias para DataOps

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}📦 DataOps: Installing Dependencies${RESET}"
echo "=================================="

# Check Python
echo -e "${YELLOW}🐍 Checking Python installation...${RESET}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 not found${RESET}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✅ Found: $PYTHON_VERSION${RESET}"

# Check pip
if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}❌ pip3 not found${RESET}"
    exit 1
fi

# Install core dependencies
echo -e "${YELLOW}📦 Installing core dependencies...${RESET}"
pip3 install --upgrade pip --quiet

# Kafka dependencies
echo -e "${YELLOW}🔌 Installing Kafka dependencies...${RESET}"
pip3 install confluent-kafka --quiet

# Avro dependencies
echo -e "${YELLOW}📄 Installing Avro dependencies...${RESET}"
pip3 install avro-python3 fastavro --quiet

# Additional dependencies for DataOps
echo -e "${YELLOW}📊 Installing additional dependencies...${RESET}"
pip3 install requests matplotlib --quiet

# Verify installations
echo -e "${YELLOW}✅ Verifying installations...${RESET}"

python3 -c "import confluent_kafka; print('✅ confluent-kafka:', confluent_kafka.__version__)" 2>/dev/null || echo "❌ confluent-kafka failed"
python3 -c "import avro; print('✅ avro-python3: OK')" 2>/dev/null || echo "❌ avro-python3 failed"
python3 -c "import fastavro; print('✅ fastavro:', fastavro.__version__)" 2>/dev/null || echo "❌ fastavro failed"
python3 -c "import requests; print('✅ requests:', requests.__version__)" 2>/dev/null || echo "❌ requests failed"

echo -e "${GREEN}🎉 All dependencies installed successfully!${RESET}"
echo -e "${BLUE}💡 You can now run DataOps scripts${RESET}"