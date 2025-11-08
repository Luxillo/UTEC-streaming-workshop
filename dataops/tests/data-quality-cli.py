#!/usr/bin/env python3
"""
Data Quality Tests usando Confluent CLI
Alternativa cuando no se puede usar Schema Registry directamente
"""

import json
import subprocess
import time
from datetime import datetime
from typing import Dict, List, Any
from dataclasses import dataclass

@dataclass
class DataQualityResult:
    test_name: str
    passed: bool
    message: str
    timestamp: datetime

class CryptoDataQualityTesterCLI:
    def __init__(self):
        self.results: List[DataQualityResult] = []
    
    def get_messages_from_cli(self, topic: str = 'crypto-prices', max_messages: int = 5) -> List[Dict]:
        """Obtener mensajes usando Confluent CLI"""
        try:
            cmd = [
                'confluent', 'kafka', 'topic', 'consume', topic,
                '--from-beginning',
                f'--max-messages', str(max_messages),
                '--timeout', '30000'
            ]
            
            print(f"🔍 Getting messages from {topic} using CLI...")
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=35)
            
            if result.returncode != 0:
                print(f"❌ CLI error: {result.stderr}")
                return []
            
            messages = []
            for line in result.stdout.strip().split('\n'):
                if line.strip():
                    try:
                        # Intentar parsear como JSON
                        msg_data = json.loads(line)
                        messages.append(msg_data)
                    except json.JSONDecodeError:
                        # Si no es JSON, podría ser el formato de salida del CLI
                        continue
            
            return messages
            
        except subprocess.TimeoutExpired:
            print("⏱️  CLI timeout - no messages received")
            return []
        except Exception as e:
            print(f"❌ Error running CLI: {e}")
            return []
    
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
        max_age_minutes = 10  # Más permisivo para CLI
        
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
    
    def run_tests(self, topic: str = 'crypto-prices') -> List[DataQualityResult]:
        """Ejecutar todos los tests de calidad"""
        messages = self.get_messages_from_cli(topic)
        
        if not messages:
            return []
        
        print(f"📊 Testing {len(messages)} messages...")
        
        for i, message_data in enumerate(messages, 1):
            print(f"📨 Processing message {i}")
            
            # Ejecutar tests
            tests = [
                self.test_message_structure(message_data),
                self.test_data_freshness(message_data),
                self.test_price_validity(message_data)
            ]
            
            self.results.extend(tests)
        
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
    tester = CryptoDataQualityTesterCLI()
    results = tester.run_tests()
    report = tester.generate_report()
    
    print("\n" + "="*50)
    print("📋 DATA QUALITY REPORT (CLI)")
    print("="*50)
    
    if "error" in report:
        print(f"❌ Error: {report['error']}")
        print("💡 Make sure the pipeline is running and CLI is configured")
    else:
        print(f"✅ Passed: {report['summary']['passed']}")
        print(f"❌ Failed: {report['summary']['failed']}")
        print(f"📊 Success Rate: {report['summary']['success_rate']:.1f}%")
        
        if report['summary']['failed'] > 0:
            print("\n❌ FAILED TESTS:")
            for result in report['test_results']:
                if result['status'] == 'FAIL':
                    print(f"   - {result['test']}: {result['message']}")
    
    # Guardar reporte
    with open('data-quality-report-cli.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"\n📄 Report saved to: data-quality-report-cli.json")