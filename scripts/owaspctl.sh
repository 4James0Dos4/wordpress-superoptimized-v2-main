#!/bin/bash

# Enable/disable ModSecurity based on parameter
case "$1" in
    --enable)
        # Add commands to enable ModSecurity
        sed -i 's/modsecurity off/modsecurity on/' /usr/local/lsws/conf/httpd_config.conf
        echo "ModSecurity enabled"
        ;;
    --disable)
        # Add commands to disable ModSecurity
        sed -i 's/modsecurity on/modsecurity off/' /usr/local/lsws/conf/httpd_config.conf
        echo "ModSecurity disabled"
        ;;
    *)
        echo "Usage: $0 {--enable|--disable}"
        exit 1
        ;;
esac 