#!/bin/bash

# 🔍 Validar Estado del Conector HTTP Source
# Este script verifica el estado y configuración del conector desplegado

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

CONNECTOR_NAME="coingecko-price-connector"

echo -e "🔍 ${BLUE}Validando Estado del Conector HTTP Source${RESET}"
echo "========================================="

# Primero, listar todos los conectores para ver qué está disponible
echo -e "📋 ${YELLOW}Listando todos los conectores...${RESET}"
confluent connect cluster list

echo ""
echo -e "📋 ${YELLOW}Verificando estado del conector...${RESET}"

# Extraer ID del conector de la salida de la lista
echo -e "📋 ${YELLOW}Obteniendo ID del conector...${RESET}"
CONNECTOR_ID=$(confluent connect cluster list 2>/dev/null | grep "$CONNECTOR_NAME" | awk '{print $1}')

if [ -z "$CONNECTOR_ID" ]; then
    echo -e "❌ ${RED}Conector '$CONNECTOR_NAME' no encontrado${RESET}"
    echo -e "💡 ${BLUE}Conectores disponibles listados arriba${RESET}"
    echo -e "💡 ${BLUE}Ejecuta 'deploy-connector.sh' para desplegar el conector primero${RESET}"
    exit 1
fi

echo -e "✅ ${GREEN}Conector '$CONNECTOR_NAME' encontrado con ID: $CONNECTOR_ID${RESET}"

# Intentar obtener información detallada del conector usando el ID
echo ""
echo -e "📊 ${YELLOW}Obteniendo detalles del conector...${RESET}"
confluent connect cluster describe "$CONNECTOR_ID" 2>/dev/null || {
    echo -e "⚠️  ${YELLOW}No se pudo obtener el estado detallado del conector${RESET}"
    echo -e "💡 ${BLUE}Esto puede ser normal - el conector puede estar aún inicializándose${RESET}"
}

echo ""
echo -e "🔄 ${YELLOW}Re-verificando estado del conector después de la inicialización...${RESET}"
confluent connect cluster list | grep "$CONNECTOR_NAME" || {
    echo -e "⚠️  ${YELLOW}Conector no visible en la lista${RESET}"
}

echo ""
echo -e "✅ ${GREEN}¡Validación del conector completa!${RESET}"
echo -e "💡 ${BLUE}Usa la Extensión de Confluent para VSCode para validar el flujo de datos${RESET}"
