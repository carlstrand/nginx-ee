#!/usr/bin/env bash

set -xu

#---------------------------------------------------------------------
# install bad bot protection
#---------------------------------------------------------------------

function bots() {
    # https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker
    
    mkdir -p /etc/nginx/sites-available
    cd /usr/sbin || exit
    wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -O install-ngxblocker
    wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/setup-ngxblocker -O setup-ngxblocker
    wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/update-ngxblocker -O update-ngxblocker
    chmod +x install-ngxblocker
    chmod +x setup-ngxblocker
    chmod +x update-ngxblocker
    install-ngxblocker -x
    setup-ngxblocker -x -w ${NGINX_DOCROOT}
    echo "OK: Clean up variables..."
    sed -i -e 's|^variables_hash_max_|#variables_hash_max_|g' /etc/nginx/conf.d/botblocker-nginx-settings.conf
}

#---------------------------------------------------------------------
# configure SSL
#---------------------------------------------------------------------

function openssl() {
    
    # The first argument is the bit depth of the dhparam, or 2048 if unspecified
    DHPARAM_BITS=${1:-2048}
    
    # If a dhparam file is not available, use the pre-generated one and generate a new one in the background.
    PREGEN_DHPARAM_FILE=/etc/letsencrypt/dhparam.pem.default
    DHPARAM_FILE=/etc/letsencrypt/dhparam.pem
    GEN_LOCKFILE=/tmp/dhparam_generating.lock
    
    if [[ ! -f ${PREGEN_DHPARAM_FILE} ]]; then
        echo "OK: NO PREGEN_DHPARAM_FILE is present. Generate ${PREGEN_DHPARAM_FILE}..."
        nice -n +5 openssl dhparam -out ${DHPARAM_FILE} 2048 2>&1
    fi
    
    if [[ ! -f ${DHPARAM_FILE} ]]; then
        # Put the default dhparam file in place so we can start immediately
        echo "OK: NO DHPARAM_FILE present. Copy ${PREGEN_DHPARAM_FILE} to ${DHPARAM_FILE}..."
        cp ${PREGEN_DHPARAM_FILE} ${DHPARAM_FILE}
        touch ${GEN_LOCKFILE}
        
        # The hash of the pregenerated dhparam file is used to check if the pregen dhparam is already in use
        PREGEN_HASH=$(md5sum ${PREGEN_DHPARAM_FILE} | cut -d" " -f1)
        CURRENT_HASH=$(md5sum ${DHPARAM_FILE} | cut -d" " -f1)
        if [[ "${PREGEN_HASH}" != "${CURRENT_HASH}" ]]; then
            nice -n +5 openssl dhparam -out ${DHPARAM_FILE} ${DHPARAM_BITS} 2>&1
            rm ${GEN_LOCKFILE}
        fi
    fi
    
    # Add Let's Encrypt CA in case it is needed
    mkdir -p /etc/ssl/private
    cd /etc/ssl/private || exit
    wget -O - https://letsencrypt.org/certs/isrgrootx1.pem https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.pem https://letsencrypt.org/certs/letsencryptauthorityx1.pem https://www.identrust.com/certificates/trustid/root-download-x3.html | tee -a ca-certs.pem> /dev/null
    
}

function run() {
   # environment
    openssl
   # if [[ ${NGINX_DEV_INSTALL} = "true" ]]; then dev; fi
  #  config
    bots
   # monit
}

run

exec "$@"