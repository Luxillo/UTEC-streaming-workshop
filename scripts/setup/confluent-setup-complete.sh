#!/bin/bash

# 🚀 Script de Automatización Completa de Confluent Cloud
# Este script automatiza todo el proceso de configuración de Confluent Cloud

set -euo pipefail

# Colores para la salida
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

# Variables de entorno
ENV_FILE="./scripts/kafka/.env"

echo -e "🚀 ${BLUE}Configuración Completa de Confluent Cloud${RESET}"
echo "============================================="

# Función para esperar entrada del usuario
wait_for_user() {
    echo -e "${YELLOW}Presiona Enter para continuar...${RESET}"
    read -r
}

# Función para obtener entrada del usuario
get_user_input() {
    local prompt="$1"
    local var_name="$2"
    echo -e "${YELLOW}$prompt${RESET}"
    read -r "$var_name"
}

# Paso 1: Validar prerrequisitos
echo -e "🔍 ${BLUE}Paso 1: Validando prerrequisitos${RESET}"
echo "================================="

if ! command -v confluent &> /dev/null; then
    echo -e "❌ ${RED}CLI de Confluent no encontrada${RESET}"
    exit 1
fi

if ! command -v duckdb &> /dev/null; then
    echo -e "❌ ${RED}DuckDB no encontrado${RESET}"
    exit 1
fi

echo -e "✅ ${GREEN}Prerrequisitos validados${RESET}"
echo ""

# Paso 2: Autenticación
echo -e "🔐 ${BLUE}Paso 2: Autenticación en Confluent Cloud${RESET}"
echo "========================================="

echo -e "${YELLOW}Iniciando login en Confluent Cloud...${RESET}"
echo -e "${YELLOW}Esto proporcionará una URL para autenticación en el navegador${RESET}"
echo -e "${YELLOW}Copia la URL proporcionada y pégala en tu navegador${RESET}"
echo -e "${YELLOW}Luego copia el código de autorización y pégalo aquí${RESET}"
wait_for_user

if confluent login --save --no-browser; then
    echo -e "✅ ${GREEN}Autenticación exitosa con Confluent Cloud${RESET}"
else
    echo -e "❌ ${RED}Falló la autenticación${RESET}"
    exit 1
fi

echo ""

# Paso 3: Configuración del entorno
echo -e "🌍 ${BLUE}Paso 3: Configuración del Entorno${RESET}"
echo "=================================="

echo -e "${YELLOW}Organizaciones disponibles:${RESET}"
confluent organization list

echo ""
echo -e "${YELLOW}Verificando si el entorno del taller ya existe...${RESET}"

# Buscar entorno existente
EXISTING_ENV=$(confluent environment list --output json | jq -r '.[] | select(.name=="cc-workshop-env") | .id')

if [ -n "$EXISTING_ENV" ] && [ "$EXISTING_ENV" != "null" ]; then
    echo -e "✅ ${GREEN}Entorno existente encontrado: $EXISTING_ENV${RESET}"
    CC_ENV_ID="$EXISTING_ENV"
    confluent environment use "$CC_ENV_ID"
else
    echo -e "${YELLOW}Creando nuevo entorno del taller...${RESET}"
    ENV_OUTPUT=$(confluent environment create "cc-workshop-env" --output json)
    CC_ENV_ID=$(echo "$ENV_OUTPUT" | jq -r '.id')
    
    if [ "$CC_ENV_ID" != "null" ] && [ -n "$CC_ENV_ID" ]; then
        echo -e "✅ ${GREEN}Entorno creado: $CC_ENV_ID${RESET}"
        confluent environment use "$CC_ENV_ID"
    else
        echo -e "❌ ${RED}Falló la creación del entorno${RESET}"
        exit 1
    fi
fi

echo ""

# Paso 4: Creación del clúster de Kafka
echo -e "☁️ ${BLUE}Paso 4: Creación del Clúster de Kafka${RESET}"
echo "====================================="

echo -e "${YELLOW}Creando clúster básico de Kafka (esto puede tomar unos minutos)...${RESET}"
CLUSTER_OUTPUT=$(confluent kafka cluster create workshop-cluster \
    --cloud aws \
    --region us-east-1 \
    --type basic \
    --output json)

CC_KAFKA_CLUSTER=$(echo "$CLUSTER_OUTPUT" | jq -r '.id')

if [ "$CC_KAFKA_CLUSTER" != "null" ] && [ -n "$CC_KAFKA_CLUSTER" ]; then
    echo -e "✅ ${GREEN}Clúster de Kafka creado: $CC_KAFKA_CLUSTER${RESET}"
    confluent kafka cluster use "$CC_KAFKA_CLUSTER"
else
    echo -e "❌ ${RED}Falló la creación del clúster de Kafka${RESET}"
    exit 1
fi

# Esperar a que el clúster esté listo
echo -e "${YELLOW}Esperando a que el clúster esté listo...${RESET}"
while true; do
    STATUS=$(confluent kafka cluster describe "$CC_KAFKA_CLUSTER" --output json | jq -r '.status')
    if [ "$STATUS" = "UP" ]; then
        echo -e "✅ ${GREEN}El clúster está listo${RESET}"
        break
    fi
    echo -e "${YELLOW}Estado del clúster: $STATUS. Esperando...${RESET}"
    sleep 10
done

# Obtener servidores bootstrap
BOOTSTRAP_SERVERS=$(confluent kafka cluster describe "$CC_KAFKA_CLUSTER" --output json | jq -r '.endpoint')
echo -e "📡 ${GREEN}Servidores bootstrap: $BOOTSTRAP_SERVERS${RESET}"

echo ""

# Paso 5: Generación de claves API
echo -e "🔑 ${BLUE}Paso 5: Generación de Claves API${RESET}"
echo "================================"

# Clave API de Kafka
echo -e "${YELLOW}Creando clave API de Kafka...${RESET}"
KAFKA_API_OUTPUT=$(confluent api-key create --resource "$CC_KAFKA_CLUSTER" --description "Clave API Kafka del Taller" --output json)
KAFKA_API_KEY=$(echo "$KAFKA_API_OUTPUT" | jq -r '.key')
KAFKA_API_SECRET=$(echo "$KAFKA_API_OUTPUT" | jq -r '.secret')

if [ "$KAFKA_API_KEY" != "null" ] && [ -n "$KAFKA_API_KEY" ]; then
    echo -e "✅ ${GREEN}Clave API de Kafka creada: $KAFKA_API_KEY${RESET}"
    confluent api-key use "$KAFKA_API_KEY" --resource "$CC_KAFKA_CLUSTER"
else
    echo -e "❌ ${RED}Falló la creación de la clave API de Kafka${RESET}"
    exit 1
fi

# Clave API del Registro de Esquemas
echo -e "${YELLOW}Obteniendo información del clúster del Registro de Esquemas...${RESET}"
SR_CLUSTER_OUTPUT=$(confluent schema-registry cluster describe --output json)
SCHEMA_REGISTRY_CLUSTER_ID=$(echo "$SR_CLUSTER_OUTPUT" | jq -r '.cluster_id')
SCHEMA_REGISTRY_URL=$(echo "$SR_CLUSTER_OUTPUT" | jq -r '.endpoint_url')

echo -e "${YELLOW}Creando clave API del Registro de Esquemas...${RESET}"
SR_API_OUTPUT=$(confluent api-key create --resource "$SCHEMA_REGISTRY_CLUSTER_ID" --description "Clave API Registro de Esquemas del Taller" --output json)
SCHEMA_REGISTRY_API_KEY=$(echo "$SR_API_OUTPUT" | jq -r '.key')
SCHEMA_REGISTRY_API_SECRET=$(echo "$SR_API_OUTPUT" | jq -r '.secret')

if [ "$SCHEMA_REGISTRY_API_KEY" != "null" ] && [ -n "$SCHEMA_REGISTRY_API_KEY" ]; then
    echo -e "✅ ${GREEN}Clave API del Registro de Esquemas creada: $SCHEMA_REGISTRY_API_KEY${RESET}"
else
    echo -e "❌ ${RED}Falló la creación de la clave API del Registro de Esquemas${RESET}"
    exit 1
fi

# Clave API de Tableflow
echo -e "${YELLOW}Creando clave API de Tableflow...${RESET}"
TABLEFLOW_API_OUTPUT=$(confluent api-key create --resource tableflow --description "Clave API Tableflow del Taller" --output json)
TABLEFLOW_API_KEY=$(echo "$TABLEFLOW_API_OUTPUT" | jq -r '.key')
TABLEFLOW_API_SECRET=$(echo "$TABLEFLOW_API_OUTPUT" | jq -r '.secret')

if [ "$TABLEFLOW_API_KEY" != "null" ] && [ -n "$TABLEFLOW_API_KEY" ]; then
    echo -e "✅ ${GREEN}Clave API de Tableflow creada: $TABLEFLOW_API_KEY${RESET}"
else
    echo -e "❌ ${RED}Falló la creación de la clave API de Tableflow${RESET}"
    exit 1
fi

echo ""

# Paso 6: Actualización del archivo de entorno
echo -e "📝 ${BLUE}Paso 6: Actualización del Archivo de Entorno${RESET}"
echo "========================================="

# Crear directorio scripts/kafka si no existe
mkdir -p "$(dirname "$ENV_FILE")"

# Obtener Organization ID
CC_ORG_ID=$(confluent organization list --output json | jq -r '.[0].id')

# Función para actualizar variables en el archivo .env
update_env_var() {
    local var_name="$1"
    local var_value="$2"
    local file="$3"
    
    if grep -q "^export ${var_name}=" "$file" 2>/dev/null; then
        # Actualizar variable existente
        sed -i "s|^export ${var_name}=.*|export ${var_name}=\"${var_value}\"|" "$file"
    else
        # Agregar nueva variable
        echo "export ${var_name}=\"${var_value}\"" >> "$file"
    fi
}

# Si el archivo no existe, crear uno básico
if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" << 'EOF'
# Confluent Cloud API Keys
# Generado/actualizado automáticamente por confluent-setup-complete.sh
# Source this file before running scripts: source .env
# Confluent Cloud Organization ID
export CC_ORG_ID=""

# Confluent Cloud Environment ID
export CC_ENV_ID=""

# Confluent Cloud Kafka Cluster ID
export CC_KAFKA_CLUSTER=""

# Kafka Bootstrap Servers
export BOOTSTRAP_SERVERS=""
export KAFKA_BOOTSTRAP_SERVERS=""

# Kafka Cluster API Keys
export KAFKA_API_KEY=""
export KAFKA_API_SECRET=""

# Schema Registry API Keys
export SCHEMA_REGISTRY_CLUSTER_ID=""
export SCHEMA_REGISTRY_API_KEY=""
export SCHEMA_REGISTRY_API_SECRET=""
export SCHEMA_REGISTRY_URL=""

# Tableflow API Keys
export TABLEFLOW_API_KEY=""
export TABLEFLOW_API_SECRET=""

EOF
fi

# Actualizar variables específicas
update_env_var "KAFKA_API_KEY" "$KAFKA_API_KEY" "$ENV_FILE"
update_env_var "KAFKA_API_SECRET" "$KAFKA_API_SECRET" "$ENV_FILE"
update_env_var "SCHEMA_REGISTRY_CLUSTER_ID" "$SCHEMA_REGISTRY_CLUSTER_ID" "$ENV_FILE"
update_env_var "SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_KEY" "$ENV_FILE"
update_env_var "SCHEMA_REGISTRY_API_SECRET" "$SCHEMA_REGISTRY_API_SECRET" "$ENV_FILE"
update_env_var "SCHEMA_REGISTRY_URL" "$SCHEMA_REGISTRY_URL" "$ENV_FILE"
update_env_var "TABLEFLOW_API_KEY" "$TABLEFLOW_API_KEY" "$ENV_FILE"
update_env_var "TABLEFLOW_API_SECRET" "$TABLEFLOW_API_SECRET" "$ENV_FILE"
update_env_var "CC_ORG_ID" "$CC_ORG_ID" "$ENV_FILE"
update_env_var "CC_ENV_ID" "$CC_ENV_ID" "$ENV_FILE"
update_env_var "CC_KAFKA_CLUSTER" "$CC_KAFKA_CLUSTER" "$ENV_FILE"
update_env_var "BOOTSTRAP_SERVERS" "$BOOTSTRAP_SERVERS" "$ENV_FILE"
update_env_var "KAFKA_BOOTSTRAP_SERVERS" "$BOOTSTRAP_SERVERS" "$ENV_FILE"

echo -e "✅ ${GREEN}Archivo de entorno actualizado: $ENV_FILE${RESET}"

# Paso 7: Validación
echo ""
echo -e "🧪 ${BLUE}Paso 7: Validación${RESET}"
echo "=================="

echo -e "${YELLOW}Cargando variables de entorno...${RESET}"
source "$ENV_FILE"

echo -e "${YELLOW}Probando conectividad con Kafka...${RESET}"
if confluent kafka topic list > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}Conectividad con Kafka validada${RESET}"
else
    echo -e "❌ ${RED}Falló la conectividad con Kafka${RESET}"
fi

echo -e "${YELLOW}Probando conectividad con Tableflow...${RESET}"
if confluent tableflow topic list > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}Conectividad con Tableflow validada${RESET}"
else
    echo -e "❌ ${RED}Falló la conectividad con Tableflow${RESET}"
fi

# Resumen final
echo ""
echo -e "🎉 ${GREEN}¡Configuración Completa!${RESET}"
echo "========================"
echo ""
echo -e "${BLUE}Resumen de recursos creados:${RESET}"
echo "• ID del Entorno: $CC_ENV_ID"
echo "• ID del Clúster de Kafka: $CC_KAFKA_CLUSTER"
echo "• Servidores Bootstrap: $BOOTSTRAP_SERVERS"
echo "• URL del Registro de Esquemas: $SCHEMA_REGISTRY_URL"
echo ""
echo -e "${BLUE}Claves API creadas:${RESET}"
echo "• Clave API de Kafka: $KAFKA_API_KEY"
echo "• Clave API del Registro de Esquemas: $SCHEMA_REGISTRY_API_KEY"
echo "• Clave API de Tableflow: $TABLEFLOW_API_KEY"
echo ""
echo -e "${YELLOW}⚠️  Importante: Los secretos de las API están almacenados en $ENV_FILE${RESET}"
echo -e "${YELLOW}   Mantén este archivo seguro y no lo subas al control de versiones${RESET}"
echo ""
echo -e "${GREEN}Próximos pasos:${RESET}"
echo "1. Cargar el archivo de entorno: source $ENV_FILE"
echo "2. Continuar con las guías del taller"
echo "3. ¡Comenzar a crear temas y transmitir datos!" archivo de entorno: source $ENV_FILE"