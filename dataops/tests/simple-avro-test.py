#!/usr/bin/env python3
"""
Simple test para leer mensajes Avro de Confluent Cloud
"""

import os
import time
from confluent_kafka import Consumer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer
from confluent_kafka.serialization import SerializationContext, MessageField

def main():
    # Configuración del consumer
    consumer_config = {
        'bootstrap.servers': os.getenv('KAFKA_BOOTSTRAP_SERVERS'),
        'security.protocol': 'SASL_SSL',
        'sasl.mechanisms': 'PLAIN',
        'sasl.username': os.getenv('KAFKA_API_KEY'),
        'sasl.password': os.getenv('KAFKA_API_SECRET'),
        'group.id': 'simple-test-' + str(int(time.time())),
        'auto.offset.reset': 'earliest'
    }
    
    # Configuración del Schema Registry
    sr_config = {
        'url': os.getenv('SCHEMA_REGISTRY_URL', 'https://psrc-xxxxx.us-east-1.aws.confluent.cloud'),
        'basic.auth.user.info': f"{os.getenv('SCHEMA_REGISTRY_API_KEY')}:{os.getenv('SCHEMA_REGISTRY_API_SECRET')}"
    }
    
    try:
        # Crear consumer simple sin deserialización
        consumer = Consumer(consumer_config)
        consumer.subscribe(['crypto-prices'])
        
        print("🔍 Testing simple message consumption...")
        print("⏱️  Timeout: 10 seconds")
        
        start_time = time.time()
        message_count = 0
        
        while time.time() - start_time < 10:
            msg = consumer.poll(1.0)
            
            if msg is None:
                continue
                
            if msg.error():
                print(f"❌ Error: {msg.error()}")
                continue
            
            message_count += 1
            raw_value = msg.value()
            
            print(f"📨 Message {message_count}:")
            print(f"   Key: {msg.key()}")
            print(f"   Value length: {len(raw_value) if raw_value else 0} bytes")
            print(f"   Headers: {msg.headers()}")
            print(f"   First 50 bytes: {raw_value[:50] if raw_value else 'None'}")
            
            # Intentar detectar si es Avro
            if raw_value and len(raw_value) > 5:
                # Los mensajes Avro de Confluent empiezan con magic byte + schema ID
                magic_byte = raw_value[0]
                schema_id = int.from_bytes(raw_value[1:5], byteorder='big')
                print(f"   Magic byte: {magic_byte}")
                print(f"   Schema ID: {schema_id}")
                
                if magic_byte == 0:
                    print("   ✅ Detected Confluent Avro format")
                else:
                    print("   ❓ Unknown format")
            
            print("-" * 50)
            
            if message_count >= 3:  # Solo procesar 3 mensajes
                break
        
        consumer.close()
        
        if message_count == 0:
            print("❌ No messages found")
            print("💡 Check that the connector is running and producing data")
        else:
            print(f"✅ Successfully read {message_count} messages")
            print("💡 Messages are in Avro format - need Schema Registry for deserialization")
            
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()