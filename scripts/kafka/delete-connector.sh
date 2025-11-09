#!/bin/bash

# 🗑️ Eliminar Conector HTTP Source
# Este script elimina el Conector HTTP Source desplegado y limpia los recursos

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

CONNECTOR_NAME="coingecko-price-connector"

echo -e "🗑️ ${BLUE}Eliminando Conector HTTP Source${RESET}"
echo "================================"

# Primero, listar todos los conectores para ver qué está disponible
echo -e "📋 ${YELLOW}Listando todos los conectores...${RESET}"
confluent connect cluster list

echo ""
echo -e "🔍 ${YELLOW}Obteniendo ID del conector para '$CONNECTOR_NAME'...${RESET}"
CONNECTOR_ID=$(confluent connect cluster list 2>/dev/null | grep "$CONNECTOR_NAME" | awk '{print $1}')

if [ -z "$CONNECTOR_ID" ]; then
    echo -e "⚠️  ${YELLOW}Conector '$CONNECTOR_NAME' no encontrado${RESET}"
    echo -e "💡 ${BLUE}El conector puede ya haber sido eliminado o nunca existió${RESET}"
    exit 0
fi

echo -e "✅ ${GREEN}Conector encontrado con ID: $CONNECTOR_ID${RESET}"

# Confirmar eliminación
echo ""
echo -e "⚠️  ${YELLOW}Esto eliminará permanentemente el conector y detendrá la ingesta de datos${RESET}"
read -p "¿Estás seguro de que quieres eliminar el conector? (s/N): " confirm

if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
    echo -e "❌ ${BLUE}Eliminación cancelada${RESET}"
    exit 0
fi

# Eliminar el conector usando el ID
echo ""
echo -e "🗑️ ${YELLOW}Eliminando conector '$CONNECTOR_NAME' (ID: $CONNECTOR_ID)...${RESET}"
confluent connect cluster delete "$CONNECTOR_ID"

if [ $? -eq 0 ]; then
    echo -e "✅ ${GREEN}Conector eliminado exitosamente${RESET}"
else
    echo -e "❌ ${RED}Falló la eliminación del conector${RESET}"
    echo -e "🔍 Verifica tus permisos e intenta nuevamente${RESET}"
    exit 1
fi

# Verificar eliminación comprobando si el ID del conector aún existe en la lista
echo ""
echo -e "🔍 ${YELLOW}Verificando eliminación del conector...${RESET}"
sleep 5

REMAINING_CONNECTOR=$(confluent connect cluster list 2>/dev/null | grep "$CONNECTOR_ID")
if [ -z "$REMAINING_CONNECTOR" ]; then
    echo -e "✅ ${GREEN}Conector eliminado exitosamente${RESET}"
else
    echo -e "⚠️  ${YELLOW}El conector puede estar aún en proceso de eliminación${RESET}"
fi

# Listar conectores restantes
echo ""
echo -e "📋 ${BLUE}Conectores restantes:${RESET}"
confluent connect cluster list

echo ""
echo -e "🎉 ${GREEN}¡Eliminación del conector completa!${RESET}"
echo -e "💡 ${BLUE}Nota: El tema 'crypto-prices' permanecerá con los datos existentes${RESET}"
echo -e "💡 ${BLUE}Usa 'confluent kafka topic delete crypto-prices' para eliminar el tema si es necesario${RESET}"
