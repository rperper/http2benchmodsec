#!/bin/bash
# /********************************************************************
# HTTP2 Benchmark Modify Server for ModSecurity config Apache modsec
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
APADIR="${3}"

config_apacheModSec(){
    silent grep "$OWASP_DIR" $APADIR/conf.d/mod_security.conf
    if [ $? -eq 0 ] ; then
        echoG "Apache already configured for modsecurity"
        return 0
    fi
    if [ -f $APADIR/conf.d/mod_security.conf ] ; then
        cp -f $APADIR/conf.d/mod_security.conf $APADIR/conf.d/mod_security.conf.nomodsec
    fi
    echo -e "<IfModule mod_security2.c>\n    # http2Benchmark OWASP Rules\n        SecDataDir $OWASP_DIR/owasp-modsecurity-crs/rules\n    #Include $OWASP_DIR/modsec_includes.conf\n    Include $OWASP_DIR/modsecurity.conf\n    Include $OWASP_DIR/owasp-modsecurity-crs/crs-setup.conf\n    Include $OWASP_DIR/owasp-modsecurity-crs/rules/*.conf\n</IfModule>\n" > $APADIR/conf.d/mod_security.conf
}

config_apacheModSec
