#!/bin/bash

# 🔍 Script de Validación de Prerrequisitos
# Este script valida todas las herramientas requeridas para el taller

# Colores para la salida
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

echo -e "🔍 ${BLUE}Validación de Prerrequisitos del Taller${RESET}"
echo "======================================="

VALIDATION_PASSED=true

# Función para verificar disponibilidad de comandos
check_command() {
    local cmd="$1"
    local name="$2"
    local install_hint="$3"
    
    if command -v "$cmd" &> /dev/null; then
        local version
        case "$cmd" in
            "confluent")
                version=$(confluent version 2>/dev/null | head -1 | cut -d' ' -f3 || echo "desconocida")
                ;;
            "duckdb")
                version=$(duckdb --version 2>/dev/null || echo "desconocida")
                ;;
            "java")
                version=$(java -version 2>&1 | head -1 | cut -d'"' -f2 || echo "desconocida")
                ;;
            "python3")
                version=$(python3 --version 2>/dev/null | cut -d' ' -f2 || echo "desconocida")
                ;;
            *)
                version="instalado"
                ;;
        esac
        echo -e "✅ ${GREEN}$name: $version${RESET}"
    else
        echo -e "❌ ${RED}$name: No encontrado${RESET}"
        if [ -n "$install_hint" ]; then
            echo -e "   ${YELLOW}Instalar: $install_hint${RESET}"
        fi
        VALIDATION_PASSED=false
    fi
}

# Verificar VSCode (opcional pero recomendado)
if command -v code &> /dev/null; then
    echo -e "✅ ${GREEN}VSCode: Disponible${RESET}"
    
    # Verificar extensión de Confluent
    if code --list-extensions 2>/dev/null | grep -q "confluent"; then
        echo -e "✅ ${GREEN}Extensión VSCode de Confluent: Instalada${RESET}"
    else
        echo -e "⚠️  ${YELLOW}Extensión VSCode de Confluent: No instalada${RESET}"
        echo -e "   ${YELLOW}Instalar desde el marketplace de extensiones de VSCode${RESET}"
    fi
else
    echo -e "⚠️  ${YELLOW}VSCode: No encontrado (opcional)${RESET}"
fi

# Verificar herramientas requeridas
check_command "confluent" "CLI de Confluent" "curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest"
check_command "duckdb" "DuckDB" "Visitar https://duckdb.org/docs/installation/"
check_command "java" "Java" "Instalar OpenJDK 11 o superior"
check_command "python3" "Python 3" "Instalar Python 3.8 o superior"

# Verificar paquetes de Python
echo ""
echo -e "${BLUE}Verificando paquetes de Python:${RESET}"

check_python_package() {
    local package="$1"
    if python3 -c "import $package" 2>/dev/null; then
        local version=$(python3 -c "import $package; print(getattr($package, '__version__', 'desconocida'))" 2>/dev/null)
        echo -e "✅ ${GREEN}$package: $version${RESET}"
    else
        echo -e "❌ ${RED}$package: No encontrado${RESET}"
        VALIDATION_PASSED=false
    fi
}

check_python_package "confluent_kafka"
check_python_package "requests"
check_python_package "pandas"
check_python_package "duckdb"

# Verificar conectividad de red
echo ""
echo -e "${BLUE}Verificando conectividad de red:${RESET}"

if curl -s --connect-timeout 5 https://confluent.cloud > /dev/null; then
    echo -e "✅ ${GREEN}Confluent Cloud: Accesible${RESET}"
else
    echo -e "❌ ${RED}Confluent Cloud: No accesible${RESET}"
    echo -e "   ${YELLOW}Verificar tu conexión a internet${RESET}"
    VALIDATION_PASSED=false
fi

# Resultado final
echo ""
echo "======================================="
if [ "$VALIDATION_PASSED" = true ]; then
    echo -e "🎉 ${GREEN}¡Todos los prerrequisitos validados exitosamente!${RESET}"
    echo -e "${GREEN}Estás listo para comenzar el taller.${RESET}"
    echo ""
    echo -e "${BLUE}Próximos pasos:${RESET}"
    echo "1. Ejecutar: workshop-login (o ./scripts/setup/confluent-login.sh)"
    echo "2. Ejecutar: ./scripts/setup/confluent-setup-complete.sh (para automatización completa)"
    echo "3. Seguir las guías del taller"
    exit 0
else
    echo -e "❌ ${RED}Faltan algunos prerrequisitos.${RESET}"
    echo -e "${YELLOW}Por favor instala las herramientas faltantes y ejecuta este script nuevamente.${RESET}"
    exit 1
fi