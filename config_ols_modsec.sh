#!/bin/bash
# /********************************************************************
# HTTP2 Benchmark Modify Server for ModSecurity config OpenLitespeed modsec
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
OLSDIR="${3}"

config_olsModSec(){
    grep 'module mod_security {' $OLSDIR/conf/httpd_config.conf
    if [ $? -eq 0 ] ; then
        echoG "OpenLitespeed already configured for modsecurity"
        return 0
    fi
    cp -f $OLSDIR/conf/httpd_config.conf $OLSDIR/conf/httpd_config.conf.nomodsec
    sed -i "s=module cache=module mod_security {\nmodsecurity  on\nmodsecurity_rules \`\nSecRuleEngine On\n\`\nmodsecurity_rules_file $OWASP_DIR/modsec_includes.conf\n  ls_enabled              1\n}\n\nmodule cache=" $OLSDIR/conf/httpd_config.conf
}

config_olsModSec
