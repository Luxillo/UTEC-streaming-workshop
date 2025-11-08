#!/usr/bin/env python3
"""
DataOps: Data Quality Tests for Crypto Streaming Pipeline
Tests de calidad de datos para validar la integridad del pipeline
"""

import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any
from confluent_kafka import Consumer, KafkaError
import os
from dataclasses import dataclass

@dataclass
class DataQualityResult:
    test_name: str
    passed: bool
    message: str
    timestamp: datetime

class CryptoDataQualityTester:
    def __init__(self):
        self.consumer_config = {
            'bootstrap.servers': os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092'),
            'group.id': 'data-quality-tester',
            'auto.offset.reset': 'latest'
        }
        self.results: List[DataQualityResult] = []
        
    def test_message_structure(self, message: Dict[str, Any]) -> DataQualityResult:
        """Test 1: Validar estructura del mensaje"""
        expected_cryptos = ['bitcoin', 'ethereum', 'binancecoin', 'cardano', 'solana']
        
        for crypto in expected_cryptos:
            if crypto not in message:
                return DataQualityResult(
                    "message_structure", False, 
                    f"Missing crypto: {crypto}", datetime.now()
                )
                
            crypto_data = message[crypto]
            required_fields = ['usd', 'usd_market_cap', 'usd_24h_vol', 'usd_24h_change', 'last_updated_at']
            
            for field in required_fields:
                if field not in crypto_data:
                    return DataQualityResult(
                        "message_structure", False,
                        f"Missing field {field} in {crypto}", datetime.now()
                    )
        
        return DataQualityResult(
            "message_structure", True, 
            "Message structure is valid", datetime.now()
        )
    
    def test_data_freshness(self, message: Dict[str, Any]) -> DataQualityResult:
        """Test 2: Validar frescura de los datos"""
        current_time = int(time.time())
        max_age_minutes = 5
        
        for crypto, data in message.items():
            if isinstance(data, dict) and 'last_updated_at' in data:
                last_updated = data['last_updated_at']
                age_seconds = current_time - last_updated
                age_minutes = age_seconds / 60
                
                if age_minutes > max_age_minutes:
                    return DataQualityResult(
                        "data_freshness", False,
                        f"Data too old for {crypto}: {age_minutes:.1f} minutes", 
                        datetime.now()
                    )
        
        return DataQualityResult(
            "data_freshness", True,
            "Data is fresh", datetime.now()
        )
    
    def test_price_validity(self, message: Dict[str, Any]) -> DataQualityResult:
        """Test 3: Validar rangos de precios"""
        price_ranges = {
            'bitcoin': (1000, 200000),
            'ethereum': (100, 10000),
            'binancecoin': (10, 1000),
            'cardano': (0.1, 10),
            'solana': (1, 500)
        }
        
        for crypto, data in message.items():
            if isinstance(data, dict) and 'usd' in data:
                price = data['usd']
                if crypto in price_ranges:
                    min_price, max_price = price_ranges[crypto]
                    if not (min_price <= price <= max_price):
                        return DataQualityResult(
                            "price_validity", False,
                            f"Price out of range for {crypto}: ${price}", 
                            datetime.now()
                        )
        
        return DataQualityResult(
            "price_validity", True,
            "All prices are within valid ranges", datetime.now()
        )
    
    def test_data_completeness(self, message: Dict[str, Any]) -> DataQualityResult:
        """Test 4: Validar completitud de datos"""
        for crypto, data in message.items():
            if isinstance(data, dict):
                for field, value in data.items():
                    if value is None or (isinstance(value, str) and value.strip() == ""):
                        return DataQualityResult(
                            "data_completeness", False,
                            f"Empty value for {crypto}.{field}", 
                            datetime.now()
                        )
        
        return DataQualityResult(
            "data_completeness", True,
            "All data fields are complete", datetime.now()
        )
    
    def run_tests(self, topic: str = 'crypto-prices', timeout: int = 30) -> List[DataQualityResult]:
        """Ejecutar todos los tests de calidad"""
        consumer = Consumer(self.consumer_config)
        consumer.subscribe([topic])
        
        print(f"🔍 Running data quality tests on topic: {topic}")
        print(f"⏱️  Timeout: {timeout} seconds")
        
        start_time = time.time()
        messages_tested = 0
        
        try:
            while time.time() - start_time < timeout:
                msg = consumer.poll(1.0)
                
                if msg is None:
                    continue
                    
                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        continue
                    else:
                        print(f"❌ Consumer error: {msg.error()}")
                        break
                
                try:
                    message_data = json.loads(msg.value().decode('utf-8'))
                    messages_tested += 1
                    
                    # Ejecutar tests
                    tests = [
                        self.test_message_structure(message_data),
                        self.test_data_freshness(message_data),
                        self.test_price_validity(message_data),
                        self.test_data_completeness(message_data)
                    ]
                    
                    self.results.extend(tests)
                    
                    print(f"✅ Tested message {messages_tested}")
                    
                except json.JSONDecodeError as e:
                    self.results.append(DataQualityResult(
                        "json_parsing", False,
                        f"JSON parsing error: {e}", datetime.now()
                    ))
                
        finally:
            consumer.close()
        
        print(f"📊 Total messages tested: {messages_tested}")
        return self.results
    
    def generate_report(self) -> Dict[str, Any]:
        """Generar reporte de calidad de datos"""
        if not self.results:
            return {"error": "No test results available"}
        
        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results if r.passed)
        failed_tests = total_tests - passed_tests
        
        report = {
            "timestamp": datetime.now().isoformat(),
            "summary": {
                "total_tests": total_tests,
                "passed": passed_tests,
                "failed": failed_tests,
                "success_rate": (passed_tests / total_tests) * 100 if total_tests > 0 else 0
            },
            "test_results": [
                {
                    "test": r.test_name,
                    "status": "PASS" if r.passed else "FAIL",
                    "message": r.message,
                    "timestamp": r.timestamp.isoformat()
                }
                for r in self.results
            ]
        }
        
        return report

if __name__ == "__main__":
    tester = CryptoDataQualityTester()
    results = tester.run_tests()
    report = tester.generate_report()
    
    print("\n" + "="*50)
    print("📋 DATA QUALITY REPORT")
    print("="*50)
    print(f"✅ Passed: {report['summary']['passed']}")
    print(f"❌ Failed: {report['summary']['failed']}")
    print(f"📊 Success Rate: {report['summary']['success_rate']:.1f}%")
    
    if report['summary']['failed'] > 0:
        print("\n❌ FAILED TESTS:")
        for result in report['test_results']:
            if result['status'] == 'FAIL':
                print(f"   - {result['test']}: {result['message']}")
    
    # Guardar reporte
    with open('data-quality-report.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"\n📄 Report saved to: data-quality-report.json")