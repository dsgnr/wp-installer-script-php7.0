#!/usr/bin/env bash
# @author: Daniel Hand
# https://www.danielhand.io
#!/bin/bash -e

# Define site location
sitestore=/var/www

# Define wp-content folder name
wpcontent=lib

# Define name of new WP core folder
core=core

# Define colors for output
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

# Define default plugins to install. Please use plugin slugs and saparate using a space
WPPLUGINS=( wordpress-seo ewww-image-optimizer better-wp-security )

clear
echo "${green}============================================${reset}"
echo "${green}WordPress Install Script${reset}"
echo "${green}============================================${reset}"
echo "${green}Do you need to setup new MySQL database? (y/n)${reset}"
read -e setupmysql
if [ "$setupmysql" == y ] ; then
	echo "${green}MySQL Admin User: ${reset}"
	read -e mysqluser
	echo "${green}MySQL Admin Password: ${reset}"
	read -s mysqlpass
	echo "${green}MySQL Host (Enter for default 'localhost'): ${reset}"
	read -e mysqlhost
		mysqlhost=${mysqlhost:-localhost}
fi
echo "${green}Domain name of site (without www)${reset}"
read -e domain
echo "${green}Database Name:${reset}"
read -e dbname
echo "${green}Database User:${reset}"
read -e dbuser
read -s -p "${green}Database password:${reset}" dbpass
echo
read -s -p "${green}Database password (again):${reset}" dbpass2
while [ "$dbpass" != "$dbpass2" ];
do
    echo
    echo "${green}Passwords do not match! Please try again${reset}"
    read -s -p "${green}Database password: ${reset}" dbpass
    echo
    read -s -p "${green}Database password (again):${reset}" dbpass2
done
echo
echo "${green}Please enter the database prefix (with underscore afterwards) (Enter for default 'wp_'):${reset}"
read -e dbprefix
		dbprefix=${dbprefix:-wp_}
echo "${green}Please specify WP language (Enter for default 'en_GB'):${reset}"
read -e wplocale
		wplocale=${wplocale:-en_GB}
echo "${green}Site title:${reset}"
read -e sitetitle
echo "${green}Site administrator username:${reset}"
read -e adminusername

read -s -p "${green}Admin password:${reset}" adminpass
echo
read -s -p "${green}Admin password (again):${reset}" adminpass2
while [ "$adminpass" != "$adminpass2" ];
do
    echo "${red}Passwords do not match! Please try again${reset}"
    read -s -p "${green}Admin password: ${reset}" adminpass
    echo
    read -s -p "${green}Admin password (again):${reset}" adminpass2
done
echo
echo "${green}${green}Site administrator email address:${reset}"
read -e adminemail

echo "${green}Site url:${reset}"
read -e siteurl

echo "${green}Do basic hardening of wp-config? (y/n)${reset}"
read -e harden

echo "${green}Install default plugins? (y/n)${reset}"
read -e plugininstall

echo "${green}Do you want to install a new Nginx host? (y/n)${reset}"
read -e installnginx

echo "${green}Last chance - sure you want to run the install? (y/n)${reset}"
read -e run
if [ "$run" == y ] ; then
	if [ "$setupmysql" == y ] ; then
		echo "${green}============================================${reset}"
		echo "${green}Setting up the database.${reset}"
		echo "${green}============================================${reset}"
		#login to MySQL, add database, add user and grant permissions
		dbsetup="create database $dbname;GRANT ALL PRIVILEGES ON $dbname.* TO $dbuser@$mysqlhost IDENTIFIED BY '$dbpass';FLUSH PRIVILEGES;"
		mysql -u $mysqluser -p$mysqlpass -e "$dbsetup"
		if [ $? != "0" ]; then
			echo "${red}============================================${reset}"
			echo "${red}[Error]: Database creation failed. Aborting.${reset}"
			echo "${red}============================================${reset}"
			exit 1
		fi
	fi
	echo "${green}============================================${reset}"
	echo "${green}Installing WordPress for you.${reset}"
	echo "${green}============================================${reset}"



#download wordpress

mkdir $sitestore/$domain && cd $sitestore/$domain

echo "${green}Downloading the latest version of WordPress${reset}"
wp core download --allow-root

# wp cli edit config
echo "${green}Configuring WordPress configuration${reset}"
wp core config --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass --dbprefix=$dbprefix --locale=$wplocale --allow-root

# wp cli add administrator credentials
wp core install --url=$siteurl --title=$sitetitle --admin_user=$adminusername --admin_password=$adminpass --admin_email=$adminemail --allow-root

if [ "$harden" == y ] ; then
                echo "${green}============================================${reset}"
                echo "${green}Basic WordPress hardening.${reset}"
                echo "${green}============================================${reset}"
		rm $sitestore/$domain/license.txt $sitestore/$domain/readme.html $sitestore/$domain/wp-config-sample.php
		mv $sitestore/$domain/wp-content/ $sitestore/$domain/$wpcontent/
		mkdir $sitestore/$domain/$core
		mv $sitestore/$domain/* $sitestore/$domain/$core/.
		mv $sitestore/$domain/$core/$wpcontent $sitestore/$domain/$core/wp-config.php $sitestore/$domain/.
		cp $sitestore/$domain/$core/index.php $sitestore/$domain/index.php

# Edit the index.php file to work with the new core location
sed -i "s|/wp-blog-header.php|/core/wp-blog-header.php|g" $sitestore/$domain/index.php


# Edit the wp-config.php file to work with the new core and wp-content locations
sed -i "2i\
define( 'WP_CONTENT_DIR', '$sitestore/$domain/$wpcontent' );\
define( 'WP_CONTENT_URL', 'http://$domain/$wpcontent' );\
define('WP_HOME','http://$domain');\
define('WP_SITEURL','http://$domain/$core');" $sitestore/$domain/wp-config.php

fi

if [ "$plugininstall" == y ] ; then
                echo "${green}============================================${reset}"
                echo "${green}Installing default plugins.${reset}"
                echo "${green}============================================${reset}"
		wp plugin install ${WPPLUGINS[@]} --activate --allow-root
fi


        if [ "$installnginx" == y ] ; then
                echo "${green}============================================${reset}"
                echo "${green}Creating Nginx host.${reset}"
                echo "${green}============================================${reset}"
# make new vhost
echo "${green}Creating new Nginx host${reset}"
cat > /etc/nginx/sites-available/$domain <<EOF
server {
	server_name www.$domain $domain;
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
sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/$domain
# restart nginx
echo "${green}Restarting Nginx${reset}"
sudo service nginx restart


        fi


	echo "${green}Changing permissions...${reset}"
sudo chown -R  www-data:www-data $sitestore/$domain
sudo find $sitestore/$domain -type d -exec chmod 755 {} +
sudo find $sitestore/$domain -type f -exec chmod 644 {} +
	echo "${green}=========================${reset}"
	echo "${green}[Success]: Installation is complete.${reset}"
	echo "${green}Your new WordPress installation can be found at http://$domain${reset}"
	echo "${green}You can log in to your new WordPress installation here: http://$domain/wp-login.php${reset}"
	echo "${green}=========================${reset}"

fi
