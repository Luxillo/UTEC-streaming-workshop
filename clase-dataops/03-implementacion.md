# 🚀 Implementación Práctica DataOps
**Bloques 3-6: 90 minutos**

## 🎯 Bloque 3: Automatización (30 min)

### Demo: Manual vs Automatizado (5 min)

#### Proceso Manual (❌)
```bash
# 15+ pasos manuales
confluent login
confluent environment use env-xxxxx
confluent kafka cluster use lkc-xxxxx
confluent kafka topic create crypto-prices --partitions 3
confluent kafka topic create crypto-prices-exploded --partitions 3
# ... más configuraciones
```

#### Proceso Automatizado (✅)
```bash
# 1 comando
./dataops/automation/setup-pipeline.sh
```

### 🛠️ PRÁCTICA 1: Setup Automatizado (10 min)

**Paso 1:** Validar prerequisitos
```bash
cd UTEC-streaming-workshop
ls dataops/automation/
```

**Paso 2:** Configurar variables de entorno
```bash
cd scripts/kafka
cp .env.example .env
# Editar .env con tus credenciales
```

**Paso 3:** Ejecutar setup automatizado
```bash
# Instalar dependencias
./dataops/automation/install-dependencies.sh

# Luego ejecutar el setup completo
./dataops/automation/setup-pipeline.sh
```

**Resultado esperado:**
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

### 🛠️ PRÁCTICA 2: Personalizar Automatización (15 min)

**Crear script personalizado:**
```bash
# Crear nuevo script
touch dataops/automation/setup-custom-pipeline.sh
```

**Contenido del script:**
```bash
#!/bin/bash
# Setup personalizado con validaciones adicionales

echo "🔧 Custom Pipeline Setup"

# Validar conectividad API
echo "🌐 Testing CoinGecko API..."
curl -s "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd" | jq .

# Crear tópico adicional para alertas
echo "📊 Creating alerts topic..."
confluent kafka topic create crypto-alerts --partitions 1

# Validar que los tópicos existen
echo "✅ Validating topics..."
confluent kafka topic list | grep crypto

echo "🎉 Custom setup completed!"
```

## 🧪 Bloque 4: Testing de Calidad (30 min)

### Tipos de Tests de Datos (5 min)

```python
# 1. Tests de Estructura
def test_schema_compliance(message):
    required_fields = ['bitcoin', 'ethereum', 'solana']
    return all(field in message for field in required_fields)

# 2. Tests de Rango
def test_price_ranges(message):
    btc_price = message['bitcoin']['usd']
    return 1000 <= btc_price <= 200000

# 3. Tests de Frescura
def test_data_freshness(message):
    age = current_time - message['bitcoin']['last_updated_at']
    return age < 300  # 5 minutos

# 4. Tests de Completitud
def test_completeness(message):
    return all(value is not None for value in message.values())
```

### 🛠️ PRÁCTICA 3: Ejecutar Tests Existentes (10 min)

```bash
# Ejecutar tests de calidad
cd dataops/tests
python3 data-quality-tests.py
```

**Analizar resultados:**
```json
{
  "summary": {
    "total_tests": 20,
    "passed": 18,
    "failed": 2,
    "success_rate": 90.0
  },
  "test_results": [
    {
      "test": "message_structure",
      "status": "PASS",
      "message": "Message structure is valid"
    }
  ]
}
```

### 🛠️ PRÁCTICA 4: Crear Test Personalizado (15 min)

**Agregar test para volatilidad:**
```python
def test_price_volatility(self, message: Dict[str, Any]) -> DataQualityResult:
    """Test personalizado: Detectar volatilidad extrema"""
    
    for crypto, data in message.items():
        if isinstance(data, dict) and 'usd_24h_change' in data:
            change_pct = abs(data['usd_24h_change'])
            
            # Alerta si cambio > 20% en 24h
            if change_pct > 20:
                return DataQualityResult(
                    "price_volatility", False,
                    f"Extreme volatility in {crypto}: {change_pct}%", 
                    datetime.now()
                )
    
    return DataQualityResult(
        "price_volatility", True,
        "Price volatility within normal ranges", 
        datetime.now()
    )
```

**Integrar el nuevo test:**
```python
# En el método run_tests, agregar:
tests = [
    self.test_message_structure(message_data),
    self.test_data_freshness(message_data),
    self.test_price_validity(message_data),
    self.test_data_completeness(message_data),
    self.test_price_volatility(message_data)  # ← Nuevo test
]
```

## 📊 Bloque 5: Monitoreo (20 min)

### Métricas Clave (5 min)

```python
# Métricas de Pipeline
pipeline_metrics = {
    'throughput': 'Mensajes por segundo',
    'latency': 'Tiempo de procesamiento',
    'error_rate': 'Porcentaje de errores',
    'data_quality_score': 'Score de calidad'
}

# Métricas de Negocio
business_metrics = {
    'price_updates_per_minute': 'Actualizaciones de precio',
    'api_response_time': 'Tiempo de respuesta API',
    'data_freshness': 'Frescura de datos',
    'coverage': 'Cobertura de criptomonedas'
}
```

### 🛠️ PRÁCTICA 5: Monitoreo en Tiempo Real (10 min)

```bash
# Iniciar monitoreo
cd dataops/monitoring
python3 pipeline-monitor.py
```

**Observar métricas en tiempo real:**
```
🔍 Starting monitoring for topic: crypto-prices
📊 crypto-prices: 10 messages, 2.50 msg/sec
📊 crypto-prices: 20 messages, 2.67 msg/sec
⚠️  ALERT: Bitcoin price anomaly: $95000
📊 crypto-prices: 30 messages, 2.73 msg/sec
```

### 🛠️ PRÁCTICA 6: Configurar Alertas Personalizadas (5 min)

**Agregar alerta para Ethereum:**
```python
def check_ethereum_alerts(self, data):
    """Alerta personalizada para Ethereum"""
    if 'ethereum' in data:
        eth_price = data['ethereum']['usd']
        eth_change = data['ethereum']['usd_24h_change']
        
        alerts = []
        
        # Alerta por precio alto
        if eth_price > 5000:
            alerts.append({
                'type': 'ETH_PRICE_HIGH',
                'message': f'Ethereum price above $5000: ${eth_price}',
                'severity': 'MEDIUM'
            })
        
        # Alerta por caída fuerte
        if eth_change < -15:
            alerts.append({
                'type': 'ETH_CRASH',
                'message': f'Ethereum crashed {eth_change}% in 24h',
                'severity': 'HIGH'
            })
        
        return alerts
    return []
```

## 🔄 Bloque 6: CI/CD (10 min)

### Demo: Pipeline CI/CD (5 min)

**GitHub Actions Workflow:**
```yaml
name: DataOps Pipeline
on: [push, pull_request]

jobs:
  data-quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Data Quality Tests
        run: ./dataops/tests/run-data-quality-tests.sh
      
  deploy:
    needs: data-quality
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy Pipeline
        run: ./dataops/automation/setup-pipeline.sh
```

### 🛠️ PRÁCTICA 7: Configurar CI/CD (5 min)

```bash
# Crear directorio de workflows
mkdir -p .github/workflows

# Copiar workflow
cp dataops/ci-cd/github-actions.yml .github/workflows/dataops.yml

# Commit y push
git add .
git commit -m "Add DataOps CI/CD pipeline"
git push origin main
```

## 📋 Checklist de Validación

### ✅ Automatización
- [ ] Pipeline se despliega con 1 comando
- [ ] Todos los tópicos se crean automáticamente
- [ ] Conector se despliega sin errores
- [ ] Validación end-to-end funciona

### ✅ Testing
- [ ] Tests de calidad ejecutan sin errores
- [ ] Success rate > 80%
- [ ] Test personalizado implementado
- [ ] Reportes se generan correctamente

### ✅ Monitoreo
- [ ] Métricas se recolectan en tiempo real
- [ ] Alertas se disparan correctamente
- [ ] Dashboard muestra información relevante
- [ ] Logs se generan apropiadamente

### ✅ CI/CD
- [ ] Workflow de GitHub Actions configurado
- [ ] Tests automáticos en cada commit
- [ ] Deployment automático en main
- [ ] Notificaciones funcionando

## 🎯 Entregables Finales

1. **Pipeline DataOps funcionando:** Setup automatizado completo
2. **Suite de tests:** Tests de calidad personalizados
3. **Sistema de monitoreo:** Métricas y alertas en tiempo real
4. **CI/CD configurado:** Pipeline automatizado en GitHub

---

**¡Felicitaciones! Has implementado DataOps completo en tu pipeline de streaming** 🎉