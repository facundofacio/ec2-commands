# AWS EC2 Instance Manager

[![CI](https://github.com/facundofacio/ec2-commands/actions/workflows/ci.yml/badge.svg)](https://github.com/facundofacio/ec2-commands/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/facundofacio/ec2-commands/badge)](https://securityscorecards.dev/viewer/?uri=github.com/facundofacio/ec2-commands)

Sistema de scripts para gestionar instancias EC2 de AWS de manera simplificada usando configuraciones predefinidas.

## Archivos del Sistema

- `ec2.sh` - Script principal que engloba todas las funcionalidades
- `start_vm.sh` - Inicia una instancia EC2 y actualiza la configuración SSH
- `stop_vm.sh` - Detiene una instancia EC2
- `update_aws_ssh.sh` - Actualiza la configuración SSH con la nueva IP de la instancia
- `manage_config.sh` - Gestiona las configuraciones de instancias
- `config.ini` - Archivo de configuración donde se almacenan los datos de las instancias

## Formato del Archivo de Configuración

El archivo `config.ini` usa el siguiente formato:

```ini
NOMBRE_CONFIGURACION=instance_id:perfil_aws:region:alias_ssh:archivo_pem
```

### Ejemplo:

```ini
DEVELOPMENT=i-0123456789abcdef0:legacy-static:us-east-1:dev-server:~/.ssh/my-key.pem
PRODUCTION=i-abcdef1234567890:prod:eu-west-1:prod-server:~/.ssh/prod-key.pem
```

## Uso del Script Principal

### Comandos Principales

```bash
# Iniciar una instancia
./ec2.sh start NOMBRE_CONFIGURACION

# Detener una instancia
./ec2.sh stop NOMBRE_CONFIGURACION

# Reiniciar una instancia (stop + start)
./ec2.sh restart NOMBRE_CONFIGURACION

# Ver estado de la instancia
./ec2.sh status NOMBRE_CONFIGURACION

# Conectar por SSH
./ec2.sh connect NOMBRE_CONFIGURACION

# Información completa de la instancia
./ec2.sh info NOMBRE_CONFIGURACION
```

### Gestión de Configuraciones

```bash
# Listar todas las configuraciones
./ec2.sh config list
./ec2.sh list  # Alias

# Mostrar detalles de una configuración
./ec2.sh config show NOMBRE_CONFIGURACION

# Agregar nueva configuración
./ec2.sh config add NOMBRE_CONFIGURACION instance_id perfil region alias_ssh archivo_pem

# Ejemplo de agregar configuración
./ec2.sh config add STAGING i-0123456789abcdef0 legacy-static us-west-2 staging-server ~/.ssh/staging-key.pem

# Eliminar configuración
./ec2.sh config remove NOMBRE_CONFIGURACION

# Editar archivo de configuración
./ec2.sh config edit
```

### Ayuda

```bash
# Mostrar ayuda completa
./ec2.sh help
./ec2.sh -h
./ec2.sh --help
```

## Ejemplos de Uso

### Configuración Inicial

1. Agregar una nueva instancia:
   ```bash
   ./ec2.sh config add DEVELOPMENT i-0123456789abcdef0 legacy-static us-east-1 dev-server ~/.ssh/my-key.pem
   ```

2. Verificar que se agregó correctamente:
   ```bash
   ./ec2.sh config list
   ```

### Uso Diario

1. Iniciar instancia de desarrollo:
   ```bash
   ./ec2.sh start DEVELOPMENT
   ```

2. Trabajar con la instancia...

3. Conectar por SSH:
   ```bash
   ./ec2.sh connect DEVELOPMENT
   ```

4. Al finalizar, detener la instancia:
   ```bash
   ./ec2.sh stop DEVELOPMENT
   ```

### Verificación de Estado

```bash
# Ver estado actual
./ec2.sh status DEVELOPMENT

# Ver información completa
./ec2.sh info DEVELOPMENT
```

## Requisitos

- AWS CLI configurado con los perfiles necesarios
- SSH configurado
- Permisos de ejecución en los scripts (`chmod +x *.sh`)

## AWS SSO

> Este repo es público. En tu `config.ini` y en `~/.ec2-cli/sso.config` van tus valores
> reales, pero esos archivos están gitignoreados y nunca se committean. Los ejemplos de
> abajo usan valores ficticios.

### Setup, una sola vez por máquina

```bash
./install.sh                                  # alias `ec2` + autocompletado + ~/.ec2-cli/
cp sso.config.example ~/.ec2-cli/sso.config   # completá los valores de tu org
ec2 sso setup                                 # siembra los perfiles SSO en ~/.aws/config
```

Después apuntá cada instancia al perfil SSO en `config.ini` (ver Migración).

### Uso diario

Sin cambios. Si la sesión SSO expiró, el comando dispara el login solo, imprime
una URL + código para aprobar en el browser y retoma la operación:

```bash
ec2 start DEVELOPMENT
ec2 connect DEVELOPMENT
ec2 stop DEVELOPMENT
```

Para refrescar la sesión a mano:

```bash
ec2 login                # login contra la sso-session default
ec2 login DEVELOPMENT    # login para el perfil de esa instancia
```

### Migración desde keys estáticas

Cambiá el `profile` de cada línea del `config.ini` del perfil estático al perfil SSO
que puede operar EC2. Por ejemplo:

```
DEVELOPMENT=i-0123456789abcdef0:legacy-static:us-east-1:dev-server:~/.ssh/my-key.pem
```

pasa a:

```
DEVELOPMENT=i-0123456789abcdef0:DevAccess-123456789012:us-east-1:dev-server:~/.ssh/my-key.pem
```

Los perfiles estáticos siguen funcionando: si una línea mantiene un `profile` estático,
el CLI no intenta login SSO y opera como antes.

## Características

- ✅ Gestión centralizada de configuraciones
- ✅ Actualización automática de SSH config
- ✅ Colores en la salida para mejor legibilidad
- ✅ Validación de parámetros y dependencias
- ✅ Backup automático de configuraciones SSH
- ✅ Soporte para múltiples regiones y perfiles AWS
- ✅ Manejo de errores robusto

## Estructura del Proyecto

```
commands/
├── ec2.sh                 # Script principal
├── start_vm.sh           # Iniciar instancia
├── stop_vm.sh            # Detener instancia
├── update_aws_ssh.sh     # Actualizar SSH
├── manage_config.sh      # Gestionar configuraciones
├── config.ini            # Archivo de configuración
└── README.md             # Esta documentación
```

## Notas

- Los nombres de configuración pueden contener letras, números, guiones y guiones bajos
- Las rutas de archivos PEM que empiecen con `~` se expandirán automáticamente al directorio home
- El sistema mantiene backups automáticos del archivo SSH config antes de modificarlo
- Las claves SSH se actualizan automáticamente en `known_hosts`
