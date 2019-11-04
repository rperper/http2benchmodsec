#!/bin/bash
# /********************************************************************
# HTTP2 Benchmark Modify Server for ModSecurity script
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
    if [ ! -f $SERVERACCESS -o ! -d $NGDIR -o ! -d $OLSDIR -o ! -d $LSDIR ] ; then
        fail_exit 'Successfully install http2benchmark before installing ModSecurity for it'
    fi
}

validate_user(){
    if [ "$EUID" -ne 0 ] ; then
        fail_exit 'You must run this script as root'
    fi
}

install_prereq(){
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

install_pcre(){
    pcre-config --version|grep 8.
    if [ $? -eq 0 ] ; then
        echoG "[OK] pcre already installed and new enough version"
        return 0
    fi
    wget ftp://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz
    tar -zxf pcre-8.43.tar.gz
    pushd pcre-8.43
    ./configure
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Configure of pcre failed" 1
    fi
    make
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Make of pcre failed" 1
    fi
    make install
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Install of pcre failed" 1
    fi
    popd 
}

install_zlib(){
    whereis libz.so.1|grep libz.so.1
    if [ $? -eq 0 ] ; then
        echoG "[OK] libz already installed and new enough version"
        return 0
    fi
    wget http://zlib.net/zlib-1.2.11.tar.gz
    tar -zxf zlib-1.2.11.tar.gz
    pushd zlib-1.2.11
    ./configure
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Configure of zlib failed" 1
    fi
    make
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Build of zlib failed" 1
    fi
    make install
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Install of zlib failed" 1
    fi
    popd
}

install_openssl(){
    openssl version|grep 1.1
    if [ $? -eq 0 ] ; then
        echoG "[OK] openssl already installed and new enough version"
        return 0
    fi
    wget http://www.openssl.org/source/openssl-1.1.1c.tar.gz
    tar -zxf openssl-1.1.1c.tar.gz
    pushd openssl-1.1.1c
    #./Configure darwin64-x86_64-cc --prefix=/usr
    ./config --prefix=/usr/local/ssl --openssldir=/usr/local/ssl
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Configure of openssl failed" 1
    fi
    make
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Build of openssl failed" 1
    fi
    make install
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Install of openssl failed" 1
    fi
    cp -pf /usr/local/ssl/bin/openssl /usr/local/bin
    popd
}

install_modsecurity(){
    if [ -d /usr/local/modsecurity ] ; then
        echoG "[OK] ModSecurity already installed"
        return 0
    fi
    pushd temp
    install_pcre
    install_zlib
    install_openssl
    git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity
    pushd ModSecurity
    git submodule init
    git submodule update
    ./build.sh
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Build of ModSecurity failed" 1
    fi
    ./configure
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Configure of ModSecurity failed" 1
    fi
    make
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Compile of ModSecurity failed" 1
    fi
    make install
    if [ $? -gt 0 ] ; then
        fail_exit_fatal "[ERROR] Install of ModSecurity failed" 1
    fi
    popd +1
}

install_nginxModSec(){
    pushd temp
    install_pcre
    install_zlib
    install_openssl
    git clone https://github.com/nginx/nginx.git
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git
    pushd nginx
    fail_exit_fatal "Don't actually run the configure yet" 1
    auto/configure --with-compat --add-dynamic-module=../ModSecurity-nginx --with-http_ssl_module --with-http_v2_module
    if [ $? -gt 0 ] ; then
        fail_exit "[ERROR] Configure of Nginx ModSecurity Module failed"
        exit 1
    fi
    make
    if [ $? -gt 0 ] ; then
        fail_exit "[ERROR] Compile of Nginx failed"
        exit 1
    fi
    make modules
    if [ $? -gt 0 ] ; then
        fail_exit "[ERROR] Compile of Nginx ModSecurity failed"
        exit 1
    fi
    popd +1
}

main(){
    validate_servers
    validate_user
    install_prereq
    install_owasp
    install_modsecurity
    install_nginxModSec
    #config_nginxModSec
    #config_olsModSec
    #config_lswsModSec
}
main
