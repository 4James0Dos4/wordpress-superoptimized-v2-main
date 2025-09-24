allora il mio intento è quello di avere una docker image/docker file e dopo un docker compose che contenga

Wordpress ultima versione (6 o superiore)
php 8.2
Maria db ultima versione 11.4 (stabile)
PhpMyAdmin ultima versione
openlitespeed ultima versione
relay ultima versione
redis ultima versione(volendo redis possiamo agganciarla a wordpress senza includerla nella docker compose grazie al plugin di lightspeed stesso)

cè l'immagine di openlightspeed litespeedtech/openlitespeed:1.8.2-lsphp82 del solo server
Component Version
Linux Ubuntu 24.04
OpenLiteSpeed Latest stable version
PHP Latest stable version

che andrebbe combinata poi con mariadb e wordpress

relay per installarlo via docker dalla doc ufficiale dice

Using Docker
We have various Docker examples on GitHub. If you’re using the official PHP Docker images you can install Relay using the php-extension-installer:

FROM php:8.1-cli(ovviamente cambiando la versione di php)
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions relay

relay per open litespeed suggerisce COME ESEMPIO questo

FROM litespeedtech/openlitespeed:1.7.16-lsphp81(ovviamente cambiando la versione di php e openlitespeed)

# Instead of using `php-config` let's hard code these

ENV PHP_EXT_DIR=/usr/local/lsws/lsphp81/lib/php/20210902 (va usato php8.2)
ENV PHP_INI_DIR=/usr/local/lsws/lsphp81/etc/php/8.1/mods-available/ (va usato php8.2)

ARG RELAY=v0.8.1

# Download Relay

RUN PLATFORM=$(uname -m | sed 's/_/-/') \
  && curl -L "https://builds.r2.relay.so/$RELAY/relay-$RELAY-php8.1-debian-$PLATFORM%2Blibssl3.tar.gz" | tar xz -C /tmp ( va usato il file relay-v0.8.1-php8.2-debian-aarch64+libssl3.tar.gz)

# Copy relay.{so,ini}

RUN PLATFORM=$(uname -m | sed 's/_/-/') \
  && cp "/tmp/relay-$RELAY-php8.1-debian-$PLATFORM+libssl3/relay.ini" "$PHP_INI_DIR/60-relay.ini" \ (va cambiato il nome della directory in base alla versione del file di relay)
&& cp "/tmp/relay-$RELAY-php8.1-debian-$PLATFORM+libssl3/relay-pkg.so" "$PHP_EXT_DIR/relay.so" (va cambiato il nome della directory in base alla versione del file di relay)

# Inject UUID

RUN sed -i "s/00000000-0000-0000-0000-000000000000/$(cat /proc/sys/kernel/random/uuid)/" "$PHP_EXT_DIR/relay.so"

# Don't start `lswsctrl`

ENTRYPOINT [""]

poi ci deve essere un file php ini ottimizzato per wordpress con molti plugin e builder visuali come elementor e simili (non so se questo va nella docker compose)
il php ini deve essere ottimizzato per openlitespeed e con tutti i moduli necessari per cache e simili

inoltre in futuro potrei voler aggiungere lightspeed enterprise litespeedtech/litespeed:6.3.1-lsphp82 e quindi dovro sostituire openlitespeed con lightspeed enterprise nella docker compose
in quel caso anche relay andrebbe installato cosi come nell'esempio

docker build --pull --tag relay-litespeed --file litespeed.Dockerfile .
docker run -it relay-litespeed bash
$ php --ri relay

unesempio di compose quasi completo comprendente tutto fatto da lightspeed
qui ci sono altre info e dati https://github.com/litespeedtech/ols-docker-env?tab=readme-ov-file

services:
mysql:
image: mariadb:11.4
logging:
driver: none
command: ["--max-allowed-packet=512M"]
volumes: - "./data/db:/var/lib/mysql:delegated"
environment:
MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    restart: always
    networks:
      - default
  litespeed:
    image: litespeedtech/openlitespeed:${OLS_VERSION}-${PHP_VERSION}
container_name: litespeed
env_file: - .env
volumes: - ./lsws/conf:/usr/local/lsws/conf - ./lsws/admin-conf:/usr/local/lsws/admin/conf - ./bin/container:/usr/local/bin - ./sites:/var/www/vhosts/ - ./acme:/root/.acme.sh/ - ./logs:/usr/local/lsws/logs/
ports: - 80:80 - 443:443 - 443:443/udp - 7080:7080
restart: always
environment:
TZ: ${TimeZone}
networks: - default
phpmyadmin:
image: bitnami/phpmyadmin:5.2.0-debian-11-r43
ports: - 8080:8080 - 8443:8443
environment:
DATABASE_HOST: mysql
restart: always
networks: - default
redis:
image: "redis:alpine"
logging:
driver: none # command: redis-server --requirepass 8b405f60665e48f795752e534d93b722
volumes: - ./redis/data:/var/lib/redis - ./redis/redis.conf:/usr/local/etc/redis/redis.conf
environment: - REDIS_REPLICATION_MODE=master
restart: always
networks: - default
networks:
default:
driver: bridge

    ├── acme

├── bin
│ └── container
├── data
│ └── db
├── logs
│ ├── access.log
│ ├── error.log
│ ├── lsrestart.log
│ └── stderr.log
├── lsws
│ ├── admin-conf
│ └── conf
├── sites
│ └── localhost
├── LICENSE
├── README.md
└── docker-compose.yml
acme contains all applied certificates from Lets Encrypt

bin contains multiple CLI scripts to allow you add or delete virtual hosts, install applications, upgrade, etc

data stores the MySQL database

logs contains all of the web server logs and virtual host access logs

lsws contains all web server configuration files

sites contains the document roots (the WordPress application will install here)

FINE ESEMPIO COMPOSE

ESEMPIO SCRIPT BASH PER INSTALLARE WORDPRESS E DATABASE E DOMINIO

domain.sh
#!/usr/bin/env bash
CONT_NAME='litespeed'
EPACE=' '

echow(){
FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
echo -e "\033[1mOPTIONS\033[0m"
echow "-A, --add [domain_name]"
echo "${EPACE}${EPACE}Example: domain.sh -A example.com, will add the domain to Listener and auto create a new virtual host."
echow "-D, --del [domain_name]"
echo "${EPACE}${EPACE}Example: domain.sh -D example.com, will delete the domain from Listener."
echow '-H, --help'
echo "${EPACE}${EPACE}Display help and exit."  
}

check_input(){
if [ -z "${1}" ]; then
help_message
exit 1
fi
}

add_domain(){
check_input ${1}
    docker compose exec ${CONT_NAME} su -s /bin/bash lsadm -c "cd /usr/local/lsws/conf && domainctl.sh --add ${1}"
    if [ ! -d "./sites/${1}" ]; then
mkdir -p ./sites/${1}/{html,logs,certs}
fi
bash bin/webadmin.sh -r
}

del_domain(){
check_input ${1}
docker compose exec ${CONT_NAME} su -s /bin/bash lsadm -c "cd /usr/local/lsws/conf && domainctl.sh --del ${1}"
bash bin/webadmin.sh -r
}

check_input ${1}
while [ ! -z "${1}" ]; do
case ${1} in -[hH] | -help | --help)
help_message
;; -[aA] | -add | --add) shift
add_domain ${1}
;; -[dD] | -del | --del | --delete) shift
del_domain ${1}
;;  
 \*)
help_message
;;  
 esac
shift
done

database.sh
#!/usr/bin/env bash
source .env

DOMAIN=''
SQL_DB=''
SQL_USER=''
SQL_PASS=''
ANY="'%'"
SET_OK=0
EPACE=' '
METHOD=0

echow(){
FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
echo -e "\033[1mOPTIONS\033[0m"
echow '-D, --domain [DOMAIN_NAME]'
echo "${EPACE}${EPACE}Example: database.sh -D example.com"
echo "${EPACE}${EPACE}Will auto-generate Database/username/password for the domain"
echow '-D, --domain [DOMAIN_NAME] -U, --user [xxx] -P, --password [xxx] -DB, --database [xxx]'
echo "${EPACE}${EPACE}Example: database.sh -D example.com -U USERNAME -P PASSWORD -DB DATABASENAME"
echo "${EPACE}${EPACE}Will create Database/username/password by given"
echow '-R, --delete -DB, --database [xxx] -U, --user [xxx]'
echo "${EPACE}${EPACE}Example: database.sh -r -DB DATABASENAME -U USERNAME"
echo "${EPACE}${EPACE}Will delete the database (require) and username (optional) by given"
echow '-H, --help'
echo "${EPACE}${EPACE}Display help and exit."
exit 0  
}

check_input(){
if [ -z "${1}" ]; then
help_message
exit 1
fi
}

specify_name(){
check_input ${SQL_USER}
check_input ${SQL_PASS}
check_input ${SQL_DB}
}

auto_name(){
SQL_DB="${TRANSNAME}"
    SQL_USER="${TRANSNAME}"
SQL_PASS="'${RANDOM_PASS}'"
}

gen_pass(){
RANDOM_PASS="$(openssl rand -base64 12)"
}

trans_name(){
TRANSNAME=$(echo ${1} | tr -d '.&&-')
}

display_credential(){
if [ ${SET_OK} = 0 ]; then
echo "Database: ${SQL_DB}"
echo "Username: ${SQL_USER}"
echo "Password: $(echo ${SQL_PASS} | tr -d "'")"
fi  
}

store_credential(){
if [ -d "./sites/${1}" ]; then
if [ -f ./sites/${1}/.db_pass ]; then
mv ./sites/${1}/.db_pass ./sites/${1}/.db_pass.bk
fi
cat > "./sites/${1}/.db_pass" << EOT
"Database":"${SQL_DB}"
"Username":"${SQL_USER}"
"Password":"$(echo ${SQL_PASS} | tr -d "'")"
EOT
    else
        echo "./sites/${1} not found, abort credential store!"
fi  
}

check_db_access(){
docker compose exec -T mysql su -c "mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e 'status'" >/dev/null 2>&1
if [ ${?} != 0 ]; then
echo '[X] DB access failed, please check!'
exit 1
fi  
}

check_db_exist(){
docker compose exec -T mysql su -c "test -e /var/lib/mysql/${1}"
if [ ${?} = 0 ]; then
echo "Database ${1} already exist, skip DB creation!"
exit 0  
 fi  
}

check_db_not_exist(){
docker compose exec -T mysql su -c "test -e /var/lib/mysql/${1}"
if [ ${?} != 0 ]; then
echo "Database ${1} doesn't exist, skip DB deletion!"
exit 0
fi
}

db_setup(){  
 docker compose exec -T mysql su -c 'mysql -uroot -p${MYSQL_ROOT_PASSWORD} \
    -e "CREATE DATABASE '${SQL_DB}';" \
 -e "GRANT ALL PRIVILEGES ON '${SQL_DB}'.* TO '${SQL_USER}'@'${ANY}' IDENTIFIED BY '${SQL_PASS}';" \
 -e "FLUSH PRIVILEGES;"'
SET_OK=${?}
}

db_delete(){
if [ "${SQL_DB}" == '' ]; then
echo "Database parameter is required!"
exit 0
fi
if [ "${SQL_USER}" == '' ]; then
SQL_USER="${SQL_DB}"
    fi
    check_db_not_exist ${SQL_DB}
    docker compose exec -T mysql su -c 'mysql -uroot -p${MYSQL_ROOT_PASSWORD} \
 -e "DROP DATABASE IF EXISTS '${SQL_DB}';" \
        -e "DROP USER IF EXISTS '${SQL_USER}'@'${ANY}';" \
 -e "FLUSH PRIVILEGES;"'
echo "Database ${SQL_DB} and User ${SQL_USER} are deleted!"
}

auto_setup_main(){
check_input ${DOMAIN}
gen_pass
trans_name ${DOMAIN}
auto_name
check_db_exist ${SQL_DB}
check_db_access
db_setup
display_credential
store_credential ${DOMAIN}
}

specify_setup_main(){
specify_name
check_db_exist ${SQL_DB}
check_db_access
db_setup
display_credential
store_credential ${DOMAIN}
}

main(){
if [ ${METHOD} == 1 ]; then
db_delete
exit 0
fi
if [ "${SQL_USER}" != '' ] && [ "${SQL_PASS}" != '' ] && [ "${SQL_DB}" != '' ]; then
specify_setup_main
else
auto_setup_main
fi
}

check_input ${1}
while [ ! -z "${1}" ]; do
case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -[dD] | -domain| --domain) shift
            DOMAIN="${1}"
;; -[uU] | -user | --user) shift
SQL_USER="${1}"
            ;;
        -[pP] | -password| --password) shift
            SQL_PASS="'${1}'"
;;  
 -db | -DB | -database| --database) shift
SQL_DB="${1}"
;; -[rR] | -del | --del | --delete)
METHOD=1
;;
\*)
help_message
;;  
 esac
shift
done
main

appinstall.sh

#!/usr/bin/env bash
APP_NAME=''
DOMAIN=''
EPACE=' '

echow(){
FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
echo -e "\033[1mOPTIONS\033[0m"
echow '-A, --app [app_name] -D, --domain [DOMAIN_NAME]'
echo "${EPACE}${EPACE}Example: appinstall.sh -A wordpress -D example.com"
echo "${EPACE}${EPACE}Will install WordPress CMS under the example.com domain"
echow '-H, --help'
echo "${EPACE}${EPACE}Display help and exit."
exit 0
}

check_input(){
if [ -z "${1}" ]; then
help_message
exit 1
fi
}

app_download(){
docker compose exec litespeed su -c "appinstallctl.sh --app ${1} --domain ${2}"
bash bin/webadmin.sh -r
exit 0
}

main(){
app_download ${APP_NAME} ${DOMAIN}
}

check_input ${1}
while [ ! -z "${1}" ]; do
case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -[aA] | -app | --app) shift
            check_input "${1}"
APP_NAME="${1}"
            ;;
        -[dD] | -domain | --domain) shift
            check_input "${1}"
DOMAIN="${1}"
;;  
 \*)
help_message
;;  
 esac
shift
done

main

FINE ESEMPIO SCRIPT BASH

CONSIDERAZIONI: questo compose di lightspeed che utilizza poi dei bash per installare database e wordpress andrebbe anche bene se non che mi rallenterebbe l'installazione di wordpress e database e salvo rari casi non lo utilizzerei mai per piu wordpress insieme e inoltre mancherebbe relay

Tieni conto che QUESTO E SOLO UN ESEMPIO, inoltre io installerò tutto tramite coolify 4 quindi questo esempio di lightspeed prevede che wordpress venga installato tramite script bash e che quindi questa stessa compose di lightspeed serve come contenitorte per piu database o wordpress, invece a me serve che wordpress sia incluso nella docker compose perche intendo installare un singolo wordpress e un singolo database per ogni dominio inoltre coolify gia include traefik e caddy per gestire il dominio e il certificato ssl

E come detto redis sarà agganciato a wordpress tramite plugin e non sarà incluso nella docker compose

come possiamo sistemare il tutto? anche perche non so come gestire poi i domini e i certificati ssl visto che coolify 4 li gestisce tramite traefik e caddy a monte
