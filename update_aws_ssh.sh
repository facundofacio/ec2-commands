#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/common.sh"

if [ "$#" -ne 1 ]; then
  echo "Uso: $0 <INSTANCE_NAME>"
  exit 1
fi

INSTANCE_NAME="$1"
load_config "$INSTANCE_NAME" || exit 1
ensure_aws_session "$AWS_PROFILE" || exit 1

SSH_CONFIG_FILE="$HOME/.ssh/config"

OLD_PUBLIC_IP=$(awk -v alias="$SSH_HOST_ALIAS" '
    BEGIN { in_block = 0 }
    /^[Hh]ost[ \t]+/ { in_block = ($2 == alias); next }
    in_block && $1 == "HostName" { print $2; exit }
' "$SSH_CONFIG_FILE" 2>/dev/null)

if [ -n "$OLD_PUBLIC_IP" ]; then
    echo "⏹ Eliminando clave antigua para $OLD_PUBLIC_IP de known_hosts..."
    ssh-keygen -R "$OLD_PUBLIC_IP" >/dev/null
fi

PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$AWS_REGION" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --profile "$AWS_PROFILE" \
    --output text)

if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "None" ]; then
    echo "❌ Error: No se pudo obtener la IP pública de la instancia $INSTANCE_ID"
    exit 1
fi

echo "⏹ Actualizando IP a $PUBLIC_IP para $SSH_HOST_ALIAS en $SSH_CONFIG_FILE"

touch "$SSH_CONFIG_FILE"
cp "$SSH_CONFIG_FILE" "$SSH_CONFIG_FILE.bak"

if grep -qE "^[Hh]ost[ \t]+$SSH_HOST_ALIAS(\s|$)" "$SSH_CONFIG_FILE.bak"; then
    awk -v alias="$SSH_HOST_ALIAS" -v ip="$PUBLIC_IP" '
    BEGIN { in_block = 0 }
    /^[Hh]ost[ \t]+/ { in_block = ($2 == alias); print; next }
    in_block {
        if ($1 == "HostName") { print "HostName " ip; in_block = 0; next }
        print; next
    }
    { print }
    ' "$SSH_CONFIG_FILE.bak" > "$SSH_CONFIG_FILE"
else
    printf '\nHost %s\n  HostName %s\n  User ubuntu\n  IdentityFile %s\n\n' "$SSH_HOST_ALIAS" "$PUBLIC_IP" "$PEM_FILE" >> "$SSH_CONFIG_FILE"
    echo "⏹ Se agregó un nuevo bloque para el alias $SSH_HOST_ALIAS"
fi

echo "⏹ Escaneando y agregando nueva clave para $PUBLIC_IP a known_hosts..."
ssh-keyscan -H "$PUBLIC_IP" >> ~/.ssh/known_hosts 2>/dev/null

if grep -A 2 "Host $SSH_HOST_ALIAS" "$SSH_CONFIG_FILE" | grep -q "HostName $PUBLIC_IP"; then
    echo "✅ Configuración actualizada correctamente."
else
    echo "❌ Error al actualizar la configuración."
    exit 1
fi
