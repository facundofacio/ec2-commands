#!/bin/bash

# Directorio del script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$DIR/config.ini"

# Función para leer configuración
load_config() {
    local instance_name="$1"
    
    # Verificar si el archivo de configuración existe
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Error: Archivo de configuración no encontrado: $CONFIG_FILE"
        exit 1
    fi
    
    # Buscar la línea de configuración
    local config_line=$(grep "^$instance_name=" "$CONFIG_FILE" | head -1)
    
    if [ -z "$config_line" ]; then
        echo "❌ Error: Configuración '$instance_name' no encontrada en $CONFIG_FILE"
        echo "Configuraciones disponibles:"
        grep "^[A-Za-z0-9_-][A-Za-z0-9_-]*=" "$CONFIG_FILE" | cut -d'=' -f1
        exit 1
    fi
    
    # Extraer valores
    local config_value=$(echo "$config_line" | cut -d'=' -f2-)
    INSTANCE_ID=$(echo "$config_value" | cut -d':' -f1)
    AWS_PROFILE=$(echo "$config_value" | cut -d':' -f2)
    AWS_REGION=$(echo "$config_value" | cut -d':' -f3)
    SSH_HOST_ALIAS=$(echo "$config_value" | cut -d':' -f4)
    PEM_FILE=$(echo "$config_value" | cut -d':' -f5)
    
    # Expandir ruta del archivo PEM si contiene ~
    PEM_FILE="${PEM_FILE/#\~/$HOME}"
}

# Verificar parámetros
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <INSTANCE_NAME>"
    echo ""
    echo "Configuraciones disponibles en $CONFIG_FILE:"
    if [ -f "$CONFIG_FILE" ]; then
        grep "^[A-Za-z0-9_-][A-Za-z0-9_-]*=" "$CONFIG_FILE" | cut -d'=' -f1 | sed 's/^/  /'
    fi
    exit 1
fi

# Cargar configuración
INSTANCE_NAME="$1"
load_config "$INSTANCE_NAME"

echo "📋 Configuración cargada:"
echo "  Instance ID: $INSTANCE_ID"
echo "  AWS Profile: $AWS_PROFILE"
echo "  AWS Region: $AWS_REGION"
echo "  SSH Alias: $SSH_HOST_ALIAS"
echo "  PEM File: $PEM_FILE"
echo ""

# Start the instance
echo "🔄 Starting instance $INSTANCE_ID..."
aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --profile "$AWS_PROFILE" > /dev/null

# Wait until it's running
echo "⏳ Waiting until instance is running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --profile "$AWS_PROFILE"

# Update SSH config
echo "✅ Instance is running. Updating SSH config..."
bash "$DIR/update_aws_ssh.sh" "$INSTANCE_NAME"
