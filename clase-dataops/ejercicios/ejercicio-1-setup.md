# 🛠️ Ejercicio 1: Setup Automatizado
**Tiempo estimado:** 15 minutos

## 🎯 Objetivo
Implementar y personalizar el setup automatizado del pipeline de streaming de criptomonedas.

## 📋 Prerequisitos
- [ ] Confluent Cloud account configurada
- [ ] Variables de entorno en `.env` configuradas
- [ ] Python 3.8+ instalado

## 🚀 Parte A: Setup Básico (10 min)

### Paso 1: Validar Estructura
```bash
# Verificar que tienes todos los archivos
ls dataops/automation/
# Debe mostrar: setup-pipeline.sh

ls scripts/kafka/
# Debe mostrar: .env, deploy-connector.sh, validate-connector.sh
```

### Paso 2: Configurar Variables de Entorno
```bash
cd scripts/kafka
cp .env.example .env

# Editar .env con tus credenciales reales:
# KAFKA_API_KEY="tu-clave-aqui"
# KAFKA_API_SECRET="tu-secreto-aqui"
```

### Paso 3: Ejecutar Setup Automatizado
```bash
cd ../../
./dataops/automation/setup-pipeline.sh
```

### ✅ Resultado Esperado
```
🚀 DataOps: Automated Pipeline Setup
========================================
📋 Validating prerequisites... ✅
🔧 Setting up environment... ✅
📊 Creating Kafka topics... ✅
🔌 Deploying HTTP Source Connector... ✅
✅ Validating setup... ✅
🎉 Pipeline setup completed successfully!
```

## 🔧 Parte B: Personalización (5 min)

### Crear Script Personalizado
Crea un nuevo archivo: `dataops/automation/setup-enhanced.sh`

```bash
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
```

### Ejecutar Script Personalizado
```bash
chmod +x dataops/automation/setup-enhanced.sh
./dataops/automation/setup-enhanced.sh
```

## 📊 Validación

### Verificar Tópicos Creados
```bash
confluent kafka topic list | grep crypto
```

**Resultado esperado:**
```
crypto-prices
crypto-prices-exploded
crypto-alerts
```

### Verificar Conector
```bash
cd scripts/kafka
./validate-connector.sh
```

### Verificar Flujo de Datos
```bash
# Consumir algunos mensajes para verificar
confluent kafka topic consume crypto-prices --from-beginning --max-messages 3
```

## 🎯 Preguntas de Reflexión

1. **¿Qué ventajas tiene el setup automatizado vs manual?**
2. **¿Qué validaciones adicionales agregarías al script?**
3. **¿Cómo manejarías errores en el proceso de setup?**

## 🚨 Troubleshooting

### Error: "Confluent CLI not found"
```bash
# Instalar Confluent CLI
curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest
export PATH=$PATH:$HOME/.confluent/bin
```

### Error: "API credentials invalid"
```bash
# Verificar variables de entorno
source scripts/kafka/.env
echo "API Key: $KAFKA_API_KEY"
echo "API Secret: $KAFKA_API_SECRET"
```

### Error: "Topic already exists"
```bash
# Listar tópicos existentes
confluent kafka topic list
# Eliminar si es necesario
confluent kafka topic delete crypto-prices
```

## ✅ Criterios de Éxito

- [ ] Setup básico ejecuta sin errores
- [ ] Todos los tópicos se crean correctamente
- [ ] Conector se despliega y está activo
- [ ] Script personalizado funciona
- [ ] Validaciones end-to-end pasan
- [ ] Mensajes fluyen en los tópicos

---

**Siguiente:** [Ejercicio 2: Tests de Calidad](ejercicio-2-testing.md)