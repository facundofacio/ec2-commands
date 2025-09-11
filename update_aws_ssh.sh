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

# Verificación de parámetros
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

# Configuración
SSH_CONFIG_FILE="$HOME/.ssh/config"

# Obtener IP pública antigua desde el bloque de configuración
OLD_PUBLIC_IP=$(awk -v alias="$SSH_HOST_ALIAS" '
    BEGIN { in_block = 0 }
    /^[Hh]ost[ \t]+/ {
        in_block = ($2 == alias)
        next
    }
    in_block && $1 == "HostName" {
        print $2
        exit
    }
' "$SSH_CONFIG_FILE")

if [ -n "$OLD_PUBLIC_IP" ]; then
    echo "⏹ Eliminando clave antigua para $OLD_PUBLIC_IP de known_hosts..."
    ssh-keygen -R "$OLD_PUBLIC_IP" >/dev/null
fi

# Obtener nueva IP pública desde AWS
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$AWS_REGION" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --profile "$AWS_PROFILE" \
    --output text)

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Error: No se pudo obtener la IP pública de la instancia $INSTANCE_ID"
    exit 1
fi

echo "⏹ Actualizando IP a $PUBLIC_IP para $SSH_HOST_ALIAS en $SSH_CONFIG_FILE"

# Crear archivo si no existe
touch "$SSH_CONFIG_FILE"

# Crear backup
cp "$SSH_CONFIG_FILE" "$SSH_CONFIG_FILE.bak"

# Detectar si el alias existe
if grep -qE "^[Hh]ost[ \t]+$SSH_HOST_ALIAS(\s|$)" "$SSH_CONFIG_FILE.bak"; then
    # Actualizar IP en el bloque existente
    awk -v alias="$SSH_HOST_ALIAS" -v ip="$PUBLIC_IP" '
    BEGIN { in_block = 0 }
    /^[Hh]ost[ \t]+/ {
        in_block = ($2 == alias)
        print
        next
    }
    in_block {
        if ($1 == "HostName") {
            print "HostName " ip
            in_block = 0
            next
        }
        print
        next
    }
    {
        print
    }
    ' "$SSH_CONFIG_FILE.bak" > "$SSH_CONFIG_FILE"
else
    # Agregar nuevo bloque
    echo -e "\nHost $SSH_HOST_ALIAS\n  HostName $PUBLIC_IP\n  User ubuntu\n  IdentityFile $PEM_FILE\n" >> "$SSH_CONFIG_FILE"
    echo "⏹ Se agregó un nuevo bloque para el alias $SSH_HOST_ALIAS"
fi

# Agregar nueva huella al known_hosts
echo "⏹ Escaneando y agregando nueva clave para $PUBLIC_IP a known_hosts..."
ssh-keyscan -H "$PUBLIC_IP" >> ~/.ssh/known_hosts 2>/dev/null

# Verificar si se actualizó correctamente
if grep -A 2 "Host $SSH_HOST_ALIAS" "$SSH_CONFIG_FILE" | grep -q "HostName $PUBLIC_IP"; then
    echo "✅ Configuración actualizada correctamente."
else
    echo "❌ Error al actualizar la configuración."
    exit 1
fi
