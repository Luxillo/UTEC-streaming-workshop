# 🧪 Ejercicio 2: Tests de Calidad de Datos
**Tiempo estimado:** 20 minutos

## 🎯 Objetivo
Implementar y personalizar tests de calidad de datos para el pipeline de streaming de criptomonedas.

## 📋 Prerequisitos
- [ ] Pipeline funcionando (Ejercicio 1 completado)
- [ ] Python 3.8+ con dependencias instaladas:
  - [ ] `confluent-kafka` - Cliente Kafka
  - [ ] `avro-python3` - Deserialización Avro
  - [ ] `fastavro` - Procesamiento Avro optimizado
- [ ] Variables de entorno configuradas en `.env`:
  - [ ] `KAFKA_BOOTSTRAP_SERVERS` - URL del cluster
  - [ ] `SCHEMA_REGISTRY_URL` - URL del Schema Registry
  - [ ] Credenciales de API configuradas
- [ ] Datos fluyendo en tópicos en **formato Avro**

## 🧪 Parte A: Ejecutar Tests Existentes (10 min)

### Paso 1: Instalar Dependencias
```bash
# Instalar dependencias para Avro
pip3 install confluent-kafka avro-python3 fastavro

# O usar el script automatizado
./dataops/automation/install-dependencies.sh
```

### Paso 2: Configurar Variables de Entorno
```bash
cd scripts/kafka
source .env

# Verificar que las variables estén configuradas
echo "Bootstrap Servers: $KAFKA_BOOTSTRAP_SERVERS"
echo "Schema Registry: $SCHEMA_REGISTRY_URL"
echo "API Key: ${KAFKA_API_KEY:0:10}..."
```

📝 **Nota Importante**: Los datos en Confluent Cloud están en **formato Avro**, no JSON. El script de tests usa el Schema Registry para deserializar automáticamente los mensajes binarios a objetos Python.

### Paso 3: Ejecutar Tests de Calidad
```bash
cd ../../dataops/tests

# El script detectará automáticamente el formato Avro
python3 data-quality-tests.py

# Alternativamente, usar la versión CLI si hay problemas con Schema Registry
python3 data-quality-cli.py
```

### ✅ Resultado Esperado
```
🔍 Running data quality tests on topic: crypto-prices
⏱️  Timeout: 30 seconds
✅ Tested message 1
✅ Tested message 2
✅ Tested message 3
📊 Total messages tested: 3

==================================================
📋 DATA QUALITY REPORT
==================================================
✅ Passed: 10
❌ Failed: 2
📊 Success Rate: 83.3%

📄 Report saved to: data-quality-report.json
```

### Paso 4: Analizar Reporte
```bash
# Ver reporte detallado
cat data-quality-report.json | jq .
```

## 🔧 Parte B: Crear Tests Personalizados (10 min)

### Test 1: Validación de Volatilidad Extrema
Agrega este método a la clase `CryptoDataQualityTester`:

```python
def test_extreme_volatility(self, message: Dict[str, Any]) -> DataQualityResult:
    """Test personalizado: Detectar volatilidad extrema en 24h"""
    
    volatility_thresholds = {
        'bitcoin': 15.0,      # Bitcoin: máximo 15% cambio
        'ethereum': 20.0,     # Ethereum: máximo 20% cambio
        'solana': 25.0,       # Solana: máximo 25% cambio
        'cardano': 30.0,      # Cardano: máximo 30% cambio
        'binancecoin': 20.0   # BNB: máximo 20% cambio
    }
    
    for crypto, data in message.items():
        if isinstance(data, dict) and 'usd_24h_change' in data:
            change_pct = abs(data['usd_24h_change'])
            threshold = volatility_thresholds.get(crypto, 25.0)
            
            if change_pct > threshold:
                return DataQualityResult(
                    "extreme_volatility", False,
                    f"Extreme volatility in {crypto}: {change_pct}% (threshold: {threshold}%)", 
                    datetime.now()
                )
    
    return DataQualityResult(
        "extreme_volatility", True,
        "Volatility within acceptable ranges", 
        datetime.now()
    )
```

### Test 2: Validación de Market Cap
```python
def test_market_cap_consistency(self, message: Dict[str, Any]) -> DataQualityResult:
    """Test personalizado: Validar consistencia de market cap"""
    
    for crypto, data in message.items():
        if isinstance(data, dict) and all(k in data for k in ['usd', 'usd_market_cap']):
            price = data['usd']
            market_cap = data['usd_market_cap']
            
            # Market cap debe ser mayor que el precio (obviamente)
            if market_cap < price:
                return DataQualityResult(
                    "market_cap_consistency", False,
                    f"Market cap ({market_cap}) less than price ({price}) for {crypto}", 
                    datetime.now()
                )
            
            # Market cap no puede ser 0 si hay precio
            if price > 0 and market_cap == 0:
                return DataQualityResult(
                    "market_cap_consistency", False,
                    f"Market cap is 0 but price is {price} for {crypto}", 
                    datetime.now()
                )
    
    return DataQualityResult(
        "market_cap_consistency", True,
        "Market cap data is consistent", 
        datetime.now()
    )
```

### Test 3: Validación de Correlación de Precios
```python
def test_price_correlation(self, message: Dict[str, Any]) -> DataQualityResult:
    """Test personalizado: Detectar precios anómalos por correlación"""
    
    # Si Bitcoin sube/baja mucho, otras cryptos deberían seguir la tendencia
    if 'bitcoin' in message and 'ethereum' in message:
        btc_change = message['bitcoin'].get('usd_24h_change', 0)
        eth_change = message['ethereum'].get('usd_24h_change', 0)
        
        # Si Bitcoin cambia más de 10%, Ethereum debería cambiar en la misma dirección
        if abs(btc_change) > 10:
            if (btc_change > 0 and eth_change < -5) or (btc_change < 0 and eth_change > 5):
                return DataQualityResult(
                    "price_correlation", False,
                    f"Unusual correlation: BTC {btc_change}%, ETH {eth_change}%", 
                    datetime.now()
                )
    
    return DataQualityResult(
        "price_correlation", True,
        "Price correlations are normal", 
        datetime.now()
    )
```

### Integrar Tests Personalizados
Modifica el método `run_tests` para incluir los nuevos tests:

```python
# En el método run_tests, actualizar la lista de tests:
tests = [
    self.test_message_structure(message_data),
    self.test_data_freshness(message_data),
    self.test_price_validity(message_data),
    self.test_data_completeness(message_data),
    self.test_extreme_volatility(message_data),      # ← Nuevo
    self.test_market_cap_consistency(message_data),  # ← Nuevo
    self.test_price_correlation(message_data)        # ← Nuevo
]
```

### Ejecutar Tests Personalizados
```bash
python3 data-quality-tests.py
```

## 📊 Parte C: Automatizar Tests (5 min)

### Crear Script de Ejecución
```bash
# Crear script automatizado
touch run-enhanced-tests.sh
```

**Contenido del script:**
```bash
#!/bin/bash
# Script para ejecutar tests de calidad mejorados

set -e

echo "🧪 Running Enhanced Data Quality Tests"
echo "====================================="

# Setup environment
cd ../../scripts/kafka
source .env
cd ../../dataops/tests

# Run tests multiple times for better coverage
for i in {1..3}; do
    echo "🔄 Test run $i/3"
    python3 data-quality-tests.py
    sleep 30  # Wait for more data
done

# Analyze results
echo "📊 Analyzing test results..."
if [ -f "data-quality-report.json" ]; then
    SUCCESS_RATE=$(python3 -c "import json; report=json.load(open('data-quality-report.json')); print(report['summary']['success_rate'])")
    
    echo "📈 Final Success Rate: $SUCCESS_RATE%"
    
    if (( $(echo "$SUCCESS_RATE >= 85" | bc -l) )); then
        echo "✅ Data quality: EXCELLENT"
    elif (( $(echo "$SUCCESS_RATE >= 70" | bc -l) )); then
        echo "⚠️  Data quality: GOOD"
    else
        echo "❌ Data quality: NEEDS IMPROVEMENT"
    fi
fi
```

### Ejecutar Tests Automatizados
```bash
chmod +x run-enhanced-tests.sh
./run-enhanced-tests.sh
```

## 📋 Validación y Análisis

### Analizar Patrones de Fallas
```bash
# Ver tests que fallan frecuentemente
cat data-quality-report.json | jq '.test_results[] | select(.status == "FAIL")'
```

### Crear Dashboard Simple
```python
# dashboard.py - Script simple para visualizar resultados
import json
import matplotlib.pyplot as plt

with open('data-quality-report.json', 'r') as f:
    report = json.load(f)

# Gráfico de success rate
tests = [r['test'] for r in report['test_results']]
statuses = [1 if r['status'] == 'PASS' else 0 for r in report['test_results']]

plt.figure(figsize=(12, 6))
plt.bar(tests, statuses, color=['green' if s else 'red' for s in statuses])
plt.title('Data Quality Test Results')
plt.ylabel('Pass (1) / Fail (0)')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('test-results.png')
print("📊 Dashboard saved as test-results.png")
```

## 🎯 Desafíos Adicionales

### Desafío 1: Test de Tendencias
Implementa un test que detecte si los precios están "congelados" (sin cambios por más de 10 minutos).

### Desafío 2: Test de Outliers
Crea un test que detecte precios que están más de 3 desviaciones estándar de la media histórica.

### Desafío 3: Test de API Health
Implementa un test que valide la salud de la API de CoinGecko basado en los tiempos de respuesta.

## ✅ Criterios de Éxito

- [ ] Tests básicos ejecutan correctamente
- [ ] Success rate > 80%
- [ ] 3 tests personalizados implementados
- [ ] Tests automatizados funcionan
- [ ] Reportes se generan correctamente
- [ ] Análisis de resultados completado

## 🚨 Troubleshooting

### Error: "No messages to test"
```bash
# Verificar que hay datos en el tópico
confluent kafka topic consume crypto-prices --from-beginning --max-messages 1
```

### Error: "Schema Registry error"
```bash
# Verificar configuración del Schema Registry
echo "Schema Registry URL: $SCHEMA_REGISTRY_URL"
echo "Schema Registry Key: $SCHEMA_REGISTRY_API_KEY"

# Usar versión alternativa con CLI
python3 data-quality-cli.py
```

### Error: "Cannot decode message as UTF-8"
```bash
# Esto es normal - los mensajes están en formato Avro binario
# Usar el script principal que maneja Avro automáticamente
python3 data-quality-tests.py
```

### Tests fallan consistentemente
```bash
# Revisar logs detallados
python3 -c "
import logging
logging.basicConfig(level=logging.DEBUG)
exec(open('data-quality-tests.py').read())
"
```

---

**Siguiente:** [Ejercicio 3: Monitoreo](ejercicio-3-monitoreo.md)