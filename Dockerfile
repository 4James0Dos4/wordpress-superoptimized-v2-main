# Dichiara gli ARG prima del FROM
ARG OPENLITESPEED_VERSION=1.8.2
ARG PHP_VERSION=82

FROM litespeedtech/openlitespeed:${OPENLITESPEED_VERSION}-lsphp${PHP_VERSION}

# Altri argomenti build

ARG RELAY_VERSION=v0.8.0
ARG RELAY_PHP_VERSION=8.2
ARG PLATFORM=x86-64
ARG PHP_VERSION=82

# Imposta le directory PHP
ENV PHP_EXT_DIR=/usr/local/lsws/lsphp${PHP_VERSION}/lib/php/20220829
ENV PHP_INI_DIR=/usr/local/lsws/lsphp${PHP_VERSION}/etc/php/8.2/mods-available/


# Installa dipendenze essenziali
RUN apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoremove -y && apt-get clean \
    wget \
    wait-for-it \
    gettext-base \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Copia il template del php.ini
COPY config/php.ini.template /usr/local/lsws/lsphp${PHP_VERSION}/etc/php/8.2/litespeed/php.ini

# Download Relay
RUN curl -L "https://builds.r2.relay.so/${RELAY_VERSION}/relay-${RELAY_VERSION}-php${RELAY_PHP_VERSION}-debian-${PLATFORM}+libssl3.tar.gz" | tar xz -C /tmp

# Copy relay.{so,ini} e configura secondo documentazione
RUN cp "/tmp/relay-${RELAY_VERSION}-php${RELAY_PHP_VERSION}-debian-${PLATFORM}+libssl3/relay.ini" "${PHP_INI_DIR}/60-relay.ini" \
    && cp "/tmp/relay-${RELAY_VERSION}-php${RELAY_PHP_VERSION}-debian-${PLATFORM}+libssl3/relay-pkg.so" "${PHP_EXT_DIR}/relay.so" \
    && sed -i "s/00000000-0000-0000-0000-000000000000/$(cat /proc/sys/kernel/random/uuid)/" "${PHP_EXT_DIR}/relay.so" \
    && sed -i 's/^relay.maxmemory = .*/relay.maxmemory = 128M/' "${PHP_INI_DIR}/60-relay.ini" \
    && sed -i 's/^relay.eviction_policy = .*/relay.eviction_policy = noeviction/' "${PHP_INI_DIR}/60-relay.ini" \
    && sed -i 's/^relay.environment = .*/relay.environment = production/' "${PHP_INI_DIR}/60-relay.ini" \
    && sed -i 's/^relay.databases = .*/relay.databases = 16/' "${PHP_INI_DIR}/60-relay.ini" \
    && sed -i 's/^relay.maxmemory_pct = .*/relay.maxmemory_pct = 95/' "${PHP_INI_DIR}/60-relay.ini" \
    && rm -rf /tmp/relay*

ARG WORDPRESS_VERSION=6.6.2   
# Scarica e configura WordPress
RUN cd /var/www/vhosts/localhost/ \
    && wget https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz \
    && tar -xzf wordpress-${WORDPRESS_VERSION}.tar.gz \
    && rm wordpress-${WORDPRESS_VERSION}.tar.gz \
    && mv wordpress/* html/ \
    && rm -rf wordpress \
    && chown -R nobody:nogroup html/

# Installa WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Copia gli script
COPY scripts/ /var/www/scripts/

# Rendiamo gli script eseguibili
RUN chmod +x /var/www/scripts/*.sh

# Impostiamo l'ENTRYPOINT
ENTRYPOINT ["/var/www/scripts/docker-entrypoint.sh"]
CMD ["/usr/local/lsws/bin/lswsctrl", "start", "-n"]

# Aggiorna i pacchetti e installa le versioni sicure per Ubuntu 24.04
RUN apt-get update && apt-get install -y \
    python3.12=3.12.3-1ubuntu0.3 \
    libglib2.0-0=2.80.0-6ubuntu3.2 \
    curl=8.5.0-2ubuntu10.5 \
    mysql-server=8.0.40-0ubuntu0.24.04.1 \
    mysql-client=8.0.40-0ubuntu0.24.04.1 \
    ghostscript=10.02.1~dfsg1-0ubuntu7.4 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Installa gli aggiornamenti di sicurezza
RUN apt-get update && apt-get install -y \
    ca-certificates \
    gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Imposta permessi restrittivi
RUN chmod 644 /etc/apt/sources.list.d/* \
    && chmod 644 /etc/apt/sources.list
