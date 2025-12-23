#!/bin/bash
# user_data_template.sh
# O script de deploy injeta o IP do banco aqui automaticamente.
DB_HOST="PLACEHOLDER_DB_IP" 

echo "--- Setup Application Server ---"
yum update -y
amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2
yum install -y httpd git

# --- AREA DE OTIMIZACAO (Os alunos podem alterar aqui) ---
echo "StartServers 5" >> /etc/httpd/conf/httpd.conf
echo "MinSpareServers 5" >> /etc/httpd/conf/httpd.conf
# ---------------------------------------------------------

systemctl start httpd
systemctl enable httpd
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

cd /var/www/html
wp core download --allow-root
wp config create --dbname=wordpress --dbuser=wp_user --dbpass=wp_pass --dbhost=$DB_HOST --allow-root

# --- CORREÇÃO DO ERRO 404 (Permalinks) ---
wp rewrite structure '/%postname%/' --hard --allow-root || true
sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
# -----------------------------------------

chown -R apache:apache /var/www/html
systemctl restart httpd