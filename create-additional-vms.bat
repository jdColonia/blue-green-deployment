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