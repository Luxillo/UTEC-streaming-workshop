#!/bin/bash

# 🚀 Desplegar Conector HTTP Source para la API de CoinGecko
# Este script despliega el Conector HTTP Source para transmitir datos de precios de criptomonedas

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

CONNECTOR_NAME="coingecko-price-connector"

# Cargar variables de entorno desde el archivo .env si existe
if [ -f ".env" ]; then
    echo -e " ${BLUE}Cargando variables de entorno desde el archivo .env...${RESET}"
    source .env
fi

echo -e " ${BLUE}Desplegando Conector HTTP Source${RESET}"
echo "================================"

# Verificar variables de entorno requeridas
echo -e " ${YELLOW}Verificando variables de entorno...${RESET}"
if [ -z "$KAFKA_API_KEY" ] || [ -z "$KAFKA_API_SECRET" ]; then
    echo -e " ${RED}Faltan variables de entorno requeridas${RESET}"
    echo -e " ${BLUE}Por favor configura las siguientes variables de entorno o crea el archivo .env:${RESET}"
    echo -e "   export KAFKA_API_KEY=\"tu-clave-api\""
    echo -e "   export KAFKA_API_SECRET=\"tu-secreto-api\""
    echo -e " ${BLUE}O ejecuta: source .env${RESET}"
    exit 1
fi

# Usar archivo de configuración existente o crear desde plantilla
CONFIG_FILE="../configs/connector-configs/http-source-coingecko.json"
TEMP_CONFIG="/tmp/coingecko-connector.json"

if [ -f "$CONFIG_FILE" ]; then
    echo -e "📝 ${YELLOW}Usando configuración de conector existente...${RESET}"
    # Sustituir variables de entorno en la configuración
    envsubst < "$CONFIG_FILE" > "$TEMP_CONFIG"
else
    echo -e "📝 ${YELLOW}Creando configuración del conector...${RESET}"
    
    cat > "$TEMP_CONFIG" << EOF
{
  "name": "coingecko-price-connector",
  "config": {
    "connector.class": "HttpSource",
    "kafka.auth.mode": "KAFKA_API_KEY",
    "kafka.api.key": "${KAFKA_API_KEY}",
    "kafka.api.secret": "${KAFKA_API_SECRET}",
    "topic.name.pattern": "crypto-prices",
    "url": "https://api.coingecko.com/api/v3/simple/price",
    "http.request.parameters": "ids=bitcoin,ethereum,binancecoin,cardano,solana&vs_currencies=usd&include_market_cap=true&include_24hr_vol=true&include_24hr_change=true&include_last_updated_at=true",
    "request.interval.ms": "60000",
    "output.data.format": "AVRO",
    "tasks.max": "1",
    "http.initial.offset": "0"
  }
}
EOF
fi

echo -e "✅ ${GREEN}Configuración del conector lista${RESET}"

# Desplegar el conector
echo ""
echo -e "🚀 ${YELLOW}Desplegando Conector HTTP Source...${RESET}"

confluent connect cluster create --config-file "$TEMP_CONFIG"

if [ $? -eq 0 ]; then
    echo -e "✅ ${GREEN}Conector desplegado exitosamente${RESET}"
    echo -e "💡 ${BLUE}Usa 'validate-connector.sh' para verificar el estado del conector${RESET}"
    echo -e "📊 ${BLUE}Usa la Extensión de Confluent para VSCode para validar el flujo de datos${RESET}"
else
    echo -e "❌ ${RED}Falló el despliegue del conector${RESET}"
    echo -e "🔍 Verifica tus credenciales de API y la configuración del clúster"
    exit 1
fi

# Limpiar archivos temporales
rm -f "$TEMP_CONFIG"

echo ""
echo -e "🎉 ${GREEN}¡Despliegue del conector completo!${RESET}"
