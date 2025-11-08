#!/bin/bash
# Setup Enhanced con validaciones adicionales

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}🚀 Enhanced DataOps Setup${RESET}"
echo "=========================="

# 1. Validar conectividad API
echo -e "${YELLOW}🌐 Testing CoinGecko API connectivity...${RESET}"
API_RESPONSE=$(curl -s -w "%{http_code}" "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd")
HTTP_CODE="${API_RESPONSE: -3}"

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✅ CoinGecko API is accessible${RESET}"
else
    echo -e "${RED}❌ CoinGecko API returned HTTP $HTTP_CODE${RESET}"
    exit 1
fi

# 2. Ejecutar setup básico
echo -e "${YELLOW}🔧 Running basic setup...${RESET}"
./dataops/automation/setup-pipeline.sh

# 3. Crear tópico adicional para alertas
echo -e "${YELLOW}📊 Creating additional topics...${RESET}"
confluent kafka topic create crypto-alerts \
  --partitions 1 \
  --config retention.ms=86400000 \
  --config cleanup.policy=delete || echo "Topic already exists"

# 4. Validar tópicos creados
echo -e "${YELLOW}✅ Validating created topics...${RESET}"
TOPICS=$(confluent kafka topic list | grep crypto | wc -l)
echo -e "${GREEN}📊 Created $TOPICS crypto-related topics${RESET}"

# 5. Test de conectividad end-to-end
echo -e "${YELLOW}🔍 Testing end-to-end connectivity...${RESET}"
sleep 10  # Esperar que el conector se inicialice

# Verificar que hay mensajes en el tópico
MESSAGE_COUNT=$(confluent kafka topic consume crypto-prices --from-beginning --max-messages 1 --timeout 30000 | wc -l)

if [ "$MESSAGE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ End-to-end test successful - messages flowing${RESET}"
else
    echo -e "${YELLOW}⚠️  No messages detected yet - may need more time${RESET}"
fi

echo -e "${GREEN}🎉 Enhanced setup completed!${RESET}"