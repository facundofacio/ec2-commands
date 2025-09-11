#!/bin/bash

# Directorio del script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$DIR/config.ini"

# Función para mostrar ayuda
show_help() {
    echo "Gestor de configuraciones de instancias EC2"
    echo ""
    echo "Uso: $0 <comando> [argumentos]"
    echo ""
    echo "Comandos:"
    echo "  list                     - Listar todas las configuraciones"
    echo "  add <name> <params>      - Agregar nueva configuración"
    echo "  remove <name>            - Eliminar configuración"
    echo "  show <name>              - Mostrar detalles de una configuración"
    echo "  edit                     - Abrir archivo de configuración en editor"
    echo ""
    echo "Parámetros para 'add':"
    echo "  <name> <instance_id> <profile> <region> <ssh_alias> <pem_file>"
    echo ""
    echo "Ejemplo:"
    echo "  $0 add DEVELOPMENT i-1234567890abcdef0 sof us-east-1 dev-server ~/.ssh/my-key.pem"
}

# Función para listar configuraciones
list_configs() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Archivo de configuración no encontrado: $CONFIG_FILE"
        return 1
    fi
    
    echo "📋 Configuraciones disponibles:"
    echo ""
    
    # Encabezados
    printf "%-15s %-20s %-12s %-12s %-15s %s\n" "NOMBRE" "INSTANCE_ID" "PROFILE" "REGION" "SSH_ALIAS" "PEM_FILE"
    printf "%-15s %-20s %-12s %-12s %-15s %s\n" "$(printf '%*s' 15 '' | tr ' ' '-')" "$(printf '%*s' 20 '' | tr ' ' '-')" "$(printf '%*s' 12 '' | tr ' ' '-')" "$(printf '%*s' 12 '' | tr ' ' '-')" "$(printf '%*s' 15 '' | tr ' ' '-')" "$(printf '%*s' 20 '' | tr ' ' '-')"
    
    # Datos
    grep "^[A-Za-z0-9_-][A-Za-z0-9_-]*=" "$CONFIG_FILE" | while IFS='=' read -r name config; do
        if [[ ! "$name" =~ ^# ]]; then
            instance_id=$(echo "$config" | cut -d':' -f1)
            profile=$(echo "$config" | cut -d':' -f2)
            region=$(echo "$config" | cut -d':' -f3)
            ssh_alias=$(echo "$config" | cut -d':' -f4)
            pem_file=$(echo "$config" | cut -d':' -f5)
            
            printf "%-15s %-20s %-12s %-12s %-15s %s\n" "$name" "$instance_id" "$profile" "$region" "$ssh_alias" "$pem_file"
        fi
    done
}

# Función para agregar configuración
add_config() {
    if [ "$#" -ne 6 ]; then
        echo "❌ Error: Faltan parámetros"
        echo "Uso: $0 add <name> <instance_id> <profile> <region> <ssh_alias> <pem_file>"
        return 1
    fi
    
    local name="$1"
    local instance_id="$2"
    local profile="$3"
    local region="$4"
    local ssh_alias="$5"
    local pem_file="$6"
    
    # Crear archivo si no existe
    touch "$CONFIG_FILE"
    
    # Verificar si ya existe
    if grep -q "^$name=" "$CONFIG_FILE"; then
        echo "❌ Error: La configuración '$name' ya existe"
        return 1
    fi
    
    # Agregar configuración
    echo "$name=$instance_id:$profile:$region:$ssh_alias:$pem_file" >> "$CONFIG_FILE"
    echo "✅ Configuración '$name' agregada correctamente"
}

# Función para eliminar configuración
remove_config() {
    if [ "$#" -ne 1 ]; then
        echo "❌ Error: Falta el nombre de la configuración"
        echo "Uso: $0 remove <name>"
        return 1
    fi
    
    local name="$1"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Archivo de configuración no encontrado: $CONFIG_FILE"
        return 1
    fi
    
    # Verificar si existe
    if ! grep -q "^$name=" "$CONFIG_FILE"; then
        echo "❌ Error: La configuración '$name' no existe"
        return 1
    fi
    
    # Crear backup y eliminar
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    grep -v "^$name=" "$CONFIG_FILE.bak" > "$CONFIG_FILE"
    echo "✅ Configuración '$name' eliminada correctamente"
}

# Función para mostrar configuración específica
show_config() {
    if [ "$#" -ne 1 ]; then
        echo "❌ Error: Falta el nombre de la configuración"
        echo "Uso: $0 show <name>"
        return 1
    fi
    
    local name="$1"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Archivo de configuración no encontrado: $CONFIG_FILE"
        return 1
    fi
    
    # Buscar configuración
    local config_line=$(grep "^$name=" "$CONFIG_FILE" | head -1)
    
    if [ -z "$config_line" ]; then
        echo "❌ Error: Configuración '$name' no encontrada"
        return 1
    fi
    
    # Extraer y mostrar valores
    local config_value=$(echo "$config_line" | cut -d'=' -f2-)
    local instance_id=$(echo "$config_value" | cut -d':' -f1)
    local profile=$(echo "$config_value" | cut -d':' -f2)
    local region=$(echo "$config_value" | cut -d':' -f3)
    local ssh_alias=$(echo "$config_value" | cut -d':' -f4)
    local pem_file=$(echo "$config_value" | cut -d':' -f5)
    
    echo "📋 Configuración '$name':"
    echo "  Instance ID: $instance_id"
    echo "  AWS Profile: $profile"
    echo "  AWS Region: $region"
    echo "  SSH Alias: $ssh_alias"
    echo "  PEM File: $pem_file"
}

# Función para editar configuración
edit_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "📝 Creando archivo de configuración: $CONFIG_FILE"
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración de instancias EC2
# Formato: INSTANCE_NAME=instance_id:profile:region:ssh_host_alias:pem_file

# Ejemplo:
# DEVELOPMENT=i-1234567890abcdef0:sof:us-east-1:dev-server:~/.ssh/my-key.pem
# PRODUCTION=i-abcdef1234567890:prod:eu-west-1:prod-server:~/.ssh/prod-key.pem

EOF
    fi
    
    # Detectar editor disponible
    if command -v code >/dev/null 2>&1; then
        code "$CONFIG_FILE"
    elif command -v nano >/dev/null 2>&1; then
        nano "$CONFIG_FILE"
    elif command -v vim >/dev/null 2>&1; then
        vim "$CONFIG_FILE"
    else
        echo "📝 Por favor, edita el archivo: $CONFIG_FILE"
    fi
}

# Procesamiento de comandos
case "$1" in
    "list"|"ls")
        list_configs
        ;;
    "add")
        shift
        add_config "$@"
        ;;
    "remove"|"rm")
        shift
        remove_config "$@"
        ;;
    "show")
        shift
        show_config "$@"
        ;;
    "edit")
        edit_config
        ;;
    "help"|"-h"|"--help"|"")
        show_help
        ;;
    *)
        echo "❌ Comando desconocido: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
