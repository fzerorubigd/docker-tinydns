#!/bin/bash

set -euo pipefail

DNS_SERVER_IP=${DNS_SERVER_IP:-}
if [ -z "${DNS_SERVER_IP}" ]; then
    echo "DNS_SERVER_IP is required and must set it before using this"
    exit 1
fi

MYSQL_HOST=${VEGA_MYSQL_HOST:-${MYSQL_PORT_3306_TCP_ADDR:-}}
MYSQL_PORT=${VEGA_MYSQL_PORT:-${MYSQL_PORT_3306_TCP_PORT:-}}
MYSQL_PASS=${VEGA_MYSQL_PASS:-${MYSQL_ENV_MYSQL_ROOT_PASSWORD:-}}

if [ -z "${MYSQL_HOST}" ] || [ -z "${MYSQL_PORT}" ] || [ -z "${MYSQL_PASS}" ] ; then
    echo "must link this with a mariadb/mysql container or set the mysql credential via env"
    exit 1
fi

VEGA_PASSWORD=${VEGA_MYSQL_PASS:-pa55w0rd}
SUPPORT_EMAIL=${VEGA_SUPPORT_EMAIL:-vega@changeme.com}
SUPPORT_NAME=${VEGA_SUPPORT_NAME:-VegaDNS}

mysqladmin -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u root create vegadns --password=${MYSQL_PASS} || echo "Database already exists"

mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u root -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER ON vegadns.* TO 'vegadns'@'%' IDENTIFIED BY '${VEGA_PASSWORD}'" mysql --password=${MYSQL_PASS}

mkdir -p /var/www/html/vegadns_private/{templates_c,configs,cache,sessions}
chown -R www-data:www-data /var/www/html/vegadns_private
chmod -R 777 /var/www/html/vegadns_private

if [ "$1" = 'vegadns' ]; then
    rm -rf /var/www/html/src/config.php

    cat >> /var/www/html/src/config.php << EOFEOF
<?php
\$private_dirs = '/var/www/html/vegadns_private';

// Location of sessions dir
\$session_dir = "\$private_dirs/sessions";

// Location of smarty dirs
\$smarty->compile_dir = "\$private_dirs/templates_c";
\$smarty->configs_dir = "\$private_dirs/configs";
\$smarty->cache_dir = "\$private_dirs/cache";


// Mysql settings
// this is my hack to support for changing port
\$mysql_host = '${MYSQL_HOST};port=${MYSQL_PORT}';
\$mysql_user = 'vegadns';
\$mysql_pass = '${VEGA_PASSWORD}';
\$mysql_db = 'vegadns';

// Local URL
\$vegadns_url = 'http://127.0.0.1/';

// Contact info used in from/to addresses of email notifactions for inactive
// domains
\$supportname = "${SUPPORT_NAME}";
\$supportemail = "${SUPPORT_EMAIL}";

// Enable IPv6 support
\$use_ipv6 = false;

// Hosts allowed to access get_data
// These are a comma delimited list of IPv4 addresses
// Such a list could look like:
// \$trusted_hosts = '127.0.0.1,127.0.0.1,127.0.0.3';

\$trusted_hosts = '127.0.0.1';

// Set this to 1 if you don't want to limit access to get_data
\$trusted = 0;

// IP Address of the local tinydns instance.  This is the IP that will be used
// for dns lookups on authoritative information
\$tinydns_ip = '${DNS_SERVER_IP}';

// Records per page
\$per_page = 75;

// Session timeout time.  default: 3600 (1 hour)
\$timeout = 3600;

// Directory containing dnsq and dnsqr
\$dns_tools_dir = '/usr/bin';

// Set to true if you want to store sessions in mysql rather than in files
// (required when load balancing VegaDNS)
\$use_mysql_sessions = false;

// Set this to a record name you want to query for version information
// over a TXT record
// \$vegadns_generation_txt_record = "vegadns-generation.example.com";

/////////////////////////////////////
// NO NEED TO  EDIT BELOW THIS LINE //
/////////////////////////////////////

require_once 'version.php';

if(!preg_match('/.*\/index.php$/', \$_SERVER['PHP_SELF'])
    && !preg_match('/.*\/axfr_get.php$/', \$_SERVER['PHP_SELF'])) {
    header("Location:../index.php");
    exit;
}

?>
EOFEOF

    sed -i -e "s/^VEGADNS=.*/VEGADNS='http:\/\/127.0.0.1\/index.php'/g" /var/www/html/update-data.sh
    chmod a+x /var/www/html/update-data.sh

    /usr/bin/tinydns-conf Gtinydns Gdnslog /etc/tinydns ${DNS_SERVER_IP}
    /usr/bin/dnscache-conf Gdnscache Gdnslog /etc/dnscache 0.0.0.0


    mkdir -p /service
    ln -sf /etc/tinydns /service/tinydns
    ln -sf /etc/dnscache /service/dnscache

    /etc/init.d/apache2 start
    # then finally, tinydns
    /usr/bin/svscan /service&
    sleep 5
    # I don't beleve in cron :))) just run the update every 10 minute.
    while :
    do
        /var/www/html/update-data.sh
	    sleep 600
    done
else
    exec "$@"
fi;
