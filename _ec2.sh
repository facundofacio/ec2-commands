#compdef ec2.sh

# Autocompletado para ec2.sh
_ec2_commands() {
  local -a commands config_subcommands
  commands=(
    'start:Iniciar instancia EC2'
    'stop:Detener instancia EC2'
    'status:Ver estado de la instancia'
    'connect:Conectar por SSH a la instancia'
    'ssh:Alias de connect'
    'restart:Reiniciar instancia (stop + start)'
    'info:Información completa de la instancia'
    'help:Mostrar ayuda'
    'list:Listar configuraciones'
    'ls:Alias de list'
    'config:Gestión de configuraciones'
    'sso:Gestión de AWS SSO'
    'login:Login SSO manual'
  )
  config_subcommands=(
    'list:Listar todas las configuraciones'
    'add:Agregar nueva configuración'
    'remove:Eliminar configuración'
    'show:Mostrar detalles de una configuración'
    'edit:Editar archivo de configuración'
  )
  local -a sso_subcommands
  sso_subcommands=(
    'setup:Sembrar perfiles SSO en ~/.aws/config'
  )

  local config_file="${${(%):-%x}:A:h}/config.ini"
  local -a instance_names
  if [[ -f $config_file ]]; then
    instance_names=($(grep -E '^[A-Za-z0-9_-]+=' "$config_file" | cut -d'=' -f1))
  fi

  if (( CURRENT == 2 )); then
    _describe -t commands 'comandos' commands
  elif (( CURRENT == 3 )); then
    case $words[2] in
      start|stop|status|info|connect|ssh|restart)
        _describe -t instance_names 'instance name' instance_names
        ;;
      config)
        _describe -t config_subcommands 'config subcomandos' config_subcommands
        ;;
      login)
        _describe -t instance_names 'instance name' instance_names
        ;;
      sso)
        _describe -t sso_subcommands 'sso subcomandos' sso_subcommands
        ;;
    esac
  fi
}

compdef _ec2_commands ec2.sh ./ec2.sh
