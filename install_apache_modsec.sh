#!/bin/bash
# /********************************************************************
# HTTP2 Benchmark Modify Server for ModSecurity install Apache modsec
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

if [ $# -ne 2 ] ; then
    fail_exit "Needs to be run by modsec.sh"
    exit 1
fi
APADIR="${1}"
OSNAME="${2}"
WD=$(pwd)

install_apacheModSec(){
    if [ -x "$APADIR/modules/mod_security2.so" ]; then
        echoG "Apache modsecurity module already installed"
        return 0
    fi
    if [ ${OSNAME} = 'centos' ]; then
        yum install mod_security -y
    else
        apt install libapache2-mod-security2
    fi
}

main(){
    install_apacheModSec
}
main
