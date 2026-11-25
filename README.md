# Infraestructura Spa de Uñas - AWS + Kubernetes + Istio

Infraestructura como código de la plataforma del sistema de inventario de un spa de uñas. Define los recursos de AWS con Terraform y los manifiestos de Kubernetes e Istio para desplegar el backend con escalabilidad, recuperación automática, despliegues canary y cifrado mTLS entre servicios.

## 🚀 Tecnologías Principales

* Terraform
* AWS (ECR, EKS, VPC, IAM, Secrets Manager, RDS/PostGIS opcional)
* Kubernetes (kubectl)
* Istio (istioctl)
* Docker Desktop (clúster local para pruebas)
* AWS CLI

## ⚙️ Configuración del Entorno

### 1️⃣ Clonar el repositorio

```
git clone https://github.com/Proyecto-Maestria-Spa-Unas/spa-infra-aws.git
cd spa-infra-aws
git checkout develop
```

### 2️⃣ Instalar herramientas

#### 🐧 Linux / Mac

```
brew install terraform kubectl awscli istioctl
```

#### 🪟 Windows (PowerShell)

```
winget install Hashicorp.Terraform
winget install Kubernetes.kubectl
winget install Amazon.AWSCLI
```

Para Istio en Windows, descargue `istioctl.exe` desde https://github.com/istio/istio/releases y ubíquelo en una carpeta del PATH (o en `tools\`, como en el laboratorio).

Verificar:

```
terraform version
kubectl version --client
aws --version
istioctl version --remote=false
```

### 3️⃣ Configurar credenciales de AWS (solo para trabajo local)

```
aws configure sso
```

⚠️ En GitHub Actions no se usan llaves de acceso: la autenticación se hace con OIDC (rol IAM asumido por el workflow).

## ▶️ Ejecutar Terraform

Desde la carpeta del entorno:

```
cd terraform/envs/staging
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

`terraform apply` sobre `staging` y `production` se ejecuta desde el pipeline con aprobación del entorno, no desde equipos personales.

## ☸️ Desplegar en Kubernetes (clúster local o EKS)

```
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/backend/
kubectl apply -f k8s/istio/
kubectl get pods -n spa-inventario
```

Cada Pod debe mostrar `READY 2/2`: el contenedor de la API y el proxy `istio-proxy`.

### Despliegue canary

Editar los pesos en `k8s/istio/virtual-service-canary.yaml` por etapas (90/10 → 50/50 → 0/100) y aplicar en cada una:

```
kubectl apply -f k8s/istio/virtual-service-canary.yaml
```

Rollback: devolver el 100 % del tráfico a `v1` y volver a aplicar.

## 📦 Componentes Principales

### 🔹 Terraform (`terraform/envs`)
Un directorio por entorno con estado aislado. Actualmente declara el repositorio ECR de la API (imágenes inmutables con escaneo al subir).

### 🔹 Deployments y Service (`k8s/base/backend`)
Versiones `v1` y `v2` de la API, Service `ClusterIP`, HPA por CPU, sondas de salud y contenedores sin privilegios.

### 🔹 DestinationRule (`k8s/istio`)
Define los subconjuntos `v1` y `v2` y expulsa réplicas con errores 5xx consecutivos.

### 🔹 VirtualService
Distribución ponderada del tráfico (canary), reintentos y tiempo máximo de respuesta.

### 🔹 PeerAuthentication
mTLS estricto entre los servicios del namespace, sin modificar el código.

### 🔹 AuthorizationPolicy
Solo el ingress gateway puede invocar la API.

## 🔐 Variables y secretos

* Las variables de Terraform se declaran en `variables.tf`; los valores por entorno van en archivos `*.tfvars` que no se suben al repositorio.
* Las variables de la API (`DB_URL`, `JWT_SECRET`, etc.) viven en AWS Secrets Manager y llegan al clúster como el Secret `backend-api-env`.

⚠️ Nunca suba `*.tfstate`, `*.tfvars` ni `kubeconfig` (ya están incluidos en el `.gitignore`).

## 📁 Organización del proyecto

| Carpeta | Uso |
|---|---|
| `terraform/envs/staging` | Infraestructura del entorno de pruebas. |
| `terraform/envs/production` | Infraestructura de producción (requiere aprobación de plataforma-admins). |
| `terraform/modules` | Módulos propios reutilizables (vpc, eks, rds-postgis, secrets, github-oidc). |
| `k8s/base` | Namespace con inyección de Istio y recursos del backend. |
| `k8s/istio` | Políticas de tráfico y seguridad de la malla de servicios. |
| `docs/ROADMAP_INFRA.md` | Fases de aprovisionamiento en AWS. |

## 🧪 Pruebas y calidad

La integración continua ejecuta:

* `calidad / pipeline`: `terraform fmt -check`, `terraform validate` por entorno y `kubeconform` sobre `k8s/`.
* `seguridad / scan`: Trivy sobre malas configuraciones y secretos.

## 🔀 Flujo de trabajo

1. Crear la rama desde `develop`: `git checkout -b feature/eks-cluster`.
2. Abrir un Pull Request hacia `develop` con la salida de `terraform plan` en la descripción.
3. El PR se fusiona cuando pasan los checks y lo aprueba el equipo de DevOps.

## QA remoto mediante AWS CodeBuild

El entorno de QA remoto permite ejecutar pruebas de software
sobre los repositorios de SPA UNAS utilizando infraestructura
temporal en AWS CodeBuild, aprovisionada mediante Terraform.

### Componentes

* AWS CodeBuild con soporte Docker.
* PostgreSQL/PostGIS temporal para pruebas de integracion.
* CloudWatch Logs para seguimiento de ejecuciones.
* IAM con permisos restringidos y autenticacion MFA.
* AWS Budgets para alertas de consumo.

### Repositorios y suites

| Repositorio | Unitarias | Integracion | Todo |
|---|---|---|---|
| `spa-backend-api` | Si | Si | Si |
| `spa-frontend-web` | Si | No | Si |
| `spa-database` | No | Si | Si |

### Configuracion inicial del ejecutor QA

El administrador de infraestructura configura:

* Usuario IAM individual: `spa-qa-jhon`.
* Grupo IAM: `spa-qa-executors`.
* Politica de ejecucion: `spa-qa-ejecutor`.
* Politica individual: `spa-qa-self-management`.
* Acceso inicial a la consola con cambio obligatorio de contrasena.

La contrasena inicial se entrega mediante un mecanismo privado
y seguro, nunca mediante chats ni en el repositorio.

El usuario QA debe realizar los siguientes pasos sin compartir
sus credenciales con el responsable de infraestructura.

#### 1. Primer inicio de sesion

Ingresar a la URL de la consola IAM proporcionada por
el administrador.

Utilizar el usuario `spa-qa-jhon` y cambiar la contrasena
temporal cuando AWS lo solicite.

#### 2. Configurar el dispositivo MFA

En la consola AWS:

1. Abrir el menu de la cuenta.
2. Seleccionar Credenciales de seguridad.
3. Buscar Autenticacion multifactor (MFA).
4. Seleccionar Asignar dispositivo MFA.
5. Utilizar el nombre `spa-qa-jhon`.
6. Seleccionar una aplicacion de autenticacion.
7. Escanear el codigo QR con Microsoft Authenticator
   u otra aplicacion compatible.
8. Completar la validacion solicitada por AWS.
9. Cerrar sesion e ingresar nuevamente utilizando MFA.

El dispositivo MFA debe permanecer bajo control exclusivo
del ejecutor QA.

No compartir el codigo QR, la semilla ni los codigos MFA.

#### 3. Crear las claves de acceso propias

Despues de iniciar sesion utilizando MFA:

1. Abrir Credenciales de seguridad.
2. Buscar Claves de acceso.
3. Seleccionar Crear clave de acceso.
4. Seleccionar Interfaz de linea de comandos (CLI).
5. Completar la creacion.
6. Guardar las credenciales de forma segura.

El ejecutor QA es responsable de sus propias claves.

No enviar las claves al administrador ni almacenarlas
en el repositorio.

#### 4. Preparar Git Bash en Windows

Instalar Git para Windows y AWS CLI v2, si no se encuentran
instalados.

Abrir Git Bash y verificar:

```bash
git --version
aws --version
```

Clonar el repositorio:

```bash
git clone https://github.com/Proyecto-Maestria-Spa-Unas/spa-infra-aws.git
cd spa-infra-aws
git checkout develop
git pull --ff-only
```

Las instrucciones sobre develop aplican una vez integrado
el PR #6. Antes de la integracion, utilizar la rama del PR
autorizada para la revision QA.

#### 5. Configurar el perfil base

Desde Git Bash:

```bash
aws configure --profile spa-qa-base
```

Introducir los valores solicitados:

| Campo | Valor |
|---|---|
| AWS Access Key ID | Clave propia del ejecutor QA |
| AWS Secret Access Key | Clave secreta propia |
| Default region name | us-east-1 |
| Default output format | json |

Verificar la identidad:

```bash
aws sts get-caller-identity --profile spa-qa-base
```

La identidad debe corresponder al usuario `spa-qa-jhon`.

El perfil base no permite ejecutar builds sin MFA.

#### 6. Obtener una sesion temporal MFA

Ejecutar:

```bash
bash scripts/qa-mfa.sh
```

Introducir el codigo de seis digitos generado por la
aplicacion de autenticacion.

El script realiza las siguientes operaciones:

* Verifica AWS CLI v2.
* Comprueba la identidad del perfil base.
* Identifica el ARN del dispositivo MFA.
* Solicita credenciales temporales mediante STS.
* Configura el perfil `spa-qa`.
* Valida la identidad de la sesion temporal.
* Informa la fecha y hora de expiracion.

La operacion STS utilizada es equivalente a:

```bash
aws sts get-session-token \
  --serial-number "arn:aws:iam::<ACCOUNT_ID>:mfa/spa-qa-jhon" \
  --token-code "<CODIGO_MFA>" \
  --duration-seconds 43200 \
  --profile spa-qa-base
```

El comando anterior es una referencia tecnica.
Se recomienda utilizar el script para evitar imprimir
las credenciales temporales en la terminal.

El script almacena las credenciales en los archivos locales
de configuracion de AWS CLI, fuera del repositorio.
Estos archivos deben mantenerse protegidos.

La duracion solicitada de la sesion es de 12 horas.

#### 7. Renovar la sesion MFA

Cuando expire la sesion o AWS devuelva `ExpiredToken`,
ejecutar nuevamente:

```bash
bash scripts/qa-mfa.sh
```

No es necesario crear nuevas claves permanentes para
renovar una sesion temporal.

### Ejecucion remota

Sintaxis:

```bash
bash scripts/qa-remoto.sh <repo> <ref> <suite>
```

Ejemplos para uso exclusivo del ejecutor QA:

Backend - pruebas unitarias:

```bash
bash scripts/qa-remoto.sh spa-backend-api develop unitarias
```

Backend - pruebas de integracion:

```bash
bash scripts/qa-remoto.sh spa-backend-api develop integracion
```

Backend - suite completa:

```bash
bash scripts/qa-remoto.sh spa-backend-api develop todo
```

Frontend:

```bash
bash scripts/qa-remoto.sh spa-frontend-web develop todo
```

Base de datos:

```bash
bash scripts/qa-remoto.sh spa-database develop integracion
```

El parametro `ref` admite ramas, referencias de Pull Request
y SHA completos de commits.

El script presenta los logs de CloudWatch y el resultado
de la ejecucion.

Codigos de salida:

| Codigo | Significado |
|---|---|
| 0 | Ejecucion satisfactoria |
| 1 | Error o ejecucion no satisfactoria |
| 130 | Interrupcion solicitada por el usuario |

### Archivos principales

| Ruta | Uso |
|---|---|
| `terraform/envs/qa-remoto/` | Infraestructura independiente de QA remoto. |
| `buildspecs/` | Dispatcher y scripts de pruebas. |
| `scripts/qa-remoto.sh` | Cliente de ejecucion remota. |
| `scripts/qa-mfa.sh` | Obtencion y renovacion de sesiones MFA. |
| `docs/qa-remoto.md` | Documentacion tecnica y manual de operacion. |
| `docs/qa-remoto-evidencias.md` | Evidencias de despliegue y validacion. |

### Seguridad y alcance

El entorno no requiere instancias EC2, bases de datos RDS
ni clusters EKS permanentes.

No utiliza credenciales de staging, production o Supabase.

La prueba de humo esta reservada al responsable de
infraestructura. Las pruebas funcionales corresponden
exclusivamente al equipo QA.

La politica del ejecutor restringe las operaciones de
CodeBuild y CloudWatch al entorno de QA remoto.

Las operaciones de ejecucion requieren una sesion MFA.

Los permisos de autogestion permiten al ejecutor administrar
sus propias claves y configurar su dispositivo MFA, con las
restricciones definidas en la politica IAM correspondiente.

Los riesgos residuales de StartBuild fueron aceptados
por el PO durante la revision del PR #6.

El presupuesto configurado genera alertas y no constituye
un limite automatico de consumo.

El timeout de 30 minutos y la concurrencia de una ejecucion
son controles configurados en el proyecto. No eliminan todos
los riesgos residuales asociados a StartBuild.

No almacenar contrasenas, claves de acceso, tokens MFA,
credenciales temporales ni estados de Terraform en Git.

### Control de costos

| Control | Configuracion |
|---|---|
| Presupuesto mensual | USD 10 |
| Alertas | 50%, 80% y 100% |
| Concurrencia configurada | 1 |
| Timeout configurado | 30 minutos |
| Retencion de logs | 7 dias |

### Documentacion tecnica

Consultar el [Manual de QA remoto](docs/qa-remoto.md)
para conocer la arquitectura, configuracion, despliegue,
ejecucion, seguridad, costos y estado de implementacion.

### Estado de implementacion

Validacion de infraestructura realizada el 24 de noviembre
de 2026.

| Actividad | Resultado |
|---|---|
| Terraform validate | PASS |
| Terraform plan | 6 recursos por crear |
| Terraform apply | 6 recursos creados |
| AWS CodeBuild | Operativo |
| CloudWatch Logs | Operativo |
| Python 3.12.16 | PASS |
| Node.js 22.23.4 | PASS |
| Docker 29.9.2 | PASS |
| PostgreSQL 16.4 | PASS |
| PostGIS 3.4.3 | PASS |
| Limpieza de recursos temporales | PASS |
| Prueba de humo | SUCCEEDED |
| Retiro de permisos temporales | Completado |
| Pull Request hacia develop | Creado - PR #6 |
| Checks iniciales del PR | 3 de 3 exitosos |
| Aceptacion de riesgos residuales | Aprobada por PO |
| Usuario IAM del ejecutor QA | Creado |
| Asignacion de politica QA | Completada |
| Politica de autogestion | Creada |
| Script de autenticacion MFA | Implementado |
| Validacion de sintaxis del script MFA | PASS |
| Activacion MFA por el ejecutor | Pendiente |
| Validacion real de sesion MFA | Pendiente |
| Pruebas negativas de IAM | Pendiente |
| Pruebas funcionales | Pendiente |
| Aceptacion definitiva del issue #5 | Pendiente |

La prueba de humo finalizo satisfactoriamente en aproximadamente
71 segundos, incluyendo la eliminacion del contenedor temporal
de PostgreSQL/PostGIS y sus volumenes.

El entorno se encuentra desplegado y validado a nivel de
infraestructura.

La primera ejecucion real de las suites funcionales corresponde
al responsable QA y constituye un requisito para la aceptacion
definitiva del issue.

### Evidencias de validacion

* [Manual tecnico de QA remoto](docs/qa-remoto.md).
* [Evidencias del despliegue y prueba de humo](docs/qa-remoto-evidencias.md).
* [Issue #5](https://github.com/Proyecto-Maestria-Spa-Unas/spa-infra-aws/issues/5).
* [Pull Request #6](https://github.com/Proyecto-Maestria-Spa-Unas/spa-infra-aws/pull/6).

La implementacion es independiente de staging y production
y no modifica los componentes asociados a DV5 y DV7.
