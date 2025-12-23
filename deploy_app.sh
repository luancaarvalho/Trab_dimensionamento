#!/bin/bash
# deploy_app.sh (Gold Master - Final Fix LB Registration)

# --- Carrega configurações ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# --- CONFIGURAÇÃO ---
INSTANCE_COUNT=3          # Quantidade de instâncias (Escala Horizontal)
INSTANCE_TYPE="t3.xlarge"  # Tipo da instância (Escala Vertical)

# --- Funções Auxiliares ---
get_output() {
    KEY=$1
    VAL=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='$KEY'].OutputValue" --output text 2>/dev/null)
    if [ "$VAL" == "None" ] || [ -z "$VAL" ]; then
        echo "ERRO CRÍTICO: Output '$KEY' não encontrado na stack '$STACK_NAME'." >&2
        return 1
    fi
    echo "$VAL"
}

echo "--- 1. Lendo dados da Arena ---"
TG_ARN=$(get_output "TargetGroupARN") || exit 1
DB_IP=$(get_output "DatabasePrivateIP") || exit 1
SG_ID=$(get_output "SecurityGroupID") || exit 1
LB_DNS=$(get_output "LoadBalancerDNS") || exit 1
SUBNET_ID=$(aws cloudformation describe-stack-resources --stack-name $STACK_NAME --query "StackResources[?LogicalResourceId=='PublicSubnet1'].PhysicalResourceId" --output text)
AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 --query 'Parameters[0].Value' --output text)

# --- Check de Idempotência ---
EXISTING_IDS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${OWNER_TAG}-App" "Name=instance-state-name,Values=running,pending" --query "Reservations[].Instances[].InstanceId" --output text)
if [ "$EXISTING_IDS" != "" ] && [ "$EXISTING_IDS" != "None" ]; then
    echo "AVISO: Instâncias já existem ($EXISTING_IDS)."
    echo "       URL: http://$LB_DNS"
    exit 0
fi

echo "--- 2. Lançando Aplicação ($INSTANCE_COUNT x $INSTANCE_TYPE) ---"

cat <<EOF > user_data_final.sh
#!/bin/bash
yum update -y
amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2
yum install -y httpd git

systemctl start httpd
systemctl enable httpd
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

cd /var/www/html
wp core download --allow-root
wp config create --dbname=wordpress --dbuser=wp_user --dbpass=wp_pass --dbhost=$DB_IP --allow-root

# --- FIX APACHE CONFIG (AllowOverride) ---
cat <<CONF > /etc/httpd/conf.d/wp-override.conf
<Directory "/var/www/html">
    AllowOverride All
</Directory>
CONF

# --- FIX PERMALINKS & .HTACCESS ---
chown -R apache:apache /var/www/html

# Cria estrutura de permalinks
wp rewrite structure '/%postname%/' --hard --allow-root

# Cria arquivo .htaccess explicitamente
cat <<HTACCESS > /var/www/html/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
HTACCESS

# Ajusta URLs e Permissões Finais
wp option update home 'http://$LB_DNS' --allow-root
wp option update siteurl 'http://$LB_DNS' --allow-root
chown apache:apache /var/www/html/.htaccess
chmod 644 /var/www/html/.htaccess

systemctl restart httpd
EOF

INSTANCE_IDS=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count $INSTANCE_COUNT \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_ID \
    --user-data file://user_data_final.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${OWNER_TAG}-App}]" \
    --query 'Instances[*].InstanceId' \
    --output text)

echo "Instâncias criadas: $INSTANCE_IDS"
echo "Aguardando boot (30s)..."
aws ec2 wait instance-running --instance-ids $INSTANCE_IDS

echo "Registrando no Load Balancer..."
# Loop para registrar todas as N instâncias criadas
for id in $INSTANCE_IDS; do
    # CORREÇÃO AQUI: Removida a barra invertida antes do $id
    aws elbv2 register-targets --target-group-arn "$TG_ARN" --targets Id=$id
done

echo "========================================="
echo " DEPLOY PRONTO: http://$LB_DNS"
echo "========================================="