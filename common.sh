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

# Retorna 0 si el perfil tiene sso_session configurado (perfil SSO).
is_sso_profile() {
  local profile="$1" s
  s=$(aws configure get sso_session --profile "$profile" 2>/dev/null)
  [ -n "$s" ]
}

# Garantiza una sesión válida para el perfil. Login SSO automático si expiró.
# No hace nada para perfiles estáticos.
ensure_aws_session() {
  local profile="$1"

  if ! is_sso_profile "$profile"; then
    return 0
  fi

  if aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
    return 0
  fi

  printf "${YELLOW}⏳ Sesión SSO expirada para %s. Iniciando login...${NC}\n" "$profile"
  if ! aws sso login --profile "$profile"; then
    printf "${RED}❌ El login SSO falló para %s${NC}\n" "$profile" >&2
    return 1
  fi

  if aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
    return 0
  fi

  printf "${RED}❌ La sesión sigue inválida tras el login${NC}\n" >&2
  return 1
}

# Appendea a <dest> cada bloque [..] de <src> cuyo header no exista ya en <dest>.
# Idempotente: correrlo dos veces no duplica ni pisa perfiles existentes.
merge_sso_config() {
  local src="$1" dest="$2" line add=0
  [ -f "$src" ] || return 1
  touch "$dest"
  while IFS= read -r line || [ -n "$line" ]; do
    if printf '%s' "$line" | grep -qE '^\[.*\]$'; then
      if grep -qxF "$line" "$dest"; then
        add=0
      else
        add=1
        printf '\n' >> "$dest"
      fi
    fi
    [ "$add" -eq 1 ] && printf '%s\n' "$line" >> "$dest"
  done < "$src"
}
