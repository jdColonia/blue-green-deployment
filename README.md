# Guía Paso a Paso para Implementación Blue-Green Deployment en AWS

## ¿Qué es Blue-Green Deployment?

La implementación Blue-Green es una estrategia que permite actualizar aplicaciones con cero tiempo de inactividad. Consiste en tener dos entornos idénticos (Blue y Green) donde:

- El entorno Blue contiene la versión actual de la aplicación
- El entorno Green se utiliza para desplegar la nueva versión
- Una vez verificado que todo funciona correctamente en Green, se redirige el tráfico de Blue a Green

La principal ventaja es que si hay problemas, puedes volver rápidamente al entorno Blue.

## Requisitos Previos

Para este proyecto necesitarás:

- Una cuenta de AWS con permisos adecuados

## Paso 0: Creación de Máquinas Virtuales en AWS

### Script 1: Creación de la VM Server

Este script creará la VM principal con los puertos que se muestran en la imagen (22, 80, 443, 465, 587, 3000-11000).

```bash
@echo off
echo Creando VM Server para Blue-Green Deployment...

REM Crear grupo de seguridad para la VM Server
aws ec2 create-security-group --group-name BlueGreen-Server-SG --description "Security group for Blue-Green Deployment Server"

REM Configurar reglas de entrada para el grupo de seguridad
aws ec2 authorize-security-group-ingress --group-name BlueGreen-Server-SG --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name BlueGreen-Server-SG --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name BlueGreen-Server-SG --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name BlueGreen-Server-SG --protocol tcp --port 465 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name BlueGreen-Server-SG --protocol tcp --port 587 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name BlueGreen-Server-SG --ip-permissions "[{\"IpProtocol\":\"tcp\",\"FromPort\":3000,\"ToPort\":11000,\"IpRanges\":[{\"CidrIp\":\"0.0.0.0/0\"}]}]"

REM Crear par de claves para acceso SSH
aws ec2 create-key-pair --key-name BlueGreen-Key --query "KeyMaterial" --output text > BlueGreen-Key.pem

REM Crear la instancia EC2 (Server)
aws ec2 run-instances --image-id ami-0c7217cdde317cfec --count 1 --instance-type t2.medium --key-name BlueGreen-Key --security-group-ids BlueGreen-Server-SG --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":20,\"DeleteOnTermination\":true}}]" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Server}]"

echo Obteniendo IPs publicas...
aws ec2 describe-instances --filters "Name=tag:Name,Values=Server" --query "Reservations[0].Instances[0].PublicIpAddress" --output text > server-ip.txt

echo La VM Server ha sido creada
```

### Script 2: Creación de las VMs Adicionales

Este script creará las VMs adicionales (Jenkins, Sonarqube, Nexus y Monitoring) con las mismas características.

```bash
@echo off
echo Creando VMs adicionales para Blue-Green Deployment...

REM Crear las instancias EC2 adicionales
echo Creando instancia Jenkins...
aws ec2 run-instances --image-id ami-0c7217cdde317cfec --count 1 --instance-type t2.medium --key-name BlueGreen-Key --security-group-ids BlueGreen-Server-SG --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":25,\"DeleteOnTermination\":true}}]" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Jenkins}]"

echo Creando instancia Sonarqube...
aws ec2 run-instances --image-id ami-0c7217cdde317cfec --count 1 --instance-type t2.medium --key-name BlueGreen-Key --security-group-ids BlueGreen-Server-SG --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":25,\"DeleteOnTermination\":true}}]" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Sonarqube}]"

echo Creando instancia Nexus...
aws ec2 run-instances --image-id ami-0c7217cdde317cfec --count 1 --instance-type t2.medium --key-name BlueGreen-Key --security-group-ids BlueGreen-Server-SG --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":25,\"DeleteOnTermination\":true}}]" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Nexus}]"

echo Creando instancia Monitoring...
aws ec2 run-instances --image-id ami-0c7217cdde317cfec --count 1 --instance-type t2.medium --key-name BlueGreen-Key --security-group-ids BlueGreen-Server-SG --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":25,\"DeleteOnTermination\":true}}]" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Monitoring}]"

echo Esperando a que las instancias estén en ejecución...
timeout /t 120

REM Obtener las IPs públicas de las instancias
echo Obteniendo IPs publicas...
aws ec2 describe-instances --filters "Name=tag:Name,Values=Jenkins" --query "Reservations[0].Instances[0].PublicIpAddress" --output text > jenkins-ip.txt
aws ec2 describe-instances --filters "Name=tag:Name,Values=Sonarqube" --query "Reservations[0].Instances[0].PublicIpAddress" --output text > sonarqube-ip.txt
aws ec2 describe-instances --filters "Name=tag:Name,Values=Nexus" --query "Reservations[0].Instances[0].PublicIpAddress" --output text > nexus-ip.txt
aws ec2 describe-instances --filters "Name=tag:Name,Values=Monitoring" --query "Reservations[0].Instances[0].PublicIpAddress" --output text > monitoring-ip.txt

echo Las VMs adicionales han sido creadas. Las IPs publicas se han guardado en archivos separados.
```

### Instrucciones de Uso

1. **Requisitos previos**:
   - Tener AWS CLI instalado en tu máquina local
   - Tener configuradas tus credenciales de AWS (`aws configure`)
2. **Para crear la VM Server**:

```bash
./create-server-vm.bat
```

3. **Para crear las VMs adicionales**:

```bash
./create-additional-vms.bat
```

Grupo de seguridad

VMs

## Paso 1: Configurar la Máquina Virtual Server

Después de lanzar la instancia procedemos a ingresar a la VM y actualizar el sistema:

```bash
sudo apt update && sudo apt upgrade -y
```

## Paso 2: Instalar AWS CLI

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip
unzip awscliv2.zip
sudo ./aws/install
```

## Paso 3: Configurar AWS CLI

Necesitarás crear una clave de acceso desde la consola IAM de AWS:

```bash
aws configure
```

Cuando se te solicite, ingresa:

- AWS Access Key ID
- AWS Secret Access Key
- Región (por ejemplo, us-east-1)
- Formato de salida (puedes dejarlo en blanco)

## Paso 4: Instalar Terraform

```bash
sudo snap install terraform --classic
```

## Paso 5: Clonar el Repositorio

```bash
git clone https://github.com/jdColonia/blue-green-deployment
cd blue-green-deployment
```

## Paso 6: Modificar Archivos de Configuración

Antes de continuar, debes modificar algunos archivos:

1. En `variable.tf`: Cambia "your private key"
2. En `main.tf`: Cambia la región y zona de disponibilidad si no estás en India

## Paso 7: Crear el Cluster EKS con Terraform

Navega a la carpeta del cluster:

```bash
cd cluster
```

Ejecuta los comandos de Terraform:

```bash
terraform init
terraform plan
terraform apply --auto-approve
```

Esto creará aproximadamente 17 recursos y tardará entre 5-10 minutos.

## Paso 8: Instalar Jenkins

Conéctate al servidor Jenkins y ejecuta:

```bash
sudo apt update
sudo apt install openjdk-17-jre-headless -y
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins
```

Accede a Jenkins a través de: http://IP-DEL-SERVIDOR:8080

## Paso 9: Instalar Nexus

```bash
sudo apt update
sudo apt install docker.io -y
sudo usermod -aG docker $USER
newgrp docker
docker run -d --name nexus3 -p 8081:8081 sonatype/nexus3
```

Después de unos minutos, accede a Nexus a través de: http://IP-DEL-SERVIDOR:8081

Para obtener la contraseña de administrador:

```bash
docker exec -it CONTAINER_ID /bin/bash
cd sonatype-work/nexus3/
cat admin.password
```

Usuario: admin
Contraseña: (la que obtuviste del comando anterior)

## Paso 10: Instalar SonarQube

```bash
sudo apt update
sudo apt install docker.io -y
sudo usermod -aG docker ubuntu
newgrp docker
docker run -d -p 9000:9000 sonarqube:lts-community
```

Accede a SonarQube a través de: http://IP-DEL-SERVIDOR:9000

Usuario: admin
Contraseña: admin

## Paso 11: Instalar Docker en el Servidor Jenkins

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker jenkins
```

Reinicia Jenkins:
http://IP-DEL-SERVIDOR:8080/restart

## Paso 12: Instalar Trivy en el Servidor Jenkins

```bash
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy
```

## Paso 13: Instalar kubectl en el Servidor Jenkins

```bash
sudo snap install kubectl --classic
```

## Paso 14: Configurar kubectl para Acceder al Cluster EKS

```bash
aws eks --region us-east-1 update-kubeconfig --name devopsshack-cluster
```

Nota: Asegúrate de cambiar la región (us-east-1) si estás usando una diferente.

## Paso 15: Configurar RBAC para Permisos en Kubernetes

Para continuar con la implementación, necesitamos configurar RBAC (Control de Acceso Basado en Roles) para dar permisos específicos a Jenkins para realizar operaciones en el clúster Kubernetes.

### 15.1 Crear un Namespace

Primero, vamos a crear un namespace llamado "webapps" donde desplegaremos nuestra aplicación:

```bash
kubectl create ns webapps
```

### 15.2 Crear una Cuenta de Servicio

Crea un archivo llamado `sa.yml` con el siguiente contenido:

```yaml:c:\Users\Juan David Colonia\Downloads\blue-green-deployment\sa.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: webapps
```

Aplica la configuración:

```bash
kubectl apply -f sa.yml
```

### 15.3 Crear un Rol

Crea un archivo llamado `role.yml` con el siguiente contenido:

```yaml:c:\Users\Juan David Colonia\Downloads\blue-green-deployment\role.yml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: webapps
rules:
  - apiGroups:
        - ""
        - apps
        - autoscaling
        - batch
        - extensions
        - policy
        - rbac.authorization.k8s.io
    resources:
      - pods
      - secrets
      - componentstatuses
      - configmaps
      - daemonsets
      - deployments
      - events
      - endpoints
      - horizontalpodautoscalers
      - ingress
      - jobs
      - limitranges
      - namespaces
      - nodes
      - pods
      - persistentvolumes
      - persistentvolumeclaims
      - resourcequotas
      - replicasets
      - replicationcontrollers
      - serviceaccounts
      - services
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

Aplica la configuración:

```bash
kubectl apply -f role.yml
```

### 15.4 Crear un RoleBinding

Crea un archivo llamado `rolebinding.yml` con el siguiente contenido:

```yaml:c:\Users\Juan David Colonia\Downloads\blue-green-deployment\rolebinding.yml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rolebinding
  namespace: webapps
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-role
subjects:
- namespace: webapps
  kind: ServiceAccount
  name: jenkins
```

Aplica la configuración:

```bash
kubectl apply -f rolebinding.yml
```

### 15.5 Crear un Token para la Cuenta de Servicio

Crea un archivo llamado `sec.yaml` con el siguiente contenido:

```yaml:c:\Users\Juan David Colonia\Downloads\blue-green-deployment\sec.yaml
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: mysecretname
  namespace: webapps
  annotations:
    kubernetes.io/service-account.name: jenkins
```

Aplica la configuración:

```bash
kubectl apply -f sec.yaml -n webapps
```

### 15.6 Obtener el Token

Ejecuta el siguiente comando para obtener el token:

```bash
kubectl describe secret mysecretname -n webapps
```

Copia el valor del token que aparece en la salida.

### 15.7 Configurar Jenkins con el Token

1. Accede a la interfaz web de Jenkins
2. Ve a "Administrar Jenkins" > "Administrar Credenciales" > "Global" > "Añadir Credenciales"
3. Selecciona "Secret text" como tipo
4. Pega el token que copiaste en el campo "Secret"
5. En el campo "ID", escribe "k8-token"
6. Haz clic en "OK" para guardar

## Paso 16: Instalar Plugins en Jenkins

Ahora necesitamos instalar varios plugins en Jenkins para poder trabajar con Kubernetes y otras herramientas:

1. Accede a la interfaz web de Jenkins
2. Ve a "Administrar Jenkins" > "Administrar Plugins" > "Disponibles"
3. Busca e instala los siguientes plugins:

   - Sonarqube Scanner
   - Maven Integration
   - Config File Provider
   - Pipeline Maven Integration
   - Docker Pipeline
   - Pipeline Stage View
   - Generic Webhook Trigger
   - Kubernetes
   - Kubernetes CLI
   - Kubernetes Client API

4. Marca la opción "Reiniciar Jenkins cuando termine la instalación y no haya trabajos en ejecución"

## Paso 17: Crear el Pipeline de Jenkins

Ahora vamos a crear un pipeline en Jenkins que automatizará todo el proceso de despliegue Blue-Green. Este pipeline nos permitirá elegir entre los entornos Blue y Green, y también nos dará la opción de cambiar el tráfico entre ellos.

### 17.1 Configurar Maven y SonarQube en Jenkins

Antes de crear el pipeline, necesitamos configurar algunas herramientas:

1. **Configurar Maven**:

   - Ve a "Administrar Jenkins" > "Herramientas" > "Maven"
   - Haz clic en "Añadir Maven"
   - Nombre: "maven3"
   - Selecciona "Instalar automáticamente"
   - Guarda los cambios

2. **Configurar SonarQube Scanner**:

   - Ve a "Administrar Jenkins" > "Herramientas" > "SonarQube Scanner"
   - Haz clic en "Añadir SonarQube Scanner"
   - Nombre: "sonar-scanner"
   - Selecciona "Instalar automáticamente"
   - Guarda los cambios

3. **Configurar Token de SonarQube**:

   - Ve a tu servidor SonarQube > "Administración" > "Seguridad" > "Usuarios"
   - Genera un nuevo token
   - Ve a Jenkins > "Administrar Jenkins" > "Credenciales" > "Global"
   - Añade una nueva credencial de tipo "Secret text"
   - Pega el token y nómbralo "sonar-token"

4. **Configurar Servidor SonarQube en Jenkins**:

   - Ve a "Administrar Jenkins" > "Sistema"
   - Busca la sección "SonarQube servers"
   - Nombre: "sonar"
   - URL del servidor: http://IP-DEL-SERVIDOR-SONARQUBE:9000
   - Selecciona el token "sonar-token"
   - Guarda los cambios

5. **Configurar Maven Settings**:

   - Ve a "Administrar Jenkins" > "Administrar Archivos" > "Global Maven settings"
   - ID: "maven-settings"
   - Añade las credenciales para el servidor Nexus (snapshots y releases)
   - Guarda los cambios

6. **Configurar Nexus en pom.xml**:
   - Ve al servidor Nexus > "Explorar" > Copia las URLs de Maven releases y snapshots
   - Añade estas URLs en la sección `distributionManagement` del archivo pom.xml

### 17.2 Crear el Pipeline

Ahora vamos a crear un nuevo pipeline en Jenkins:

1. Ve a Jenkins > "Nueva Tarea"
2. Ingresa un nombre (por ejemplo, "blue-green-deployment")
3. Selecciona "Pipeline" y haz clic en "OK"
4. En la sección "Pipeline", selecciona "Pipeline script" y pega el siguiente código:

```groovy
pipeline {
    agent any

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['blue', 'green'], description: 'Choose which environment to deploy: Blue or Green')
        choice(name: 'DOCKER_TAG', choices: ['blue', 'green'], description: 'Choose the Docker image tag for the deployment')
        booleanParam(name: 'SWITCH_TRAFFIC', defaultValue: false, description: 'Switch traffic between Blue and Green')
    }

    environment {
        IMAGE_NAME = "premd91/bankapp"
        TAG = "${params.DOCKER_TAG}"  // The image tag now comes from the parameter
        KUBE_NAMESPACE = 'webapps'
        SCANNER_HOME = tool 'sonar-scanner'
    }

    stages {
        stage('Git Checkout') {
            steps {
                git branch: 'main', credentialsId: 'git-cred', url: 'https://github.com/devops-methodology/Blue-Green-Deployment.git'
            }
        }

        stage('Compile') {
            tools {
                maven 'maven3'
            }
            steps {
                sh 'mvn compile'
            }
        }

        stage('Test') {
            tools {
                maven 'maven3'
            }
            steps {
                sh 'mvn test'
            }
        }

        stage('Trivy FS Scan') {
            steps {
                sh 'trivy fs --format table -o fs.html .'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar') {
                    sh "${SCANNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=Multitier -Dsonar.projectName=Multitier -Dsonar.java.binaries=target"
                }
            }
        }

        stage('Quality Gate Check') {
            steps {
                timeout(time: 60, unit: 'SECONDS') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Application') {
            tools {
                maven 'maven3'
            }
            steps {
                sh 'mvn package -DskipTests=true'
            }
        }

        stage('Publish to Nexus') {
            tools {
                maven 'maven3'
            }
            steps {
                sh 'mvn deploy -DskipTests=true'
            }
        }

        stage('Docker Build & Tag') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${TAG} ."
            }
        }

        stage('Docker Image Scan') {
            steps {
                sh "trivy image --format table -o image-scan.html ${IMAGE_NAME}:${TAG}"
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([string(credentialsId: 'docker-hub', variable: 'DOCKER_HUB_PASS')]) {
                    sh "docker login -u premd91 -p ${DOCKER_HUB_PASS}"
                    sh "docker push ${IMAGE_NAME}:${TAG}"
                }
            }
        }

        stage('Deploy MySQL') {
            steps {
                script {
                    withKubeConfig(credentialsId: 'k8-token') {
                        sh 'kubectl apply -f k8s/mysql-deployment.yaml -n ${KUBE_NAMESPACE}'
                        sh 'kubectl apply -f k8s/mysql-service.yaml -n ${KUBE_NAMESPACE}'
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    withKubeConfig(credentialsId: 'k8-token') {
                        sh "kubectl apply -f k8s/${params.DEPLOY_ENV}-deployment.yaml -n ${KUBE_NAMESPACE}"
                        sh 'kubectl apply -f k8s/service.yaml -n ${KUBE_NAMESPACE}'
                    }
                }
            }
        }

        stage('Switch Traffic') {
            when {
                expression { params.SWITCH_TRAFFIC == true }
            }
            steps {
                script {
                    withKubeConfig(credentialsId: 'k8-token') {
                        sh "kubectl patch service bank-app-service -n ${KUBE_NAMESPACE} -p '{\"spec\":{\"selector\":{\"app\":\"${params.DEPLOY_ENV}\"}}}'"
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    withKubeConfig(credentialsId: 'k8-token') {
                        sh "kubectl get all -n ${KUBE_NAMESPACE}"
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'fs.html,image-scan.html', followSymlinks: false
        }
    }
}
```

### 17.3 Configurar Webhook de SonarQube

Para que SonarQube pueda notificar a Jenkins sobre el resultado del análisis de calidad:

1. Ve a tu servidor SonarQube > "Administración" > "Configuración" > "Webhooks"
2. Haz clic en "Crear"
3. Nombre: "jenkins"
4. URL: http://IP-DE-JENKINS:8080/sonarqube-webhook/
5. Haz clic en "Crear"

### 17.4 Crear Credenciales Adicionales

Necesitamos crear algunas credenciales más en Jenkins:

1. **Credenciales de Git**:

   - Ve a "Administrar Jenkins" > "Credenciales" > "Global"
   - Añade una nueva credencial de tipo "Username with password"
   - ID: "git-cred"
   - Ingresa tu nombre de usuario y contraseña de GitHub
   - Guarda los cambios

2. **Credenciales de Docker Hub**:
   - Ve a "Administrar Jenkins" > "Credenciales" > "Global"
   - Añade una nueva credencial de tipo "Secret text"
   - ID: "docker-hub"
   - Ingresa tu contraseña de Docker Hub
   - Guarda los cambios

### 17.5 Ejecutar el Pipeline

Ahora puedes ejecutar el pipeline:

1. Ve a tu pipeline en Jenkins
2. Haz clic en "Construir con parámetros"
3. Selecciona el entorno que deseas desplegar (Blue o Green)
4. Selecciona la etiqueta de Docker que deseas usar
5. Decide si quieres cambiar el tráfico entre entornos
6. Haz clic en "Construir"

### 17.6 Verificar el Despliegue

Una vez que el pipeline haya terminado, puedes verificar el despliegue:

```bash
kubectl get all -n webapps
```

Abre un navegador y accede a la URL del balanceador de carga para ver la aplicación en funcionamiento.

## Paso 18: Limpieza de Recursos

Cuando hayas terminado con el proyecto, es importante eliminar todos los recursos para evitar cargos innecesarios:

1. Elimina las instancias EC2
2. Elimina el grupo de nodos EKS y luego el clúster EKS (esto puede tardar 2-3 minutos)
3. Elimina los roles y políticas
4. Elimina el balanceador de carga (muy importante)
5. Verifica el panel de EC2 para asegurarte de que se han eliminado VPC, subredes y tablas de rutas
