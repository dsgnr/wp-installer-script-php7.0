#!/usr/bin/env bash
# @author: Daniel Hand
# https://www.danielhand.io
#!/bin/bash -e
sitestore=/var/www
clear
echo "============================================"
echo "WordPress Install Script"
echo "============================================"
echo "Do you need to setup new MySQL database? (y/n)"
read -e setupmysql
if [ "$setupmysql" == y ] ; then
	echo "MySQL Admin User: "
	read -e mysqluser
	echo "MySQL Admin Password: "
	read -s mysqlpass
	echo "MySQL Host (Enter for default 'localhost'): "
	read -e mysqlhost
		mysqlhost=${mysqlhost:-localhost}
fi
echo "Domain name of site (without www)"
read -e domain
echo "Database Name: "
read -e dbname
echo "Database User: "
read -e dbuser
echo "Database Password: "
read -s dbpass
echo "Please enter the database prefix (with underscore afterwards):"
read -e dbprefix
echo "Please specify WP language (eg. en_GB):"
read -e wplocale
echo "Site title:"
read -e sitetitle
echo "Site administrator username:"
read -e adminusername
echo "Site administrator password:"
read -s adminpass
echo "Site administrator email address:"
read -e adminemail
echo "Site url:"
read -e siteurl

echo "Do basic hardening of wp-config? (y/n)"
read -e harden

echo "Do you want to install a new Nginx host? (y/n)"
read -e installnginx

echo "Last chance - sure you want to run the install? (y/n)"
read -e run
if [ "$run" == y ] ; then
	if [ "$setupmysql" == y ] ; then
		echo "============================================"
		echo "Setting up the database."
		echo "============================================"
		#login to MySQL, add database, add user and grant permissions
		dbsetup="create database $dbname;GRANT ALL PRIVILEGES ON $dbname.* TO $dbuser@$mysqlhost IDENTIFIED BY '$dbpass';FLUSH PRIVILEGES;"
		mysql -u $mysqluser -p$mysqlpass -e "$dbsetup"
		if [ $? != "0" ]; then
			echo "============================================"
			echo "[Error]: Database creation failed. Aborting."
			echo "============================================"
			exit 1
		fi
	fi
	echo "============================================"
	echo "Installing WordPress for you."
	echo "============================================"



#download wordpress

mkdir "$sitestore"/"$domain" && cd "$sitestore"/"$domain"

echo "Downloading the latest version of WordPress"
wp core download --allow-root

# wp cli edit config
echo "Configuring WordPress configuration"
wp core config --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass --dbprefix=$dbprefix --locale=$wplocale --allow-root

# wp cli add administrator credentials
wp core install --url=$siteurl --title=$sitetitle --admin_user=$adminusername --admin_password=$adminpass --admin_email=$adminemail --allow-root

if [ "$harden" == y ] ; then
                echo "============================================"
                echo "Basic WordPress hardening."
                echo "============================================"
		rm $sitestore/$domain/license.txt $sitestore/$domain/readme.html
fi


        if [ "$installnginx" == y ] ; then
                echo "============================================"
                echo "Creating Nginx host."
                echo "============================================"
# make new vhost
echo "Creating new Nginx host"
cat > /etc/nginx/sites-available/$domain <<EOF
server {
	server_name $domain;
	listen 80;
        port_in_redirect off;
	access_log   /var/log/nginx/$domain.access.log;
	error_log    /var/log/nginx/$domain.error.log;
	root $sitestore/$domain;
	index index.html index.php;
	location / {
		try_files \$uri \$uri/ /index.php?\$args;
	}
	# Cache static files for as long as possible
	location ~*.(ogg|ogv|svg|svgz|eot|otf|woff|mp4|ttf|css|rss|atom|js|jpg|jpeg|gif|png|ico|zip|tgz|gz|rar|bz2|doc|xls|exe|ppt|tar|mid|midi|wav|bmp|rtf|cur)$ {
        expires max;
        log_not_found off;
        access_log off;
	}

	# Deny public access to wp-config.php
	location ~* wp-config.php {
		deny all;
	}

	location ~ \.php\$ {
		try_files \$uri =404;
		include fastcgi_params;
		fastcgi_pass unix:/run/php/php7.0-fpm.sock;
		fastcgi_split_path_info ^(.+\.php)(.*)\$;
		fastcgi_param  SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
	}
}
EOF
# symlink for vhost
sudo ln -s /etc/nginx/sites-available/"$domain" /etc/nginx/sites-enabled/"$domain"
# restart nginx
echo "Restarting Nginx"
sudo service nginx restart


        fi


	echo "Changing permissions..."
sudo chown -R  www-data:www-data $sitestore/$domain
sudo find $sitestore/$domain -type d -exec chmod 755 {} +
sudo find $sitestore/$domain -type f -exec chmod 644 {} +
	echo "========================="
	echo "[Success]: Installation is complete."
	echo "========================="

fi
