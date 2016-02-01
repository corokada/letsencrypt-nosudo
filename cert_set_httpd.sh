#!/bin/sh

#
# ssl certificate setting for apache
#
# Author: corokada
#

if [ -z "$1" ]; then
        echo "usage:$0 [domain-name]"
        exit 0
fi

## それぞれ環境に合わせて修正をしてください。
CERTDIR="`pwd`/"

# ドメイン設定
DOMAIN=$1

## 設定する証明書チェック
HTTPDCERT="${CERTDIR}${DOMAIN}.crt"
if [ ! -f $HTTPDCERT ]; then
    echo "'$HTTPDCERT' is not exist. Create a '${DOMAIN}' Certificate."
    exit 0
fi

# httpdのパス(環境に合わせて修正)
HTTPD="/usr/sbin/httpd"

## CONFFILE
CONFFILE=`$HTTPD -S | grep virtualhost | grep "port 443" | grep " $DOMAIN " | tr -d ' ' | cut -d'(' -f2 | cut -d':' -f1`

## SSL証明書は対象のssl-conf-fileと同じ場所に保存
CONFDIR="${CONFFILE%/*}/"

## 証明書チェック
CERT="${CONFDIR}${DOMAIN}.crt"
if [ -f ${CERT} ]; then
    mv ${CERT} ${CERT}.`date +%Y%m%d-%H%M%S`
fi
CSR="${CONFDIR}${DOMAIN}.csr"
if [ -f ${CSR} ]; then
    mv ${CSR} ${CSR}.`date +%Y%m%d-%H%M%S`
fi
KEY="${CONFDIR}${DOMAIN}.key"
if [ -f ${KEY} ]; then
    mv ${KEY} ${KEY}.`date +%Y%m%d-%H%M%S`
fi
CA="${CONFDIR}${DOMAIN}.ca-bundle"
if [ -f ${CA} ]; then
    mv ${CA} ${CA}.`date +%Y%m%d-%H%M%S`
fi

## 証明書etcをコピーする
cp ${CERTDIR}${DOMAIN}.{key,csr,crt,ca-bundle} ${CONFDIR}

## ダミー証明書を使っているかチェック
if grep -v "#" $CONFFILE | grep "pki" | grep -sq "SSLCertificateFile"; then
    ## CONFFILEの修正
    sed -i -e "/SSLCertificateFile/c\    SSLCertificateFile ${CERT}" $CONFFILE
    sed -i -e "/SSLCertificateKeyFile/c\    SSLCertificateKeyFile ${KEY}" $CONFFILE
    sed -i -e "/SSLCACertificateFile/c\    SSLCACertificateFile ${CA}" $CONFFILE
    sed -i -e "s/#SSLVerifyClient/SSLVerifyClient/" -e "s/SSLVerifyClient/#SSLVerifyClient/" $CONFFILE
    sed -i -e "s/#SSLVerifyDepth/SSLVerifyDepth/" -e "s/SSLVerifyDepth/#SSLVerifyDepth/" $CONFFILE
fi

## apache再起動
/usr/sbin/apachectl graceful
