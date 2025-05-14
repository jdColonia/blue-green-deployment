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