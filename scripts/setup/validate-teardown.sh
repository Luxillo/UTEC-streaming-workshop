#!/bin/bash

# Taller de Confluent Cloud - Script de Validación de Recursos
# Este script valida que todos los recursos del taller hayan sido eliminados correctamente
# Basado en los pasos de verificación de guides/05-teardown-resources.adoc

# Definiciones de colores para la salida
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
RESET='\033[0m'

# Códigos de salida
SUCCESS=0
WARNING=1
ERROR=2

# Variables globales
ISSUES_FOUND=0
WARNINGS_FOUND=0

# Función para imprimir salida con colores
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS")
            echo -e "${GREEN}✅ $message${RESET}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${RESET}"
            WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${RESET}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${RESET}"
            ;;
        "HEADER")
            echo -e "${CYAN}🔍 $message${RESET}"
            ;;
    esac
}

# Función para verificar si la CLI de confluent está disponible
check_cli() {
    if ! command -v confluent &> /dev/null; then
        print_status "ERROR" "CLI de Confluent no encontrada. Por favor instálala primero."
        exit $ERROR
    fi
    
    # Verificar si el usuario ha iniciado sesión
    if ! confluent context list &> /dev/null; then
        print_status "ERROR" "No has iniciado sesión en Confluent Cloud. Ejecuta 'confluent login' primero."
        exit $ERROR
    fi
}

# Función para verificar recursos de Flink (COSTO ALTO)
check_flink_resources() {
    print_status "HEADER" "Verificando Recursos de Flink (Prioridad de Costo Alto)"
    
    # Verificar pools de cómputo de Flink
    local pools_output
    pools_output=$(confluent flink compute-pool list --output json 2>/dev/null)
    local pools_count
    pools_count=$(echo "$pools_output" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ "$pools_count" -gt 0 ]]; then
        print_status "ERROR" "Se encontraron $pools_count pool(s) de cómputo de Flink - ¡estos generan cargos continuos!"
        echo "$pools_output" | jq -r '.[] | "  - ID del Pool: \(.id), Nombre: \(.name), Estado: \(.status)"' 2>/dev/null
    else
        print_status "SUCCESS" "No se encontraron pools de cómputo de Flink"
    fi
    
    # Verificar declaraciones/aplicaciones de Flink
    local statements_output
    statements_output=$(confluent flink statement list --output json 2>/dev/null)
    local statements_count
    statements_count=$(echo "$statements_output" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ "$statements_count" -gt 0 ]]; then
        print_status "ERROR" "¡Se encontraron $statements_count declaración(es) de Flink aún ejecutándose!"
        echo "$statements_output" | jq -r '.[] | "  - Declaración: \(.name // "sin nombre"), Estado: \(.status // "desconocido")"' 2>/dev/null
    else
        print_status "SUCCESS" "No se encontraron declaraciones de Flink"
    fi
}

# Función para verificar recursos de Tableflow (COSTO MEDIO)
check_tableflow_resources() {
    print_status "HEADER" "Verificando Recursos de Tableflow (Prioridad de Costo Medio)"
    
    # Verificar integraciones de catálogo de Tableflow
    local catalogs_output
    catalogs_output=$(confluent tableflow catalog-integration list --output json 2>/dev/null)
    local catalogs_count
    catalogs_count=$(echo "$catalogs_output" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ "$catalogs_count" -gt 0 ]]; then
        print_status "ERROR" "Se encontraron $catalogs_count integración(es) de catálogo de Tableflow - ¡estas incurren en costos de almacenamiento!"
        echo "$catalogs_output" | jq -r '.[] | "  - ID del Catálogo: \(.id // "desconocido"), Nombre: \(.display_name // "desconocido"), Estado: \(.status // "desconocido")"' 2>/dev/null
    else
        print_status "SUCCESS" "No se encontraron integraciones de catálogo de Tableflow"
    fi
    
    # Verificar habilitación de temas de Tableflow
    if [ -n "$CC_KAFKA_CLUSTER" ]; then
        local tableflow_topics_output
        tableflow_topics_output=$(confluent tableflow topic list --cluster "$CC_KAFKA_CLUSTER" --output json 2>/dev/null)
        local tableflow_topics_count
        tableflow_topics_count=$(echo "$tableflow_topics_output" | jq '. | length' 2>/dev/null || echo "0")
        
        if [[ "$tableflow_topics_count" -gt 0 ]]; then
            print_status "ERROR" "¡Se encontraron $tableflow_topics_count tema(s) habilitado(s) para Tableflow!"
            echo "$tableflow_topics_output" | jq -r '.[] | "  - Tema: \(.topic_name), Fase: \(.phase), Suspendido: \(.suspended)"' 2>/dev/null
        else
            print_status "SUCCESS" "No se encontraron temas habilitados para Tableflow"
        fi
    else
        print_status "WARNING" "CC_KAFKA_CLUSTER no configurado, omitiendo verificación de temas de Tableflow"
    fi
}

# Función para verificar conectores
check_connectors() {
    print_status "HEADER" "Verificando Conectores"
    
    local connectors_output
    connectors_output=$(confluent connect connector list --output json 2>/dev/null)
    local connectors_count
    connectors_count=$(echo "$connectors_output" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ "$connectors_count" -gt 0 ]]; then
        # Verificar temas específicos del taller
        local expected_topics=("crypto-prices" "price-alerts" "crypto-prices-exploded" "crypto-trends")
        local found_topics=()
        
        for topic in "${expected_topics[@]}"; do
            if echo "$topics_output" | jq -e --arg topic "$topic" '.[] | select(.name == $topic)' >/dev/null 2>&1; then
                found_topics+=("$topic")
            fi
        done
        
        if [[ ${#found_topics[@]} -gt 0 ]]; then
            print_status "WARNING" "Se encontraron tema(s) relacionado(s) con el taller:"
            for topic in "${found_topics[@]}"; do
                echo "  - $topic"
            done
        fi
        
        # Verificar conectores específicos del taller
        local workshop_connectors
        workshop_connectors=$(echo "$connectors_output" | jq -r '.[] | select(.name | contains("coingecko") or contains("workshop")) | .name' 2>/dev/null)
        
        if [[ -n "$workshop_connectors" ]]; then
            print_status "ERROR" "Se encontraron conector(es) relacionado(s) con el taller:"
            echo "$workshop_connectors" | while read -r connector; do
                echo "  - $connector"
            done
        else
            print_status "INFO" "Se encontraron $connectors_count conector(es), pero ninguno parece relacionado con el taller"
        fi
    else
        print_status "SUCCESS" "No se encontraron conectores"
    fi
}

# Función para verificar clústeres de Kafka
check_kafka_clusters() {
    print_status "HEADER" "Verificando Clústeres de Kafka"
    
    local clusters_output
    clusters_output=$(confluent kafka cluster list --output json 2>/dev/null)
    local clusters_count
    clusters_count=$(echo "$clusters_output" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ "$clusters_count" -gt 0 ]]; then
        # Verificar clústeres no-Básicos (que incurren en cargos)
        local paid_clusters
        paid_clusters=$(echo "$clusters_output" | jq -r '.[] | select(.type != "BASIC") | "\(.id) (\(.type))"' 2>/dev/null)
        
        if [[ -n "$paid_clusters" ]]; then
            print_status "ERROR" "Se encontraron clúster(es) de pago - estos generan cargos:"
            echo "$paid_clusters" | while read -r cluster; do
                echo "  - Clúster: $cluster"
            done
        fi
        
        # Verificar clústeres con nombre de taller
        local workshop_clusters
        workshop_clusters=$(echo "$clusters_output" | jq -r '.[] | select(.name | contains("workshop")) | "\(.name) (\(.type))"' 2>/dev/null)
        
        if [[ -n "$workshop_clusters" ]]; then
            print_status "WARNING" "Se encontraron clúster(es) con nombre de taller:"
            echo "$workshop_clusters" | while read -r cluster; do
                echo "  - $cluster"
            done
        fi
        
        if [[ -z "$paid_clusters" && -z "$workshop_clusters" ]]; then
            print_status "SUCCESS" "Se encontraron $clusters_count clúster(es), todos parecen ser de nivel Básico (gratuito)"
        fi
    else
        print_status "SUCCESS" "No se encontraron clústeres de Kafka"
    fi
}

# Función para verificar claves API
check_api_keys() {
    print_status "HEADER" "Verificando Claves API"
    
    local keys_output
    keys_output=$(confluent api-key list --output json 2>/dev/null)
    local keys_count
    keys_count=$(echo "$keys_output" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ "$keys_count" -gt 0 ]]; then
        # Verificar claves API relacionadas con el taller
        local workshop_keys
        workshop_keys=$(echo "$keys_output" | jq -r '.[] | select(.description | contains("workshop") or contains("Workshop") or contains("Taller")) | "\(.key) - \(.description)"' 2>/dev/null)
        
        if [[ -n "$workshop_keys" ]]; then
            print_status "WARNING" "Se encontraron clave(s) API relacionada(s) con el taller:"
            echo "$workshop_keys" | while read -r key; do
                echo "  - $key"
            done
        else
            print_status "INFO" "Se encontraron $keys_count clave(s) API, ninguna parece relacionada con el taller"
        fi
    else
        print_status "SUCCESS" "No se encontraron claves API"
    fi
}

# Función para verificar entornos
check_environments() {
    print_status "HEADER" "Verificando Entornos"
    
    local envs_output
    envs_output=$(confluent environment list --output json 2>/dev/null)
    local workshop_envs
    workshop_envs=$(echo "$envs_output" | jq -r '.[] | select(.name | contains("workshop") or contains("cc-workshop") or contains("taller")) | "\(.id) - \(.name)"' 2>/dev/null)
    
    if [[ -n "$workshop_envs" ]]; then
        print_status "WARNING" "Se encontraron entorno(s) relacionado(s) con el taller:"
        echo "$workshop_envs" | while read -r env; do
            echo "  - $env"
        done
    else
        print_status "SUCCESS" "No se encontraron entornos relacionados con el taller"
    fi
}

# Función para proporcionar guía de monitoreo de costos
provide_cost_guidance() {
    print_status "HEADER" "Guía de Monitoreo de Costos"
    
    echo -e "${BLUE}🌐 Por favor verifica en la Consola de Confluent Cloud:${RESET}"
    echo "1. Ve a: https://confluent.cloud"
    echo "2. Navega a: Facturación y Pago → Uso"
    echo "3. Verifica: No hay cargos activos de Flink o Tableflow"
    echo "4. Comprueba: Solo permanecen clúster Básico (gratuito) o recursos esperados"
    echo ""
    
    if [[ $ISSUES_FOUND -gt 0 ]]; then
        echo -e "${RED}💰 URGENTE: ¡Tienes $ISSUES_FOUND problema(s) crítico(s) que pueden generar cargos!${RESET}"
        echo "Ejecuta el script de limpieza de emergencia de la guía de desmontaje inmediatamente."
    elif [[ $WARNINGS_FOUND -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Tienes $WARNINGS_FOUND advertencia(s) para revisar.${RESET}"
        echo "Considera limpiar estos recursos si ya no los necesitas."
    else
        echo -e "${GREEN}🎉 ¡Excelente! No se encontraron recursos que generen costos.${RESET}"
    fi
}

# Ejecución principal
main() {
    echo -e "${CYAN}🧹 Taller de Confluent Cloud - Validación de Recursos${RESET}"
    echo -e "${CYAN}===================================================${RESET}"
    echo "Verificando recursos facturables restantes..."
    echo ""
    
    # Verificar disponibilidad de CLI
    check_cli
    
    # Verificar recursos en orden de prioridad de costo
    check_flink_resources
    echo ""
    
    check_tableflow_resources
    echo ""
    
    check_connectors
    echo ""
    
    check_kafka_clusters
    echo ""
    
    check_api_keys
    echo ""
    
    check_environments
    echo ""
    
    # Proporcionar guía
    provide_cost_guidance
    
    # Salir con código apropiado
    if [[ $ISSUES_FOUND -gt 0 ]]; then
        exit $ERROR
    elif [[ $WARNINGS_FOUND -gt 0 ]]; then
        exit $WARNING
    else
        exit $SUCCESS
    fi
}

# Ejecutar función principal
main "$@"
