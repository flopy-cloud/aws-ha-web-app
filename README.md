# aws-ha-# Aplicación de alta disponibilidad en AWS con Terraform

## Objetivo
Armar una aplicación web que siga respondiendo aunque se caiga un servidor o una zona de disponibilidad, y comprobarlo apagando una instancia a propósito.

## Arquitectura
- **VPC** con dos subredes públicas (instancias web y balanceador) y dos subredes privadas (base de datos), repartidas en dos zonas de disponibilidad.
- **Application Load Balancer:** recibe el tráfico HTTP y lo reparte entre las instancias sanas.
- **Auto Scaling Group:** mínimo 2 y máximo 3 instancias `t3.micro` repartidas en las dos zonas. Usa los chequeos de salud del balanceador, así que reemplaza automáticamente las instancias que fallan.
- **Plantilla de lanzamiento:** Amazon Linux 2023 con IMDSv2 obligatorio; un script de arranque instala Apache y publica una página que muestra el ID y la zona de la instancia que respondió.
- **RDS MySQL Multi-AZ:** en subredes privadas, cifrada, sin acceso público y con la contraseña administrada por RDS en Secrets Manager.
- **Security groups encadenados:** internet → balanceador (puerto 80) → instancias (solo desde el balanceador) → base de datos (solo desde las instancias).

Toda la infraestructura está definida con **Terraform** (19 recursos) en la región `us-east-1`.

## Cómo usarlo
```bash
terraform init
terraform plan
terraform apply
```

Probar el balanceo:
```bash
ALB=$(terraform output -raw alb_dns)
for i in 1 2 3 4 5 6; do curl -s http://$ALB | grep Instancia; done
```

Para eliminar todo:
```bash
terraform destroy
```

## Resultados

### Despliegue con Terraform

<img width="494" height="44" alt="Captura de pantalla de 2026-10-28 18-25-54" src="https://github.com/user-attachments/assets/9a895b57-853b-4c41-bdcd-6d2ad7fa9e99" />


### El balanceador reparte el tráfico entre las dos zonas
Las respuestas alternan entre dos instancias distintas.

<img width="308" height="118" alt="Captura de pantalla de 2026-10-28 18-29-36" src="https://github.com/user-attachments/assets/530fe975-8750-426b-8e55-f17897b310f7" />


Cada una corre en una zona de disponibilidad diferente.

<img width="835" height="146" alt="Captura de pantalla de 2026-10-28 18-30-52" src="https://github.com/user-attachments/assets/8bb2b538-7c2e-4963-ae27-61215b92b082" />


### Caída de una instancia
Terminé una instancia a propósito mientras hacía consultas continuas. Hubo unos segundos sin respuesta mientras el balanceador detectaba la caída, y después todo el tráfico pasó a la instancia que quedó viva.

<img width="384" height="214" alt="Captura de pantalla de 2026-10-28 18-39-27" src="https://github.com/user-attachments/assets/56c7407f-cf8e-4451-9f67-550863569c5a" />


### Recuperación automática
El Auto Scaling Group creó una instancia nueva por su cuenta y volvió a tener las dos en funcionamiento.

<img width="350" height="248" alt="Captura de pantalla de 2026-10-28 18-40-54" src="https://github.com/user-attachments/assets/1b091e5e-f6e4-4714-916d-d89d1cc90857" />


### Base de datos Multi-AZ
La base tiene su instancia principal en `us-east-1b` y la réplica en espera en `us-east-1a`.

<img width="832" height="141" alt="Captura de pantalla de 2026-10-28 18-46-00" src="https://github.com/user-attachments/assets/2260ad08-422a-4618-a8aa-e81b50b7608f" />

## Decisiones de diseño y límites
- **Instancias en subredes públicas:** para no pagar un NAT Gateway (casi un dólar por día), las instancias tienen IP pública, pero su security group solo acepta tráfico del balanceador. En producción las pondría en subredes privadas con NAT o endpoints de VPC.
- **Solo HTTP:** el balanceador no usa HTTPS. En producción agregaría un certificado de ACM y redirección a HTTPS.
- **Conmutación de la base:** verifiqué que Multi-AZ está activo, con su réplica en otra zona, pero no probé el failover.

## Qué aprendí
- Con la verificación de salud por el balanceador, el Auto Scaling Group reemplaza solo las instancias que fallan.
- Repartir recursos en dos zonas es lo que permite sobrevivir a la caída de una.
- Encadenar los security groups limita cada capa a recibir tráfico solo de la anterior.
- El balanceador tarda unos segundos en retirar una instancia caída, así que puede haber un corte breve.

## Costo
El balanceador, las instancias y la base Multi-AZ cuestan alrededor de US$2,50 por día si quedan prendidos. Levanté la infraestructura solo durante las pruebas y la destruí con `terraform destroy`.web-app
