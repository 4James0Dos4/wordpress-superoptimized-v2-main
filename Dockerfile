# ---- Build args before FROM ----
    ARG OPENLITESPEED_VERSION=1.8.2
    ARG PHP_VERSION=82
    
    # ---- Base image ----
    FROM litespeedtech/openlitespeed:${OPENLITESPEED_VERSION}-lsphp${PHP_VERSION}
    
    # ---- Build args ----
    ARG RELAY_VERSION=v0.8.0
    ARG RELAY_PHP_VERSION=8.2
    ARG PLATFORM=x86-64
    ARG WORDPRESS_VERSION=6.6.2
    
    # ---- ENV variables ----
    ENV PHP_VERSION=82
    ENV PHP_EXT_DIR=/usr/local/lsws/lsphp${PHP_VERSION}/lib/php/20220829
    ENV PHP_INI_DIR=/usr/local/lsws/lsphp${PHP_VERSION}/etc/php/8.2/mods-available/
    
    # ---- Install essential packages first (cache layer) ----
    RUN apt-get update && apt-get upgrade -y && \
        apt-get install -y wget curl tar gettext-base tzdata wait-for-it ca-certificates gnupg python3 python3-pip ghostscript && \
        apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*
    
    # ---- Copy php.ini template (cache layer) ----
    COPY config/php.ini.template /usr/local/lsws/lsphp${PHP_VERSION}/etc/php/8.2/litespeed/php.ini
    
    # ---- Download and install Relay (cache layer) ----
    RUN curl -L -o /tmp/relay.tar.gz \
        "https://builds.r2.relay.so/${RELAY_VERSION}/relay-${RELAY_VERSION}-php${RELAY_PHP_VERSION}-debian-${PLATFORM}+libssl3.tar.gz" && \
        tar -xzf /tmp/relay.tar.gz -C /tmp && \
        cp "/tmp/relay-${RELAY_VERSION}-php${RELAY_PHP_VERSION}-debian-${PLATFORM}+libssl3/relay.ini" "${PHP_INI_DIR}/60-relay.ini" && \
        cp "/tmp/relay-${RELAY_VERSION}-php${RELAY_PHP_VERSION}-debian-${PLATFORM}+libssl3/relay-pkg.so" "${PHP_EXT_DIR}/relay.so" && \
        sed -i "s/00000000-0000-0000-0000-000000000000/$(cat /proc/sys/kernel/random/uuid)/" "${PHP_EXT_DIR}/relay.so" && \
        sed -i 's/^relay.maxmemory = .*/relay.maxmemory = 128M/' "${PHP_INI_DIR}/60-relay.ini" && \
        sed -i 's/^relay.eviction_policy = .*/relay.eviction_policy = noeviction/' "${PHP_INI_DIR}/60-relay.ini" && \
        sed -i 's/^relay.environment = .*/relay.environment = production/' "${PHP_INI_DIR}/60-relay.ini" && \
        sed -i 's/^relay.databases = .*/relay.databases = 16/' "${PHP_INI_DIR}/60-relay.ini" && \
        sed -i 's/^relay.maxmemory_pct = .*/relay.maxmemory_pct = 95/' "${PHP_INI_DIR}/60-relay.ini" && \
        rm -rf /tmp/relay* /tmp/relay.tar.gz
    
    # ---- Install WordPress (cache layer) ----
    RUN mkdir -p /var/www/vhosts/localhost/html && cd /var/www/vhosts/localhost && \
        wget https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz && \
        tar -xzf wordpress-${WORDPRESS_VERSION}.tar.gz && rm wordpress-${WORDPRESS_VERSION}.tar.gz && \
        mv wordpress/* html/ && rm -rf wordpress && chown -R nobody:nogroup html/
    
    # ---- Install WP-CLI (cache layer) ----
    RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
        chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp
    
    # ---- Copy scripts last (frequent changes) ----
    COPY scripts/ /var/www/scripts/
    RUN chmod +x /var/www/scripts/*.sh
    
    # ---- Entry point ----
    ENTRYPOINT ["/var/www/scripts/docker-entrypoint.sh"]
    CMD ["/usr/local/lsws/bin/lswsctrl", "start", "-n"]
    
    # ---- Restrictive permissions ----
    RUN chmod 644 /etc/apt/sources.list.d/* && chmod 644 /etc/apt/sources.list
    