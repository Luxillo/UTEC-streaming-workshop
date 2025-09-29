# 🚀 Configuración de GitHub Codespaces para el Taller de Confluent Cloud

Este directorio contiene la configuración del contenedor de desarrollo para ejecutar el Taller de Confluent Cloud en GitHub Codespaces.

## 🏗️ Qué se Incluye

### Entorno Base
- **Ubuntu 22.04** imagen base
- **Zsh** con configuración de Oh My Zsh
- **Node.js 18** para desarrollo web
- **Python 3.11** con paquetes del taller
- **Java 17** con Maven y Gradle

### Herramientas del Taller
- **Confluent CLI** - Última versión para la gestión de Confluent Cloud
- **DuckDB** - Para consultas analíticas en tablas Iceberg
- **Extensiones de VSCode** - Extensión de Confluent Cloud y herramientas de desarrollo

### Paquetes de Python Preinstalados
- `confluent-kafka[avro]` - Cliente de Kafka con soporte para Avro
- `requests` - Cliente HTTP para llamadas a API
- `pandas` - Manipulación de datos
- `duckdb-engine` - Motor SQLAlchemy para DuckDB

## 🎯 Inicio Rápido

1. **Abrir en Codespaces**: Haz clic en el botón "Code" → "Codespaces" → "Create codespace"
2. **Esperar la configuración**: El script de arranque instalará automáticamente todas las dependencias
3. **Validar el entorno**: Ejecuta `workshop-validate`
4. **Iniciar sesión en Confluent**: Ejecuta `workshop-login`
5. **Comenzar el taller**: Sigue las instrucciones de `guides/01-setup-confluent-cloud.adoc`

## 🔧 Comandos del Taller

El contenedor de desarrollo incluye alias y funciones útiles:

### Alias
```bash
cc                 # confluent
ccenv              # confluent environment
cccluster          # confluent kafka cluster
cctopic            # confluent kafka topic
ccconnector        # confluent connect connector
ccflink            # confluent flink
```

### Funciones de Ayuda
```bash
workshop-status    # Comprobar el estado del entorno
workshop-validate  # Ejecutar la validación de prerrequisitos
workshop-login     # Iniciar sesión en Confluent Cloud
```

## 📁 Estructura del Directorio

```
.devcontainer/
├── devcontainer.json    # Configuración principal
├── bootstrap.sh         # Script de configuración
└── README.md           # Este archivo
```

## 🔍 Detalles de Configuración

### Redirección de Puertos
- **8080** - Servidor de aplicaciones
- **3000** - Servidor de desarrollo
- **5000** - Aplicaciones Flask/Python
- **8000** - Servidor web alternativo

### Variables de Entorno
- `WORKSHOP_ENV=codespaces` - Identifica el entorno de Codespaces
- `CONFLUENT_DISABLE_UPDATES=true` - Evita las solicitudes de actualización de la CLI

### Extensiones de VSCode
- Extensión de Confluent Cloud para la gestión de clústeres
- Herramientas de desarrollo de Python (Black, Flake8)
- Paquete de desarrollo de Java
- Soporte para Markdown y JSON

## 🚨 Solución de Problemas

### Problemas de Arranque
Si el script de arranque falla:
```bash
# Volver a ejecutar el arranque manualmente
.devcontainer/bootstrap.sh

# Comprobar los registros
cat /tmp/bootstrap.log
```

### Herramientas Faltantes
Si las herramientas no están disponibles después de la configuración:
```bash
# Recargar la configuración del shell
source ~/.zshrc

# Comprobar el PATH
echo $PATH

# Verificar las instalaciones
confluent version
duckdb --version
```

### Problemas de Permisos
```bash
# Arreglar los permisos de los scripts
find scripts -name "*.sh" -exec chmod +x {} \;

# opcional el permiso directo
chmod +x .devcontainer/bootstrap.sh;

```

## 🔄 Actualizaciones

Para actualizar la configuración del contenedor de desarrollo:
1. Modifica `devcontainer.json` o `bootstrap.sh`
2. Reconstruye el contenedor: Paleta de Comandos → "Codespaces: Rebuild Container"

## 📚 Recursos del Taller

- **Guías**: `/guides/` - Instrucciones paso a paso
- **Scripts**: `/scripts/` - Ayudantes de automatización
- **Datos**: `/data/` - Conjuntos de datos de muestra
- **Configuraciones**: `/configs/` - Plantillas de configuración
- **Solución de problemas**: `/troubleshooting/` - Resolución de problemas (pendiente)

---

**¿Listo para empezar?** ¡Ejecuta `workshop-validate` para asegurarte de que todo funciona! 🎉
