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

echo "✅ EC2 CLI instalado. Recarga tu shell: source ~/.zshrc || source ~/.bashrc"