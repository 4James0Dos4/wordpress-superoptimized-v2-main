#!/bin/bash

# Configurazione logging
LOGFILE="/var/log/wordpress/entrypoint.log"
mkdir -p /var/log/wordpress
exec 1> >(tee -a "$LOGFILE") 2>&1

# Creiamo il socket per il logging se non esiste
if [ ! -d "/dev" ]; then
    mkdir -p /dev
fi
if [ ! -S "/dev/log" ]; then
    mkfifo /dev/log
fi

# Funzione per verificare lo stato di OpenLiteSpeed
check_litespeed() {
    if ! pgrep litespeed > /dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: OpenLiteSpeed non è in esecuzione!"
        return 1
    fi
    return 0
}

# Attendiamo che MySQL sia pronto
until mysqladmin ping -h"$WORDPRESS_DB_HOST" --silent; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting up: Waiting for MySQL to be ready..."
    sleep 2
done

# Imposta il percorso corretto per WordPress
cd /var/www/vhosts/localhost/html

# Installiamo WordPress se non è già installato
if ! wp core is-installed --allow-root; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting up: Installing WordPress..."
    wp core install \
        --url="$SITE_URL" \
        --title="$SITE_TITLE" \
        --admin_user="$ADMIN_USER" \
        --admin_password="$ADMIN_PASSWORD" \
        --admin_email="$ADMIN_EMAIL" \
        --allow-root
fi

# Configure OpenLiteSpeed admin credentials
if [ ! -f "/usr/local/lsws/admin/conf/htpasswd" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting up: Configuring OpenLiteSpeed admin credentials..."
    # Create admin user
    /usr/local/lsws/admin/misc/admpass.sh << EOF
${OLS_ADMIN_USERNAME}
${OLS_ADMIN_PASSWORD}
${OLS_ADMIN_PASSWORD}
EOF
    echo "OpenLiteSpeed admin credentials configured."
fi

# Verifica e correggi i permessi
echo "$(date '+%Y-%m-%d %H:%M:%S') Checking and fixing permissions..."
chown -R nobody:nogroup /usr/local/lsws/conf/
chmod -R 755 /usr/local/lsws/conf/
chown -R nobody:nogroup /var/www/vhosts/localhost/html/
chmod -R 755 /var/www/vhosts/localhost/html/

# Eseguiamo il setup di sicurezza una sola volta
if [ ! -f "/var/www/security-setup.done" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting up: Running security setup..."
    if bash /var/www/scripts/security-setup.sh; then
        touch /var/www/security-setup.done
        echo "$(date '+%Y-%m-%d %H:%M:%S') Security setup completed successfully."
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Security setup failed!"
    fi
fi

# Avviamo OpenLiteSpeed
echo "$(date '+%Y-%m-%d %H:%M:%S') Starting up: Launching OpenLiteSpeed..."
/usr/local/lsws/bin/lswsctrl start

# Verifica iniziale
sleep 5
if ! check_litespeed; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: OpenLiteSpeed failed to start properly!"
    exit 1
fi

# Monitora OpenLiteSpeed
while true; do
    if ! check_litespeed; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: OpenLiteSpeed crashed, attempting restart..."
        /usr/local/lsws/bin/lswsctrl restart
        sleep 5
        if ! check_litespeed; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') CRITICAL: OpenLiteSpeed failed to restart!"
            exit 1
        fi
    fi
    sleep 10
done