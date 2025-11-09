#!/bin/bash

# 🚀 Script de Bootstrap de Confluent Cloud Workshop para GitHub Codespaces
# Este script instala todas las herramientas y dependencias necesarias.

set -euo pipefail

# Colors for output
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

echo -e "🚀 ${BLUE}Arranque del entorno del taller en la nube de Confluent${RESET}"
echo "=================================================="

# Update system packages
echo -e "📦 ${YELLOW}Updating system packages...${RESET}"
sudo apt-get update -qq
sudo apt-get install -y curl wget unzip jq git make

# Install Confluent CLI
echo -e "☁️ ${YELLOW}Installing Confluent CLI...${RESET}"
curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest
# The installer puts the binary in ./bin/confluent, not ~/.confluent/bin/confluent
if [ -f "./bin/confluent" ]; then
    sudo mv ./bin/confluent /usr/local/bin/
elif [ -f "$HOME/.confluent/bin/confluent" ]; then
    sudo mv "$HOME/.confluent/bin/confluent" /usr/local/bin/
else
    # Find where it was installed
    CONFLUENT_PATH=$(find . -name "confluent" -type f 2>/dev/null | head -1)
    if [ -n "$CONFLUENT_PATH" ]; then
        sudo mv "$CONFLUENT_PATH" /usr/local/bin/
    else
        echo -e "❌ ${RED}Could not find confluent binary${RESET}"
        exit 1
    fi
fi
echo -e "✅ ${GREEN}Confluent CLI installed${RESET}"

# Install DuckDB
echo -e "🦆 ${YELLOW}Installing DuckDB...${RESET}"
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo -e "   🔧 ${YELLOW}ARM64 detected: using DuckDB v1.2.0 with native ARM64 support${RESET}"
    DUCKDB_VERSION="v1.2.0"
    DUCKDB_ARCH="linux-aarch64"
else
    echo -e "   💻 ${YELLOW}x86_64 detected: using DuckDB v1.3.2${RESET}"
    DUCKDB_VERSION="v1.3.2"
    DUCKDB_ARCH="linux-amd64"
fi
curl -L "https://github.com/duckdb/duckdb/releases/download/${DUCKDB_VERSION}/duckdb_cli-${DUCKDB_ARCH}.zip" -o duckdb.zip
unzip -q duckdb.zip
sudo mv duckdb /usr/local/bin/
rm duckdb.zip
sudo chmod +x /usr/local/bin/duckdb
echo -e "✅ ${GREEN}DuckDB installed${RESET}"

# Install additional Python packages for workshop
echo -e "🐍 ${YELLOW}Installing Python packages...${RESET}"
# Ensure pip is available - devcontainer features should have installed it
if command -v pip3 >/dev/null 2>&1; then
    pip3 install --user confluent-kafka[avro] requests pandas duckdb-engine sqlalchemy
elif command -v pip >/dev/null 2>&1; then
    pip install --user confluent-kafka[avro] requests pandas duckdb-engine sqlalchemy
else
    echo -e "⚠️  ${YELLOW}pip not found, installing via python3 -m pip${RESET}"
    python3 -m pip install --user confluent-kafka[avro] requests pandas duckdb-engine sqlalchemy
fi
echo -e "✅ ${GREEN}Python packages installed${RESET}"

# Install DataOps specific tools
echo -e "📊 ${YELLOW}Installing DataOps tools...${RESET}"
if command -v pip3 >/dev/null 2>&1; then
    pip3 install --user great-expectations apache-airflow dbt-core dbt-duckdb pytest
elif command -v pip >/dev/null 2>&1; then
    pip install --user great-expectations apache-airflow dbt-core dbt-duckdb pytest
else
    python3 -m pip install --user great-expectations apache-airflow dbt-core dbt-duckdb pytest
fi
echo -e "✅ ${GREEN}DataOps tools installed${RESET}"

# Install Java dependencies
echo -e "☕ ${YELLOW}Setting up Java environment...${RESET}"
# Maven dependencies will be handled by individual projects
echo -e "✅ ${GREEN}Java environment ready${RESET}"

# Create cache directory
mkdir -p /home/vscode/.cache

# Set up shell aliases and environment
echo -e "🔧 ${YELLOW}Configuring shell environment...${RESET}"
cat >> /home/vscode/.zshrc << 'EOF'

# Confluent Cloud Workshop Aliases
alias cc='confluent'
alias ccenv='confluent environment'
alias cccluster='confluent kafka cluster'
alias cctopic='confluent kafka topic'
alias ccconnector='confluent connect connector'
alias ccflink='confluent flink'

# Workshop environment variables
export WORKSHOP_ENV=codespaces
export CONFLUENT_DISABLE_UPDATES=true
export PATH=$PATH:/usr/local/bin

# Workshop helper functions
workshop-status() {
    echo "🔍 Workshop Environment Status:"
    echo "  Confluent CLI: $(confluent version 2>/dev/null || echo 'Not authenticated')"
    echo "  DuckDB: $(duckdb --version 2>/dev/null || echo 'Not available')"
    echo "  Python: $(python3 --version)"
    echo "  Java: $(java -version 2>&1 | head -1)"
    echo "  Great Expectations: $(python3 -c 'import great_expectations; print(great_expectations.__version__)' 2>/dev/null || echo 'Not available')"
    echo "  dbt: $(dbt --version 2>/dev/null | head -1 || echo 'Not available')"
}

workshop-validate() {
    echo "🧪 Running workshop prerequisites validation..."
    if [ -f "./scripts/setup/validate-prerequisites.sh" ]; then
        ./scripts/setup/validate-prerequisites.sh
    else
        echo "❌ Validation script not found. Make sure you're in the workshop root directory."
    fi
}

workshop-login() {
    echo "🔐 Starting Confluent Cloud login..."
    if [ -f "./scripts/setup/confluent-login.sh" ]; then
        ./scripts/setup/confluent-login.sh
    else
        echo "❌ Login script not found. Make sure you're in the workshop root directory."
    fi
}

dataops-init() {
    echo "📊 Initializing DataOps environment..."
    if [ -f "./scripts/dataops/init-dataops.sh" ]; then
        ./scripts/dataops/init-dataops.sh
    else
        echo "❌ DataOps init script not found. Creating basic structure..."
        mkdir -p ./dataops/{dbt,great_expectations,airflow,tests}
        echo "✅ Basic DataOps structure created"
    fi
}

dataops-validate() {
    echo "🧪 Validating DataOps pipeline..."
    if [ -f "./scripts/dataops/validate-pipeline.sh" ]; then
        ./scripts/dataops/validate-pipeline.sh
    else
        echo "❌ DataOps validation script not found."
    fi
}

EOF

# Make scripts executable
echo -e "🔐 ${YELLOW}Setting script permissions...${RESET}"
find /workspaces/*/scripts -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true

# VSCode extensions are handled automatically by devcontainer.json
echo -e "🔌 ${YELLOW}VSCode extensions will be installed automatically${RESET}"
echo -e "   📝 Students can validate and install manually if needed${RESET}"

# Create welcome message
cat > /home/vscode/.workshop-welcome << 'EOF'
🎉 ¡Bienvenido al taller de Confluent Cloud y DataOps!

Comandos de inicio rápido:
    workshop-status     - Verificar el estado del entorno
    workshop-validate   - Ejecutar la validación de prerrequisitos
    workshop-login      - Iniciar sesión en Confluent Cloud
    dataops-init        - Inicializar entorno DataOps
    dataops-validate    - Validar pipeline DataOps

Estructura del taller:
    📚 guias/ - Guías paso a paso del taller
    🔧 scripts/ - Scripts de automatización
    📊 data/ - Archivos de datos de ejemplo
    ⚙️ configs/ - Plantillas de configuración
    🚨 troubleshooting/ - Guías para la resolución de problemas
    📈 dataops/ - Herramientas y pipelines DataOps

Talleres disponibles:
    🚀 Kafka Streaming - Procesamiento en tiempo real
    📊 DataOps - Pipelines de datos, calidad y observabilidad

Próximos pasos para Kafka:
    1. Ejecutar: workshop-validate
    2. Ejecutar: workshop-login
    3. Seguir guias/01-setup-confluent-cloud.adoc

Próximos pasos para DataOps:
    1. Ejecutar: workshop-validate
    2. Ejecutar: dataops-init
    3. Seguir guias/dataops/01-setup-dataops-environment.adoc

¡Que disfrutes aprendiendo! 🚀
EOF

# Display welcome message on terminal startup
echo 'cat /home/vscode/.workshop-welcome' >> /home/vscode/.zshrc

echo ""
echo -e "🎉 ${GREEN}Bootstrap completed successfully!${RESET}"
echo -e "🔧 ${BLUE}Environment ready for Confluent Cloud Workshop${RESET}"
echo ""
echo -e "📋 ${YELLOW}Installed Tools:${RESET}"
echo "  ✅ Confluent CLI: $(confluent version 2>/dev/null || echo 'Ready for authentication')"
echo "  ✅ DuckDB: $(duckdb --version)"
echo "  ✅ Python: $(python3 --version)"
echo "  ✅ Java: $(java -version 2>&1 | head -1)"
echo ""
echo -e "💡 ${BLUE}Restart your terminal or run 'source ~/.zshrc' to load workshop aliases${RESET}"``