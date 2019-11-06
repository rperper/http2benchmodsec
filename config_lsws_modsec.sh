#!/bin/bash
# /********************************************************************
# HTTP2 Benchmark Modify Server for ModSecurity config Lsws modsec
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
LSDIR="${3}"

config_lswsModSec(){
    grep '<enableCensorship>1</enableCensorship>' $LSDIR/conf/httpd_config.xml
    if [ $? -eq 0 ] ; then
        echoG "LSWS already configured for modsecurity"
        return 0
    fi
    cp -f $LSDIR/conf/httpd_config.xml $LSDIR/conf/httpd_config.xml.nomodsec
    sed -i "s=<enableCensorship>0</enableCensorship>=<enableCensorship>1</enableCensorship>=" $LSDIR/conf/httpd_config.xml
    sed -i "s=</censorshipControl>=</censorshipControl>\n    <censorshipRuleSet>\n      <name>ModSec</name>\n      <enabled>1</enabled>\n      <ruleSet>include $OWASP_DIR/modsec_includes.conf</ruleSet>\n    </censorshipRuleSet>" $LSDIR/conf/httpd_config.xml
}

config_lswsModSec
