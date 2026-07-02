#!/bin/bash

# Script principal para gestión de instancias EC2
# Autor: Facundo Facio
# Fecha: $(date +%Y-%m-%d)

# Directorio del script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
. "$DIR/common.sh"

# Colores para output
PURPLE='\033[0;35m'
CYAN='\033[0;36m'

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                 AWS EC2 Instance Manager                     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Uso:${NC} $0 <comando> [argumentos]"
    echo ""
    echo -e "${YELLOW}COMANDOS PRINCIPALES:${NC}"
    echo -e "  ${GREEN}start${NC} <instance_name>        - Iniciar instancia EC2 y actualizar SSH"
    echo -e "  ${RED}stop${NC} <instance_name>         - Detener instancia EC2"
    echo -e "  ${PURPLE}status${NC} <instance_name>       - Ver estado de la instancia"
    echo -e "  ${CYAN}connect${NC} <instance_name>       - Conectar por SSH a la instancia"
    echo ""
    echo -e "${YELLOW}GESTIÓN DE CONFIGURACIONES:${NC}"
    echo -e "  ${BLUE}config list${NC}                  - Listar todas las configuraciones"
    echo -e "  ${BLUE}config add${NC} <params>           - Agregar nueva configuración"
    echo -e "  ${BLUE}config remove${NC} <name>          - Eliminar configuración"
    echo -e "  ${BLUE}config show${NC} <name>            - Mostrar detalles de una configuración"
    echo -e "  ${BLUE}config edit${NC}                   - Editar archivo de configuración"
    echo ""
    echo -e "${YELLOW}AWS SSO:${NC}"
    echo -e "  ${BLUE}sso setup${NC}                    - Sembrar perfiles SSO en ~/.aws/config"
    echo -e "  ${BLUE}login${NC} [instance_name]        - Login SSO manual (refresco de sesión)"
    echo ""
    echo -e "${YELLOW}UTILIDADES:${NC}"
    echo -e "  ${CYAN}list${NC}                         - Listar configuraciones (alias de 'config list')"
    echo -e "  ${CYAN}restart${NC} <instance_name>       - Reiniciar instancia (stop + start)"
    echo -e "  ${CYAN}info${NC} <instance_name>         - Información completa de la instancia"
    echo -e "  ${CYAN}help${NC}                         - Mostrar esta ayuda"
    echo ""
    echo -e "${YELLOW}EJEMPLOS:${NC}"
    echo -e "  $0 start DEVELOPMENT"
    echo -e "  $0 stop PRODUCTION"
    echo -e "  $0 config add STAGING i-123456789 legacy-static us-west-2 staging-server ~/.ssh/key.pem"
    echo -e "  $0 restart DEVELOPMENT"
    echo -e "  $0 connect DEVELOPMENT"
}

# Función para mostrar configuraciones disponibles
show_available_configs() {
    local config_file
    config_file="$(resolve_config_file)"
    if [ -f "$config_file" ]; then
        echo -e "${YELLOW}Configuraciones disponibles:${NC}"
        grep "^[A-Za-z0-9_-][A-Za-z0-9_-]*=" "$config_file" | cut -d'=' -f1 | sed 's/^/  /' | head -10
        local total
        total=$(grep -c "^[A-Za-z0-9_-][A-Za-z0-9_-]*=" "$config_file")
        if [ "$total" -gt 10 ]; then
            echo "  ... y $((total - 10)) más"
        fi
    else
        echo -e "${RED}❌ No hay configuraciones disponibles. Usa 'config add' para crear una.${NC}"
    fi
}

# Función para verificar dependencias
check_dependencies() {
    local missing_deps=()
    
    if ! command -v aws >/dev/null 2>&1; then
        missing_deps+=("aws-cli")
    fi
    
    if ! command -v ssh >/dev/null 2>&1; then
        missing_deps+=("ssh")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}❌ Dependencias faltantes:${NC}"
        printf '%s\n' "${missing_deps[@]}" | sed 's/^/  /'
        echo ""
        echo -e "${YELLOW}Por favor instala las dependencias faltantes.${NC}"
        exit 1
    fi
}

# Función para verificar si existe la configuración
check_config_exists() {
    local instance_name="$1"
    local config_file
    config_file="$(resolve_config_file)"

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ Archivo de configuración no encontrado.${NC}"
        echo -e "${YELLOW}Usa 'config edit' para crear el archivo de configuración.${NC}"
        return 1
    fi
    
    if ! grep -q "^$instance_name=" "$config_file"; then
        echo -e "${RED}❌ Configuración '$instance_name' no encontrada.${NC}"
        echo ""
        show_available_configs
        return 1
    fi
    
    return 0
}

# Función para obtener estado de instancia
get_instance_status() {
    local instance_name="$1"
    
    if ! check_config_exists "$instance_name"; then
        return 1
    fi
    
    # Usar el script de configuración para obtener los datos
    local config_line
    config_line=$(grep "^$instance_name=" "$(resolve_config_file)" | head -1)
    local config_value
    config_value=$(echo "$config_line" | cut -d'=' -f2-)
    local instance_id
    instance_id=$(echo "$config_value" | cut -d':' -f1)
    local aws_profile
    aws_profile=$(echo "$config_value" | cut -d':' -f2)
    local aws_region
    aws_region=$(echo "$config_value" | cut -d':' -f3)

    ensure_aws_session "$aws_profile" || return 1

    echo -e "${BLUE}🔍 Consultando estado de la instancia...${NC}"

    local status
    status=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --region "$aws_region" \
        --profile "$aws_profile" \
        --query "Reservations[0].Instances[0].State.Name" \
        --output text 2>/dev/null)
    
    if [ -z "$status" ] || [ "$status" = "None" ]; then
        echo -e "${RED}❌ No se pudo obtener el estado de la instancia${NC}"
        return 1
    fi
    
    case "$status" in
        "running")
            echo -e "${GREEN}✅ Instancia está ejecutándose${NC}"
            ;;
        "stopped")
            echo -e "${YELLOW}⏹  Instancia está detenida${NC}"
            ;;
        "stopping")
            echo -e "${YELLOW}⏸  Instancia se está deteniendo...${NC}"
            ;;
        "starting")
            echo -e "${BLUE}🔄 Instancia se está iniciando...${NC}"
            ;;
        "pending")
            echo -e "${BLUE}⏳ Instancia está pendiente...${NC}"
            ;;
        *)
            echo -e "${PURPLE}❓ Estado: $status${NC}"
            ;;
    esac
    
    return 0
}

# Función para mostrar información completa
show_instance_info() {
    local instance_name="$1"
    
    if ! check_config_exists "$instance_name"; then
        return 1
    fi
    
    echo -e "${BLUE}📋 Información de la instancia '$instance_name':${NC}"
    echo ""
    
    # Mostrar configuración
    "$DIR/manage_config.sh" show "$instance_name"
    echo ""
    
    # Mostrar estado
    get_instance_status "$instance_name"
}

# Función para conectar por SSH
connect_ssh() {
    local instance_name="$1"
    
    if ! check_config_exists "$instance_name"; then
        return 1
    fi
    
    # Obtener alias SSH de la configuración
    local config_line
    config_line=$(grep "^$instance_name=" "$(resolve_config_file)" | head -1)
    local config_value
    config_value=$(echo "$config_line" | cut -d'=' -f2-)
    local ssh_alias
    ssh_alias=$(echo "$config_value" | cut -d':' -f4)
    
    echo -e "${BLUE}🔗 Conectando a $ssh_alias...${NC}"
    
    # Verificar si el host está en la configuración SSH
    if ! grep -q "Host $ssh_alias" "$HOME/.ssh/config" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Host no encontrado en ~/.ssh/config${NC}"
        echo -e "${BLUE}Actualizando configuración SSH...${NC}"
        "$DIR/update_aws_ssh.sh" "$instance_name"
    fi
    
    ssh "$ssh_alias"
}

# Función para reiniciar instancia
restart_instance() {
    local instance_name="$1"
    
    echo -e "${YELLOW}🔄 Reiniciando instancia '$instance_name'...${NC}"
    echo ""
    
    # Detener
    echo -e "${RED}⏹  Paso 1/2: Deteniendo instancia...${NC}"
    if "$DIR/stop_vm.sh" "$instance_name"; then
        echo ""
        echo -e "${GREEN}⏳ Esperando 5 segundos antes de iniciar...${NC}"
        sleep 5
        echo ""
        
        # Iniciar
        echo -e "${GREEN}🚀 Paso 2/2: Iniciando instancia...${NC}"
        "$DIR/start_vm.sh" "$instance_name"
    else
        echo -e "${RED}❌ Error al detener la instancia${NC}"
        return 1
    fi
}

# Bootstrap: siembra los perfiles SSO en ~/.aws/config desde ~/.ec2-cli/sso.config
sso_setup() {
    local sso_src="$HOME/.ec2-cli/sso.config"
    local aws_config="$HOME/.aws/config"

    if [ ! -f "$sso_src" ]; then
        echo -e "${RED}❌ No se encontró $sso_src${NC}"
        echo -e "${YELLOW}Copiá $DIR/sso.config.example a $sso_src, completá los valores de la org y volvé a correr 'ec2 sso setup'.${NC}"
        return 1
    fi

    mkdir -p "$HOME/.aws"
    touch "$aws_config"
    cp "$aws_config" "$aws_config.bak"
    echo -e "${BLUE}🗄  Backup de ~/.aws/config en ~/.aws/config.bak${NC}"

    merge_sso_config "$sso_src" "$aws_config"
    echo -e "${GREEN}✅ Perfiles SSO sembrados en ~/.aws/config${NC}"
}

# Login SSO manual. Con nombre de instancia usa su perfil; sin nombre, la sso-session default.
sso_login() {
    local instance_name="$1"
    if [ -n "$instance_name" ]; then
        load_config "$instance_name" || return 1
        if ! is_sso_profile "$AWS_PROFILE"; then
            echo -e "${YELLOW}⚠️  El perfil '$AWS_PROFILE' no es SSO; no hay login que hacer.${NC}"
            return 0
        fi
        aws sso login --profile "$AWS_PROFILE"
    else
        aws sso login --sso-session default
    fi
}

# Verificar dependencias al inicio
check_dependencies

# Procesamiento de comandos
case "$1" in
    "start")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ Error: Falta el nombre de la instancia${NC}"
            echo -e "${YELLOW}Uso: $0 start <instance_name>${NC}"
            echo ""
            show_available_configs
            exit 1
        fi
        "$DIR/start_vm.sh" "$2"
        ;;
    
    "stop")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ Error: Falta el nombre de la instancia${NC}"
            echo -e "${YELLOW}Uso: $0 stop <instance_name>${NC}"
            echo ""
            show_available_configs
            exit 1
        fi
        "$DIR/stop_vm.sh" "$2"
        ;;
    
    "restart")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ Error: Falta el nombre de la instancia${NC}"
            echo -e "${YELLOW}Uso: $0 restart <instance_name>${NC}"
            echo ""
            show_available_configs
            exit 1
        fi
        restart_instance "$2"
        ;;
    
    "status")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ Error: Falta el nombre de la instancia${NC}"
            echo -e "${YELLOW}Uso: $0 status <instance_name>${NC}"
            echo ""
            show_available_configs
            exit 1
        fi
        get_instance_status "$2"
        ;;
    
    "info")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ Error: Falta el nombre de la instancia${NC}"
            echo -e "${YELLOW}Uso: $0 info <instance_name>${NC}"
            echo ""
            show_available_configs
            exit 1
        fi
        show_instance_info "$2"
        ;;
    
    "connect"|"ssh")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ Error: Falta el nombre de la instancia${NC}"
            echo -e "${YELLOW}Uso: $0 connect <instance_name>${NC}"
            echo ""
            show_available_configs
            exit 1
        fi
        connect_ssh "$2"
        ;;
    
    "sso")
        case "$2" in
            "setup") sso_setup ;;
            *) echo -e "${RED}❌ Subcomando desconocido: sso $2${NC}"; echo "Uso: $0 sso setup" ;;
        esac
        ;;

    "login")
        sso_login "$2"
        ;;

    "config")
        shift
        "$DIR/manage_config.sh" "$@"
        ;;
    
    "list"|"ls")
        "$DIR/manage_config.sh" list
        ;;
    
    "help"|"-h"|"--help")
        show_help
        ;;
    
    "")
        echo -e "${YELLOW}⚠️  No se especificó ningún comando${NC}"
        echo ""
        show_help
        ;;
    
    *)
        echo -e "${RED}❌ Comando desconocido: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
