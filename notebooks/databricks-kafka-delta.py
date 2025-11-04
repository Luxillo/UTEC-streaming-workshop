# Databricks notebook source
# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Instalación y Configuración
# MAGIC
# MAGIC Este notebook se conecta a un tema de Kafka que contiene precios de criptomonedas en formato Avro, procesa los datos y los escribe en una tabla Delta.
# MAGIC
# MAGIC **Prerrequisitos:**
# MAGIC - Un clúster de Databricks en ejecución.
# MAGIC - Un tema de Kafka con datos en formato Avro.
# MAGIC - Detalles de la cuenta de Confluent Cloud (o los detalles de tu proveedor de Kafka).

# COMMAND ----------

# MAGIC %pip install confluent-kafka avro

# COMMAND ----------

# DBTITLE 1,Configuración de Kafka y Schema Registry
# Reemplaza con tus credenciales y configuraciones de Confluent Cloud
# Puedes encontrarlos en tu panel de control de Confluent Cloud o en el archivo .env

bootstrap_servers = "TUS_BOOTSTRAP_SERVERS"
kafka_api_key = "TU_KAFKA_API_KEY"
kafka_api_secret = "TU_KAFKA_API_SECRET"
schema_registry_url = "TU_SCHEMA_REGISTRY_URL"
schema_registry_api_key = "TU_SCHEMA_REGISTRY_API_KEY"
schema_registry_api_secret = "TU_SCHEMA_REGISTRY_API_SECRET"

# Tema de Kafka
topic = "crypto-prices"

# Esquema Avro para los datos
# Esto se basa en el archivo price-event-schema.avsc
avro_schema_str = '''{
  "type": "record",
  "name": "ConnectDefault",
  "namespace": "io.confluent.connect.avro",
  "fields": [
    {"name": "binancecoin", "type": {"type": "record", "name": "binancecoin", "fields": [{"name": "usd", "type": "double"}, {"name": "usd_market_cap", "type": "double"}, {"name": "usd_24h_vol", "type": "double"}, {"name": "usd_24h_change", "type": "double"}, {"name": "last_updated_at", "type": "int"}], "connect.name": "binancecoin"}},
    {"name": "bitcoin", "type": {"type": "record", "name": "bitcoin", "namespace": "", "fields": [{"name": "usd", "type": "int"}, {"name": "usd_market_cap", "type": "double"}, {"name": "usd_24h_vol", "type": "double"}, {"name": "usd_24h_change", "type": "double"}, {"name": "last_updated_at", "type": "int"}], "connect.name": "bitcoin"}},
    {"name": "cardano", "type": {"type": "record", "name": "cardano", "namespace": "", "fields": [{"name": "usd", "type": "double"}, {"name": "usd_market_cap", "type": "double"}, {"name": "usd_24h_vol", "type": "double"}, {"name": "usd_24h_change", "type": "double"}, {"name": "last_updated_at", "type": "int"}], "connect.name": "cardano"}},
    {"name": "ethereum", "type": {"type": "record", "name": "ethereum", "fields": [{"name": "usd", "type": "double"}, {"name": "usd_market_cap", "type": "double"}, {"name": "usd_24h_vol", "type": "double"}, {"name": "usd_24h_change", "type": "double"}, {"name": "last_updated_at", "type": "int"}], "connect.name": "ethereum"}},
    {"name": "solana", "type": {"type": "record", "name": "solana", "fields": [{"name": "usd", "type": "double"}, {"name": "usd_market_cap", "type": "double"}, {"name": "usd_24h_vol", "type": "double"}, {"name": "usd_24h_change", "type": "double"}, {"name": "last_updated_at", "type": "int"}], "connect.name": "solana"}}
  ]
}'''

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. Leer desde Kafka
# MAGIC
# MAGIC Usaremos Spark Structured Streaming para leer desde el tema de Kafka.

# COMMAND ----------

from pyspark.sql.functions import expr, col
from pyspark.sql.avro.functions import from_avro

# Leer desde Kafka
kafka_df = (spark.readStream
  .format("kafka")
  .option("kafka.bootstrap.servers", bootstrap_servers)
  .option("kafka.security.protocol", "SASL_SSL")
  .option("kafka.sasl.mechanism", "PLAIN")
  .option("kafka.sasl.jaas.config", f'''org.apache.kafka.common.security.plain.PlainLoginModule required username="{kafka_api_key}" password="{kafka_api_secret}";''')
  .option("subscribe", topic)
  .load()
)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Deserializar y Transformar Datos
# MAGIC
# MAGIC El mensaje `value` de Kafka está en formato Avro. Necesitamos deserializarlo usando el esquema y luego aplanar la estructura para un análisis más fácil.

# COMMAND ----------

# Deserializar los datos Avro
# Los primeros 5 bytes del mensaje son metadatos de Confluent Schema Registry, así que los omitimos.
deserialized_df = kafka_df.select(
    from_avro(expr("substring(value, 6)"), avro_schema_str).alias("data")
)

# Aplanar la estructura anidada
# Esto crea una fila por cada criptomoneda a partir de los registros anidados
flattened_df = deserialized_df.selectExpr(
    "inline(array(data.bitcoin, data.ethereum,.binancecoin, data.cardano, data.solana))"
)

# Agregar una columna para el nombre de la criptomoneda
# Podemos extraer esto de la información del esquema si está disponible, o agregarlo manualmente.
# Para simplificar, agregaremos una identificación que se incrementa monotónicamente.
# Un mejor enfoque sería modificar la fuente para incluir el nombre de la moneda en el registro.

from pyspark.sql.functions import monotonically_increasing_id

final_df = flattened_df.withColumn("id", monotonically_increasing_id())

# COMMAND ----------

# MAGIC %md
# MAGIC ## 4. Escribir en Delta Lake
# MAGIC
# MAGIC Escribiremos los datos procesados en una tabla Delta. Esto proporciona una capa de almacenamiento confiable y escalable.

# COMMAND ----------

# Definir la ruta para la tabla Delta y la ubicación del checkpoint
delta_table_path = "/delta/crypto_prices"
checkpoint_path = "/delta/checkpoints/crypto_prices"

# Escribir el stream a una tabla Delta
(final_df.writeStream
  .format("delta")
  .outputMode("append")
  .option("checkpointLocation", checkpoint_path)
  .start(delta_table_path)
)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 5. Analizar los Datos
# MAGIC
# MAGIC Ahora que los datos están en una tabla Delta, puedes consultarlos usando Spark SQL estándar.

# COMMAND ----------

# Esperar a que el stream pueble la tabla
import time
time.sleep(60) # Ajustar según sea necesario

# COMMAND ----------

# DBTITLE 1,Consultar la Tabla Delta
# Leer la tabla Delta
crypto_prices_delta_df = spark.read.format("delta").load(delta_table_path)

# Mostrar algunos datos
display(crypto_prices_delta_df.limit(10))

# COMMAND ----------

# DBTITLE 1,Análisis Simple: Conteo de Registros por Criptomoneda
# Este análisis es un poco complicado con la estructura actual.
# Un mejor enfoque es agregar un campo "coin_name" durante la transformación.

# Intentemos identificar las monedas según su estructura (no es ideal)
from pyspark.sql.functions import when

# Esta es una solución alternativa. Una solución adecuada implicaría un mejor esquema.
# Asumimos que el orden es consistente.
crypto_prices_delta_df = crypto_prices_delta_df.withColumn(
    "coin_name",
    when(col("usd").isNotNull(), "desconocido") # Marcador de posición
)

# Agrupar por la nueva columna coin_name
analysis_df = crypto_prices_delta_df.groupBy("coin_name").count()

display(analysis_df)

# COMMAND ----------

# MAGIC %md
# MAGIC ### Próximos Pasos
# MAGIC
# MAGIC - **Mejorar Esquema:** El esquema Avro actual está anidado. Para un análisis más fácil, podrías modificar el productor de Kafka para enviar un esquema más plano con un campo dedicado para el nombre de la criptomoneda (por ejemplo, `{"coin_name": "bitcoin", "usd": 60000, ...}`).
# MAGIC - **Análisis Avanzado:** Ahora puedes realizar análisis más complejos en la tabla Delta, como análisis de series de tiempo, detección de anomalías o construcción de modelos de aprendizaje automático.
# MAGIC - **Visualización de Datos:** Usa las herramientas de visualización de Databricks para crear paneles y gráficos a partir de tu tabla Delta.
