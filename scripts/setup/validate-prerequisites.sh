#!/bin/bash

# Script de Validación de Prerrequisitos para el Taller de Confluent Cloud
# Este script valida que todas las herramientas requeridas estén instaladas y accesibles

set -euo pipefail

# Colores para la salida
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

# Script de Validación de Prerrequisitos para el Taller de Confluent Cloud
# Este script valida que todas las herramientas requeridas estén instaladas y accesibles

echo -e "🔍 ${BLUE}Validando Prerrequisitos del Taller${RESET}"
echo "=================================="

# Rastrear el estado de la validación
VALIDATION_PASSED=true

# Función para verificar la disponibilidad de un comando
check_command() {
    local cmd=$1
    local name=$2
    local install_url=$3
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "✅ ${GREEN}$name está instalado${RESET}"
        return 0
    else
        echo -e "❌ ${RED}$name NO está instalado${RESET}"
        echo "   📥 Instalar desde: $install_url"
        VALIDATION_PASSED=false
        return 1
    fi
}

# Función para verificar los requisitos de versión
check_version() {
    local cmd=$1
    local name=$2
    local min_version=$3
    
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>&1 | head -1)
        echo -e "ℹ️  ${BLUE}$name versión: $version${RESET}"
        return 0
    else
        return 1
    fi
}

echo ""
echo -e "🔧 ${YELLOW}Checking Core Tools${RESET}"
echo "----------------------"

# Check VSCode
if command -v code &> /dev/null; then
    echo -e "✅ ${GREEN}VSCode está instalado${RESET}"
    
    # Comprobar la extensión Confluent (gestiona entornos locales y devcontainer)
    if code --list-extensions 2>/dev/null | grep -q "confluent" || \
       ls ~/.vscode-server/extensions/confluent.* 2>/dev/null | grep -q "confluent" || \
       ls /home/vscode/.vscode-server/extensions/confluent.* 2>/dev/null | grep -q "confluent"; then
        echo -e "✅ ${GREEN}La extensión de Confluent VSCode está instalada${RESET}"
    else
        echo -e "❌ ${RED}La extensión de Confluent VSCode NO está instalada${RESET}"
        echo "   📥 Instalar desde la tienda de extensiones de VSCode"
        # En devcontainer, intentar instalarlo automáticamente
        if [ "$WORKSHOP_ENV" = "codespaces" ] || [ -n "$REMOTE_CONTAINERS" ]; then
            echo "   🔄 Intentando instalación automática en devcontainer..."
            code --install-extension confluent.confluent-cloud --force 2>/dev/null || true
        fi
        VALIDATION_PASSED=false
    fi
else
    echo -e "❌ ${RED}VSCode is NOT installed${RESET}"
    echo "   📥 Instalar desde : https://code.visualstudio.com/"
    VALIDATION_PASSED=false
fi

# Verificar la CLI de Confluent
check_command "confluent" "Confluent CLI" "https://docs.confluent.io/confluent-cli/current/install.html"
if command -v confluent &> /dev/null; then
    check_version "confluent" "Confluent CLI" "3.0.0"
fi

# Verificar DuckDB
check_command "duckdb" "DuckDB" "https://duckdb.org/docs/installation/"
if command -v duckdb &> /dev/null; then
    check_version "duckdb" "DuckDB" "0.8.0"
fi

echo ""
echo -e "🌐 ${YELLOW}Comprobando conectividad de red${RESET}"
echo "--------------------------------"

# Check internet connectivity
if curl -s --connect-timeout 5 https://api.coingecko.com/api/v3/ping > /dev/null; then
    echo -e "✅ ${GREEN}La API de CoinGecko es accesible${RESET}"
else
    echo -e "⚠️  ${YELLOW}Problema de conectividad de la API de CoinGecko${RESET}"
    echo "   🔍 CComprobar la conexión a internet y la configuración del firewall"
fi

# Comprobar la conectividad de Confluent Cloud 
if curl -s --connect-timeout 5 https://confluent.cloud > /dev/null; then
    echo -e "✅ ${GREEN}Confluent Cloud es accesible${RESET}"
else
    echo -e "⚠️  ${YELLOW}Problema de conectividad con Confluent Cloud${RESET}"
    echo "   🔍 Comprobar la conexión a internet y la configuración del firewall"
fi

echo ""
echo -e "📊 ${YELLOW}Información del sistema${RESET}"
echo "------------------------"

# Mostrar información del sistema
echo "🖥️  OS: $(uname -s) $(uname -r)"
echo "💾 Memoria: $(free -h 2>/dev/null | grep '^Mem:' | awk '{print $2}' || echo 'N/A')"
echo "💽 Espacio en disco: $(df -h . | tail -1 | awk '{print $4}' 2>/dev/null || echo 'N/A') available"

echo ""
echo -e "📋 ${YELLOW}Resumen de validaciones completada${RESET}"
echo "========================"

if [ "$VALIDATION_PASSED" = true ]; then
    echo -e "🎉 ${GREEN}Todos los prerrequisitos validados correctamente!${RESET}"
    echo "✨ Estás listo para comenzar el taller"
    exit 0
else
    echo -e "⚠️  ${RED}Faltan algunos prerrequisitos${RESET}"
    echo "🔧 Instala las herramientas que faltan antes de continuar"
    echo ""
    echo -e "📚 ${BLUE}Comandos de instalación rápida:${RESET}"
    echo "   Confluent CLI: curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest"
    echo "   DuckDB: Visit https://duckdb.org/docs/installation/"
    echo "   VSCode: Visit https://code.visualstudio.com/"
    exit 1
fi
