#!/usr/bin/env python3
"""
DataOps: Pipeline Monitoring
Monitoreo en tiempo real del pipeline de streaming
"""

import json
import time
import logging
from datetime import datetime
from typing import Dict, List
from confluent_kafka import Consumer, KafkaError
from confluent_kafka.admin import AdminClient, ConfigResource
import os
import threading
from dataclasses import dataclass, asdict

@dataclass
class PipelineMetrics:
    timestamp: datetime
    topic: str
    message_count: int
    avg_message_size: int
    lag: int
    throughput_per_sec: float
    error_count: int

class PipelineMonitor:
    def __init__(self):
        self.consumer_config = {
            'bootstrap.servers': os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092'),
            'group.id': 'pipeline-monitor',
            'auto.offset.reset': 'latest'
        }
        self.admin_client = AdminClient({'bootstrap.servers': self.consumer_config['bootstrap.servers']})
        self.metrics: List[PipelineMetrics] = []
        self.running = False
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('pipeline-monitor.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def get_topic_metadata(self, topic: str) -> Dict:
        """Obtener metadata del tópico"""
        try:
            metadata = self.admin_client.list_topics(topic=topic, timeout=10)
            if topic in metadata.topics:
                topic_metadata = metadata.topics[topic]
                return {
                    'partitions': len(topic_metadata.partitions),
                    'error': topic_metadata.error
                }
        except Exception as e:
            self.logger.error(f"Error getting topic metadata: {e}")
        return {}
    
    def monitor_topic(self, topic: str, duration: int = 60):
        """Monitorear un tópico específico"""
        consumer = Consumer(self.consumer_config)
        consumer.subscribe([topic])
        
        start_time = time.time()
        message_count = 0
        total_size = 0
        error_count = 0
        
        self.logger.info(f"🔍 Starting monitoring for topic: {topic}")
        
        try:
            while time.time() - start_time < duration and self.running:
                msg = consumer.poll(1.0)
                
                if msg is None:
                    continue
                
                if msg.error():
                    error_count += 1
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        continue
                    else:
                        self.logger.error(f"Consumer error: {msg.error()}")
                        continue
                
                message_count += 1
                if msg.value():
                    total_size += len(msg.value())
                
                # Log cada 10 mensajes
                if message_count % 10 == 0:
                    elapsed = time.time() - start_time
                    throughput = message_count / elapsed if elapsed > 0 else 0
                    self.logger.info(f"📊 {topic}: {message_count} messages, {throughput:.2f} msg/sec")
        
        finally:
            consumer.close()
        
        # Calcular métricas finales
        elapsed_time = time.time() - start_time
        avg_size = total_size // message_count if message_count > 0 else 0
        throughput = message_count / elapsed_time if elapsed_time > 0 else 0
        
        metrics = PipelineMetrics(
            timestamp=datetime.now(),
            topic=topic,
            message_count=message_count,
            avg_message_size=avg_size,
            lag=0,  # TODO: Implementar cálculo de lag
            throughput_per_sec=throughput,
            error_count=error_count
        )
        
        self.metrics.append(metrics)
        return metrics
    
    def check_data_quality_alerts(self, topic: str = 'crypto-prices'):
        """Verificar alertas de calidad de datos"""
        consumer = Consumer(self.consumer_config)
        consumer.subscribe([topic])
        
        alerts = []
        
        try:
            for _ in range(5):  # Revisar últimos 5 mensajes
                msg = consumer.poll(2.0)
                
                if msg is None or msg.error():
                    continue
                
                try:
                    data = json.loads(msg.value().decode('utf-8'))
                    
                    # Alert 1: Precio de Bitcoin muy bajo/alto
                    if 'bitcoin' in data and 'usd' in data['bitcoin']:
                        btc_price = data['bitcoin']['usd']
                        if btc_price < 20000 or btc_price > 150000:
                            alerts.append({
                                'type': 'PRICE_ANOMALY',
                                'message': f'Bitcoin price anomaly: ${btc_price}',
                                'severity': 'HIGH',
                                'timestamp': datetime.now().isoformat()
                            })
                    
                    # Alert 2: Datos muy antiguos
                    current_time = int(time.time())
                    for crypto, crypto_data in data.items():
                        if isinstance(crypto_data, dict) and 'last_updated_at' in crypto_data:
                            age_minutes = (current_time - crypto_data['last_updated_at']) / 60
                            if age_minutes > 10:
                                alerts.append({
                                    'type': 'STALE_DATA',
                                    'message': f'Stale data for {crypto}: {age_minutes:.1f} minutes old',
                                    'severity': 'MEDIUM',
                                    'timestamp': datetime.now().isoformat()
                                })
                
                except json.JSONDecodeError:
                    alerts.append({
                        'type': 'PARSE_ERROR',
                        'message': 'Failed to parse message JSON',
                        'severity': 'HIGH',
                        'timestamp': datetime.now().isoformat()
                    })
        
        finally:
            consumer.close()
        
        return alerts
    
    def start_monitoring(self, topics: List[str] = None, duration: int = 300):
        """Iniciar monitoreo continuo"""
        if topics is None:
            topics = ['crypto-prices', 'crypto-prices-exploded']
        
        self.running = True
        self.logger.info(f"🚀 Starting pipeline monitoring for {duration} seconds")
        
        # Monitorear cada tópico en threads separados
        threads = []
        for topic in topics:
            thread = threading.Thread(target=self.monitor_topic, args=(topic, duration))
            threads.append(thread)
            thread.start()
        
        # Thread para alertas
        alert_thread = threading.Thread(target=self._alert_loop, args=(duration,))
        threads.append(alert_thread)
        alert_thread.start()
        
        # Esperar a que terminen todos los threads
        for thread in threads:
            thread.join()
        
        self.running = False
        self.logger.info("✅ Monitoring completed")
    
    def _alert_loop(self, duration: int):
        """Loop de verificación de alertas"""
        start_time = time.time()
        
        while time.time() - start_time < duration and self.running:
            alerts = self.check_data_quality_alerts()
            
            for alert in alerts:
                severity_emoji = "🚨" if alert['severity'] == 'HIGH' else "⚠️"
                self.logger.warning(f"{severity_emoji} ALERT: {alert['message']}")
            
            time.sleep(30)  # Verificar cada 30 segundos
    
    def generate_report(self) -> Dict:
        """Generar reporte de monitoreo"""
        if not self.metrics:
            return {"error": "No metrics available"}
        
        report = {
            "timestamp": datetime.now().isoformat(),
            "summary": {
                "total_topics_monitored": len(set(m.topic for m in self.metrics)),
                "total_messages": sum(m.message_count for m in self.metrics),
                "avg_throughput": sum(m.throughput_per_sec for m in self.metrics) / len(self.metrics),
                "total_errors": sum(m.error_count for m in self.metrics)
            },
            "topic_metrics": [asdict(m) for m in self.metrics]
        }
        
        return report
    
    def stop_monitoring(self):
        """Detener monitoreo"""
        self.running = False

if __name__ == "__main__":
    monitor = PipelineMonitor()
    
    try:
        # Monitorear por 5 minutos
        monitor.start_monitoring(duration=300)
        
        # Generar reporte
        report = monitor.generate_report()
        
        print("\n" + "="*50)
        print("📊 PIPELINE MONITORING REPORT")
        print("="*50)
        print(f"📈 Total Messages: {report['summary']['total_messages']}")
        print(f"⚡ Avg Throughput: {report['summary']['avg_throughput']:.2f} msg/sec")
        print(f"❌ Total Errors: {report['summary']['total_errors']}")
        
        # Guardar reporte
        with open('pipeline-monitoring-report.json', 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        print(f"\n📄 Report saved to: pipeline-monitoring-report.json")
        
    except KeyboardInterrupt:
        print("\n🛑 Monitoring stopped by user")
        monitor.stop_monitoring()