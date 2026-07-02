#!/bin/bash

# EC2 CLI Simple Installer
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Crear alias global
sudo tee /usr/local/bin/ec2 > /dev/null << EOF
#!/bin/bash
exec "$SCRIPT_DIR/ec2.sh" "\$@"
EOF
sudo chmod +x /usr/local/bin/ec2

# Autocompletado para zsh
echo "
# EC2 CLI
alias ec2='$SCRIPT_DIR/ec2.sh'
fpath=($SCRIPT_DIR \$fpath)
autoload -Uz compinit && compinit" >> ~/.zshrc 2>/dev/null || true

# Autocompletado para bash  
echo "
# EC2 CLI
alias ec2='$SCRIPT_DIR/ec2.sh'
source $SCRIPT_DIR/_ec2.sh" >> ~/.bashrc 2>/dev/null || true

# Copiar configuración
mkdir -p ~/.ec2-cli
[ ! -f ~/.ec2-cli/config.ini ] && [ -f "$SCRIPT_DIR/config.ini" ] && cp "$SCRIPT_DIR/config.ini" ~/.ec2-cli/

# Ofrecer bootstrap de SSO si hay sso.config
if [ -f "$HOME/.ec2-cli/sso.config" ]; then
  printf "¿Sembrar perfiles SSO en ~/.aws/config ahora? [y/N] "
  read -r ans
  case "$ans" in
    y|Y) "$SCRIPT_DIR/ec2.sh" sso setup ;;
    *) echo "Podés hacerlo luego con: ec2 sso setup" ;;
  esac
else
  echo "ℹ️  Para SSO: copiá sso.config.example a ~/.ec2-cli/sso.config, completalo y corré 'ec2 sso setup'"
fi

echo "✅ EC2 CLI instalado. Recarga tu shell: source ~/.zshrc || source ~/.bashrc"