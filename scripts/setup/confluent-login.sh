#!/bin/bash

# 🔐 Script de Ayuda para Autenticación en Confluent Cloud
# Este script ayuda con el login y configuración de contexto en Confluent Cloud

# Colores para la salida
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

echo -e "🔐 ${BLUE}Configuración de Autenticación en Confluent Cloud${RESET}"
echo "==============================================="

# Verificar si la CLI de Confluent está instalada
if ! command -v confluent &> /dev/null; then
    echo -e "❌ ${RED}La CLI de Confluent no está instalada${RESET}"
    echo "📥 Por favor instálala primero: curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest"
    exit 1
fi

echo -e "✅ ${GREEN}CLI de Confluent encontrada${RESET}"

# Iniciar sesión en Confluent Cloud
echo ""
echo "🔑 Iniciando sesión en Confluent Cloud..."
echo -e "${YELLOW}Esto proporcionará una URL para autenticación en el navegador${RESET}"
echo -e "${YELLOW}Copia la URL proporcionada y pégala en tu navegador${RESET}"
echo -e "${YELLOW}Luego copia el código de autorización y pégalo aquí${RESET}"
echo ""
echo -e "${BLUE}Presiona Enter para continuar...${RESET}"
read -r

confluent login --save --no-browser

if [ $? -eq 0 ]; then
    echo -e "✅ ${GREEN}Sesión iniciada exitosamente en Confluent Cloud${RESET}"
else
    echo -e "❌ ${RED}Falló el inicio de sesión. Por favor verifica tus credenciales.${RESET}"
    echo -e "${YELLOW}Consejo: Asegúrate de haber copiado el código de autorización correctamente${RESET}"
    exit 1
fi

# Listar organizaciones
echo ""
echo -e " Organizaciones Disponibles:"
confluent organization list

# Nota: El contexto se crea automáticamente durante el login
echo ""
echo -e "🔧 ${YELLOW}Verificando contexto actual...${RESET}"
CURRENT_CONTEXT=$(confluent context list | grep '\*' | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')
if [ -n "$CURRENT_CONTEXT" ]; then
    echo -e "✅ ${GREEN}Usando contexto: $CURRENT_CONTEXT${RESET}"
else
    echo -e "⚠️  ${YELLOW}No se encontró contexto activo${RESET}"
fi

# Listar contextos actuales
echo ""
echo -e " Contextos CLI actuales:"
confluent context list

echo ""
echo -e " ¡Configuración de autenticación completa!"
echo -e " Próximos pasos:"
echo "   1. Crear un entorno: confluent environment create 'cc-workshop-env'"
echo "   2. Crear un clúster de Kafka: confluent kafka cluster create workshop-cluster --cloud aws --region us-east-1 --type basic"
