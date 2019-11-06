#!/bin/bash
# /********************************************************************
# HTTP2 Benchmark Modify Server for ModSecurity config Nginx modsec
# *********************************************************************/

silent() {
  if [[ $debug ]] ; then
    "$@"
  else
    "$@" >/dev/null 2>&1
  fi
}

### Tools
echoY() {
    echo -e "\033[38;5;148m${1}\033[39m"
}
echoG() {
    echo -e "\033[38;5;71m${1}\033[39m"
}
echoR()
{
    echo -e "\033[38;5;203m${1}\033[39m"
}

fail_exit(){
    echoR "${1}"
}

fail_exit_fatal(){
    echoR "${1}"
    if [ $# -gt 1 ] ; then
        popd "+${2}"
    fi
    exit 1
}

if [ $# -ne 3 ] ; then
    fail_exit "Needs to be run by modsec.sh"
    exit 1
fi
TEMP_DIR="${1}"
OWASP_DIR="${2}"
NGDIR="${3}"

config_nginxModSec(){
    grep ngx_http_modsecurity_module.so $NGDIR/nginx.conf
    if [ $? -eq 0 ] ; then
        echoG "Nginx already configured for modsecurity"
        return 0
    fi
    cp -f $NGDIR/nginx.conf $NGDIR/nginx.conf.nomodsec
    cp -f $NGDIR/conf.d/default.conf $NGDIR/conf.d/default.conf.nomodsec
    cp -f $NGDIR/conf.d/wordpress.conf $NGDIR/conf.d/wordpress.conf.nomodsec
    sed -i '1iload_module modules/ngx_http_modsecurity_module.so;' $NGDIR/nginx.conf
    sed -i "s=server {=server {\n    modsecurity on;\n    modsecurity_rules_file $OWASP_DIR/modsec_includes.conf;=g" $NGDIR/conf.d/default.conf
    sed -i "s=server {=server {\n    modsecurity on;\n    modsecurity_rules_file $OWASP_DIR/modsec_includes.conf;=g" $NGDIR/conf.d/wordpress.conf
}

config_nginxModSec
