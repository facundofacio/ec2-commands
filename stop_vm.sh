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

echo "📋 Configuración cargada:"
echo "  Instance ID: $INSTANCE_ID"
echo "  AWS Profile: $AWS_PROFILE"
echo "  AWS Region: $AWS_REGION"
echo ""

echo "⏹ Stopping instance $INSTANCE_ID..."
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --profile "$AWS_PROFILE" --no-cli-pager

aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --profile "$AWS_PROFILE"
echo "✅ Instance stopped."
