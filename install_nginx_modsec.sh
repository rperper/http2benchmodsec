#!/bin/bash
# /********************************************************************
# HTTP2 Benchmark Modify Server for ModSecurity install Nginx modsec
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
TEMP_DIR="${1}"
OWASP_DIR="${2}"
NGDIR='/etc/nginx'

install_pcre(){
    if [ -d pcre-8.43 ] ; then
        echoG "[OK] pcre already downloaded"
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
    if [ -d zlib-1.2.11 ] ; then
        echoG "[OK] libz already download"
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
    openssl version|grep 1.1.1
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
    PWD=$(pwd)
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
    echo "End of ModSecurity PWD: $(pwd)"
    read line
    popd +1
    echo "End of ModSecurity After popd +1 PWD: $(pwd)"
    read line
    cd $PWD
    echo "End of ModSecurity After cd: $PWD: $(pwd)"
    read line
}

install_nginxModSec(){
    echo "Start of nginxModSec PWD: $(pwd)"
    read line
    pushd temp
    install_pcre
    install_zlib
    install_openssl
    echo "Finished test of pre-reqs for nginxModSec PWD: $(pwd)"
    read line
    git clone https://github.com/nginx/nginx.git
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git
    pushd nginx
    echo "Did clones and in nginx dir for nginxModSec PWD: $(pwd)"
    read line
    git checkout default
    auto/configure --with-compat --add-dynamic-module=../ModSecurity-nginx --prefix=$NGDIR --sbin-path=/usr/sbin/nginx --with-http_ssl_module --with-http_v2_module --conf-path=$NGDIR/nginx.conf --pid-path=/run/nginx.pid --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --with-pcre=../pcre-8.43 --with-zlib=../zlib-1.2.11 --with-http_ssl_module --with-stream --with-mail=dynamic 
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
    cp $NGDIR/nginx.conf $NGDIR/nginx.conf.preinstall
    cp $NGDIR/conf.d/default.conf $NGDIR/conf.d/default.conf.preinstall
    make install
    if [ $? -gt 0 ] ; then
        cp $NGDIR/nginx.conf.preinstall $NGDIR/nginx.conf
        cp $NGDIR/conf.d/default.conf.preinstall $NGDIR/conf.d/default.conf
        fail_exit "[ERROR] Install of Nginx ModSecurity failed"
        exit 1
    fi
    cp $NGDIR/nginx.conf.preinstall $NGDIR/nginx.conf
    cp $NGDIR/conf.d/default.conf.preinstall $NGDIR/conf.d/default.conf
    popd +1
}

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

main(){
    install_modsecurity
    install_nginxModSec
}
main
