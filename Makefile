# EC2 CLI Simple Installer

install:
	@echo "Installing EC2 CLI..."
	@sudo tee /usr/local/bin/ec2 > /dev/null << 'EOF'
#!/bin/bash
exec "$(shell pwd)/ec2.sh" "$$@"
EOF
	@sudo chmod +x /usr/local/bin/ec2
	@echo 'alias ec2="$(shell pwd)/ec2.sh"' >> ~/.zshrc 2>/dev/null || true
	@echo 'fpath=($(shell pwd) $$fpath)' >> ~/.zshrc 2>/dev/null || true
	@echo 'autoload -Uz compinit && compinit' >> ~/.zshrc 2>/dev/null || true
	@echo 'alias ec2="$(shell pwd)/ec2.sh"' >> ~/.bashrc 2>/dev/null || true
	@echo 'source $(shell pwd)/_ec2.sh' >> ~/.bashrc 2>/dev/null || true
	@mkdir -p ~/.ec2-cli
	@[ ! -f ~/.ec2-cli/config.ini ] && [ -f config.ini ] && cp config.ini ~/.ec2-cli/ || true
	@echo "✅ EC2 CLI installed. Reload: source ~/.zshrc || source ~/.bashrc"

.PHONY: install