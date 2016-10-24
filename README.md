# WordPress bash installer script for PHP7.0-FPM

A small bash script to dynamically create a new WP installation, along with a new Nginx host file to really speed up your development. This script is designed for PHP 7.0 so if you are using PHP 5.6 please go to this script (Add link here). 

# Prerequisites

* Nginx
* PHP 7.0-FPM
* MySQL (or MariaDB)
* WP CLI

# What this script does

* Creates a new database (user defined)
* Creates a new database user with password (user defined)
* Create new nginx host file
* Create symlink and restart nginx
* Make a new directory in your $SITESTORE (default is /var/www)
* Download the latest version of WP
* Configure the database credentials in wp-config.php
* Configures the site as per user defined instructions
* Removes default WordPress files like readme.md, license.txt and wp-config-sample.php


# Want to improve this script?

If this script has helped you, or you think there are improvements to be made, please let me know!
