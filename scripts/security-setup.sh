#!/bin/bash

# Configurazione logging più robusta
if [ ! -d "/var/log/wordpress" ]; then
    mkdir -p /var/log/wordpress
fi

LOGFILE="/var/log/wordpress/security-setup.log"
exec 1> >(tee -a "$LOGFILE") 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') Starting security setup script..."

# Verifichiamo che WP-CLI sia disponibile
if ! command -v wp &> /dev/null; then
    echo "ERROR: wp-cli non è installato"
    exit 1
fi

# Verifichiamo che WordPress sia installato
if ! wp core is-installed --allow-root; then
    echo "ERROR: WordPress non è ancora installato"
    exit 1
fi

# Verifichiamo i permessi
if [ ! -w "/var/www/vhosts/localhost/html" ]; then
    echo "ERROR: Permessi insufficienti sulla directory di WordPress"
    exit 1
fi

# Disabilita tutti gli aggiornamenti automatici
echo "Disabling automatic updates..."
wp config set WP_AUTO_UPDATE_CORE false --raw --allow-root
wp config set AUTOMATIC_UPDATER_DISABLED true --raw --allow-root
wp config set WP_AUTO_UPDATE_PLUGINS false --raw --allow-root
wp config set WP_AUTO_UPDATE_THEMES false --raw --allow-root
wp config set DISALLOW_FILE_MODS true --raw --allow-root  # Disabilita anche l'installazione di plugin/temi
wp config set DISALLOW_FILE_EDIT true --raw --allow-root  # Disabilita l'editor di file nel backend

# Disabilita gli aggiornamenti tramite wp-cli
wp config set WP_CLI_DISABLE_AUTO_CHECK_UPDATE true --raw --allow-root

echo "Automatic updates disabled successfully"

# Rimuovi plugin non necessari
echo "Removing unnecessary plugins..."
wp plugin delete akismet --allow-root
wp plugin delete hello --allow-root

# Verifica se le variabili d'ambiente sono impostate
if [ "${ENABLE_MODSECURITY}" = "true" ]; then
    echo "Enabling ModSecurity..."
    # Configurazione ModSecurity
fi

if [ "${ENABLE_RATE_LIMITING}" = "true" ]; then
    echo "Enabling Rate Limiting..."
    # Configurazione Rate Limiting
fi

if [ "${ENABLE_IP_ACCESS_CONTROL}" = "true" ]; then
    echo "Enabling IP Access Control..."
    # Configurazione IP Access Control
fi

# Rimuoviamo la parte di fail2ban da qui poiché ora è gestita dal container dedicato

# Funzione per installare e configurare LiteSpeed Cache
setup_litespeed_cache() {
    wp plugin install litespeed-cache --activate --allow-root

    # Cache Settings
    wp litespeed-option set cache true --allow-root
    wp litespeed-option set cache-priv true --allow-root
    wp litespeed-option set cache-commenter true --allow-root
    wp litespeed-option set cache-rest true --allow-root
    wp litespeed-option set cache-page_login true --allow-root
    wp litespeed-option set cache-favicon true --allow-root
    wp litespeed-option set cache-resources true --allow-root
    wp litespeed-option set cache-mobile true --allow-root
    wp litespeed-option set cache-browser true --allow-root

    # TTL Settings
    wp litespeed-option set cache-ttl_pub 604800 --allow-root
    wp litespeed-option set cache-ttl_priv 1800 --allow-root
    wp litespeed-option set cache-ttl_frontpage 604800 --allow-root
    wp litespeed-option set cache-ttl_feed 604800 --allow-root

    # Purge Settings
    wp litespeed-option set purge-upgrade true --allow-root
    wp litespeed-option set purge-stale true --allow-root

    # ESI Settings
    wp litespeed-option set esi true --allow-root
    wp litespeed-option set esi-cache_admbar true --allow-root
    wp litespeed-option set esi-cache_commform true --allow-root

    # Optimization Settings
    wp litespeed-option set optm-css_min true --allow-root
    wp litespeed-option set optm-css_comb true --allow-root
    wp litespeed-option set optm-css_async true --allow-root
    wp litespeed-option set optm-js_min true --allow-root
    wp litespeed-option set optm-js_comb true --allow-root
    wp litespeed-option set optm-js_defer true --allow-root
    wp litespeed-option set optm-html_min true --allow-root
    wp litespeed-option set optm-qs_rm true --allow-root
    wp litespeed-option set optm-ggfonts_rm true --allow-root

    # Media Settings
    wp litespeed-option set img_optm-auto true --allow-root
    wp litespeed-option set img_optm-webp true --allow-root
    wp litespeed-option set media-lazy true --allow-root
    wp litespeed-option set media-iframe_lazy true --allow-root

    # Crawler Settings
    wp litespeed-option set crawler true --allow-root
    wp litespeed-option set crawler-usleep 500 --allow-root
    wp litespeed-option set crawler-run_duration 400 --allow-root
    wp litespeed-option set crawler-threads 3 --allow-root

    # Database Optimization
    wp litespeed-option set db_optm-revisions_max 50 --allow-root
    wp litespeed-option set db_optm-revisions_age 30 --allow-root
}

# Funzione per installare e configurare plugin di sicurezza
setup_security_plugins() {

    # WP Security Audit Log
    wp plugin install wp-security-audit-log --allow-root

}

# Funzione per installare e configurare plugin di ottimizzazione
#setup_optimization_plugins() {}

# Funzione per installare plugin/temi di default
setup_custom_plugins() {
    echo "Installing custom plugins..."
    
    # Array di URL dei plugin da installare
    declare -a plugin_urls=(
        "https://minio-ls8g4sowggsso880wccww44c.app.rewamp.it/pluginaifb/breakdance.zip"  # Breakdance
        "https://minio-ls8g4sowggsso880wccww44c.app.rewamp.it/pluginaifb/697144_wpmu-dev-dashboard-4.11.28.zip"  # WPMUDEV DASHBOARD
        # Aggiungi altri URL qui
    )

    # Installa ogni plugin dall'URL
    for url in "${plugin_urls[@]}"; do
        echo "Installing plugin from: $url"
        if wp plugin install "$url" --force --allow-root; then
            echo "Successfully installed plugin from: $url"
        else
            echo "Failed to install plugin from: $url - skipping..."
        fi
    done
}

# Funzione per installare e configurare temi
setup_custom_themes() {
    echo "Installing custom themes..."
    
    # Array di URL dei temi da installare
    declare -a theme_urls=(
        "https://minio-ls8g4sowggsso880wccww44c.app.rewamp.it/pluginaifb/breakdance-zero-theme-master.zip"  # breakdance zero theme
        # Aggiungi altri URL qui
    )

    # Installa ogni tema dall'URL
    for url in "${theme_urls[@]}"; do
        echo "Installing theme from: $url"
        if wp theme install "$url" --force --allow-root; then
            echo "Successfully installed theme from: $url"
        else
            echo "Failed to install theme from: $url - skipping..."
        fi
    done
}

# Esegui le configurazioni
setup_litespeed_cache
setup_security_plugins
#setup_optimization_plugins
setup_custom_plugins
setup_custom_themes

# Pulisci la cache dopo le installazioni
wp cache flush --allow-root

echo "Security setup completed successfully!"