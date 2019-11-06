#!/bin/bash
# /********************************************************************
# HTTP2 Benchmark Modify Server for to uninstall ModSecurity script
# *********************************************************************/
CMDFD='/opt'
ENVFD="${CMDFD}/env"
ENVLOG="${ENVFD}/server/environment.log"
CUSTOM_WP="${ENVFD}/custom_wp"
SERVERACCESS="${ENVFD}/serveraccess.txt"
DOCROOT='/var/www/html'
NGDIR='/etc/nginx'
#APADIR='/etc/apache2'
LSDIR='/usr/local/entlsws'
OLSDIR='/usr/local/lsws'
#CADDIR='/etc/caddy'
#HTODIR='/etc/h2o'
#FPMCONF='/etc/php-fpm.d/www.conf'
USER='www-data'
GROUP='www-data'
#CERTDIR='/etc/ssl'
#MARIAVER='10.3'
#PHP_P='7'
#PHP_S='2'
REPOPATH=''
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
SERVER_LIST="lsws nginx openlitespeed"
#DOMAIN_NAME='benchmark.com'
#WP_DOMAIN_NAME='wordpress.benchmark.com'
declare -A WEB_ARR=( [lsws]=wp_lsws [nginx]=wp_nginx [openlitespeed]=wp_openlitespeed )

TEMP_DIR="${SCRIPTPATH}/temp"
OWASP_DIR="${TEMP_DIR}/owasp"

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

check_system(){
    if [ -f /etc/redhat-release ] ; then
        grep -i fedora /etc/redhat-release >/dev/null 2>&1
        if [ ${?} = 1 ]; then
            OSNAME=centos
            USER='apache'
            GROUP='apache'
            REPOPATH='/etc/yum.repos.d'
            APACHENAME='httpd'
            APADIR='/etc/httpd'
            RED_VER=$(rpm -q --whatprovides redhat-release)
        else
            fail_exit "Please use CentOS or Ubuntu OS"
        fi    
    elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
        OSNAME=ubuntu 
        REPOPATH='/etc/apt/sources.list.d'
        APACHENAME='apache2'
        FPMCONF="/etc/php/${PHP_P}.${PHP_S}/fpm/pool.d/www.conf"
    else 
        fail_exit 'Please use CentOS or Ubuntu OS'
    fi      
}
check_system

KILL_PROCESS(){
    PROC_NUM=$(pidof ${1})
    if [ ${?} = 0 ]; then
        kill -9 ${PROC_NUM}
    fi    
}

backup_old(){
    if [ -f ${1} ] && [ ! -f ${1}_old ]; then
       mv ${1} ${1}_old
    fi
}

checkweb(){
    if [ ${1} = 'lsws' ] || [ ${1} = 'ols' ]; then
        ps -ef | grep lshttpd | grep -v grep >/dev/null 2>&1
    else
        ps -ef | grep "${1}" | grep -v grep >/dev/null 2>&1
    fi    
    if [ ${?} = 0 ]; then 
        echoG "${1} process is running!"
        echoG 'Stop web service temporary'
        if [ "${1}" = 'lsws' ]; then 
           PROC_NAME='lshttpd'
            silent ${LSDIR}/bin/lswsctrl stop
            ps aux | grep '[w]swatch.sh' >/dev/null 2>&1
            if [ ${?} = 0 ]; then
                kill -9 $(ps aux | grep '[w]swatch.sh' | awk '{print $2}')
            fi    
        elif [ "${1}" = 'ols' ]; then 
            PROC_NAME='lshttpd'
            silent ${OLSDIR}/bin/lswsctrl stop  
        elif [ "${1}" = 'nginx' ]; then 
            PROC_NAME='nginx'
            silent service ${PROC_NAME} stop
        elif [ "${1}" = 'httpd' ]; then
            PROC_NAME='httpd'
            silent systemctl stop ${PROC_NAME}
        elif [ "${1}" = 'apache2' ]; then
            PROC_NAME='apache2' 
            silent systemctl stop ${PROC_NAME}
        elif [ "${1}" = 'h2o' ]; then
            PROC_NAME='h2o' 
            silent systemctl stop ${PROC_NAME}
        fi
        sleep 5
        if [ $(systemctl is-active ${PROC_NAME}) != 'active' ]; then 
            echoG "[OK] Stop ${PROC_NAME} service"
        else 
            echoR "[Failed] Stop ${PROC_NAME} service"
        fi 
    else 
        echoR '[ERROR] Failed to start the web server.'
        ps -ef | grep ${PROC_NAME} | grep -v grep
    fi 
}

change_owner(){
    chown -R ${USER}:${GROUP} ${1}
}

validate_servers(){
    if [ ! -f $SERVERACCESS -o ! -d $NGDIR -o ! -d $LSDIR ] ; then
        fail_exit_fatal 'Successfully install http2benchmark before installing ModSecurity for it'
    fi
    #if [ ! -d $TEMP_DIR -o ! -d $OWASP_DIR ] ; then
    #    fail_exit_fatal 'Run modsec.sh before running uninstall'
    #fi
}

validate_user(){
    if [ "$EUID" -ne 0 ] ; then
        fail_exit 'You must run this script as root'
    fi
}

uninstall_prereq(){
    if [ ${OSNAME} = 'centos' ]; then
        yum group install "Development Tools" -y
        yum install geoip geoip-devel yajl lmdb -y
    else
        apt install build-essential
        apt install libgeoip1 libgeoip-dev geoip-bin libyajl-dev lmdb-utils
    fi    
}

install_owasp(){
    if [ -d "$OWASP_DIR" ] ; then
        echoG "[OK] OWASP already installed"
        return 0
    fi
    if [ ! -x "${SCRIPTPATH}/install_owasp.sh" ] ; then
        fail_exit "[ERROR] Missing ${SCRIPTPATH}/install_owasp.sh script"
    fi
    PGM="${SCRIPTPATH}/install_owasp.sh"
    PARM1="${OWASP_DIR}"
    $PGM $PARM1
    if [ $? -gt 0 ] ; then
        fail_exit "install_owasp failed"
    fi
}

install_nginxModSec(){
    if [ -f $NGDIR/modules/ngx_http_modsecurity_module.so ] ; then
        echoG 'Nginx modsecurity module already compiled and installed'
        return 0
    fi
    if [ ! -x "${SCRIPTPATH}/install_nginx_modsec.sh" ] ; then
        fail_exit "[ERROR] Missing ${SCRIPTPATH}/install_owasp.sh script"
    fi
    PGM="${SCRIPTPATH}/install_nginx_modsec.sh"
    PARM2="${TEMP_DIR}"
    PARM1="${OWASP_DIR}"
    $PGM $PARM1 $PARM2
    if [ $? -gt 0 ] ; then
        fail_exit "install Nginx failed"
    fi
}

unconfig_nginxModSec(){
    grep ngx_http_modsecurity_module.so $NGDIR/nginx.conf
    if [ $? -ne 0 ] ; then
        echoG "Nginx already unconfigured for modsecurity"
        return 0
    fi
    PGM="${SCRIPTPATH}/unconfig_nginx_modsec.sh"
    PARM2="${TEMP_DIR}"
    PARM1="${OWASP_DIR}"
    $PGM $PARM1 $PARM2 $NGDIR
    if [ $? -gt 0 ] ; then
        fail_exit "unconfig Nginx failed"
    fi
}

unconfig_lswsModSec(){
    grep '<enableCensorship>0</enableCensorship>' $LSDIR/conf/httpd_config.xml
    if [ $? -eq 0 ] ; then
        echoG "LSWS already unconfigured for modsecurity"
        return 0
    fi
    PGM="${SCRIPTPATH}/unconfig_lsws_modsec.sh"
    PARM2="${TEMP_DIR}"
    PARM1="${OWASP_DIR}"
    $PGM $PARM1 $PARM2 $LSDIR
    if [ $? -gt 0 ] ; then
        fail_exit "unconfig lsws failed"
    fi
}

main(){
    validate_servers
    validate_user
    unconfig_lswsModSec
    unconfig_nginxModSec
    rm -rf $TEMP_DIR
    #uninstall_nginxModSec
    #uninstall_owasp
    #uninstall_prereq
}
main