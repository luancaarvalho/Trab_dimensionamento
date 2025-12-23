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
wp config create --dbname=wordpress --dbuser=wp_user --dbpass=wp_pass --dbhost=10.0.1.83 --allow-root

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
wp option update home 'http://BenchmarkALB-1315564996.us-east-1.elb.amazonaws.com' --allow-root
wp option update siteurl 'http://BenchmarkALB-1315564996.us-east-1.elb.amazonaws.com' --allow-root
chown apache:apache /var/www/html/.htaccess
chmod 644 /var/www/html/.htaccess

systemctl restart httpd
