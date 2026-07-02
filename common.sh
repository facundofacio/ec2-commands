#!/bin/bash
# Librería compartida para ec2-commands: resolución de config, parseo,
# y lógica de sesión AWS SSO. Portable macOS (bash 3.2) + Ubuntu.

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Ruta activa de config.ini: ~/.ec2-cli/ tiene prioridad, si no el repo.
resolve_config_file() {
  if [ -f "$HOME/.ec2-cli/config.ini" ]; then
    printf '%s\n' "$HOME/.ec2-cli/config.ini"
  else
    printf '%s\n' "$COMMON_DIR/config.ini"
  fi
}

# Parsea la línea del config.ini y setea las variables globales.
load_config() {
  local instance_name="$1"
  local config_file; config_file="$(resolve_config_file)"

  if [ ! -f "$config_file" ]; then
    printf "${RED}❌ Archivo de configuración no encontrado: %s${NC}\n" "$config_file" >&2
    return 1
  fi

  local config_line; config_line=$(grep "^$instance_name=" "$config_file" | head -1)
  if [ -z "$config_line" ]; then
    printf "${RED}❌ Configuración '%s' no encontrada en %s${NC}\n" "$instance_name" "$config_file" >&2
    grep -E "^[A-Za-z0-9_-][A-Za-z0-9_-]*=" "$config_file" | cut -d'=' -f1 >&2
    return 1
  fi

  local v; v=$(printf '%s' "$config_line" | cut -d'=' -f2-)
  INSTANCE_ID=$(printf '%s' "$v" | cut -d':' -f1)
  AWS_PROFILE=$(printf '%s' "$v" | cut -d':' -f2)
  AWS_REGION=$(printf '%s' "$v" | cut -d':' -f3)
  SSH_HOST_ALIAS=$(printf '%s' "$v" | cut -d':' -f4)
  PEM_FILE=$(printf '%s' "$v" | cut -d':' -f5)
  PEM_FILE="${PEM_FILE/#\~/$HOME}"
  CONFIG_FILE="$config_file"
}
