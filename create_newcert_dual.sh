#!/bin/sh

#
# ssl certificate create 
#     (hogehoge.com/www.hogehoge.com)
#
# Author: corokada
#

if [ -z "$1" ]; then
        echo "usage:$0 [domain-name]"
        exit 0
fi

DOMAIN=$1

## それぞれ環境に合わせて修正をしてください。
CERTDIR="`dirname $0`/"

# httpdのパス
HTTPD="/usr/sbin/httpd"

# 発行プログラムのパス
SIGNPG="${CERTDIR}sign_csr.py"

#CONF
CONF=`$HTTPD -S | grep "port 80" | grep $DOMAIN | tr -d ' ' | cut -d'(' -f2 | cut -d':' -f1`
if [ "$CONF" == "" ]; then
    echo "'$CONF' is not exist. Create a '${DOMAIN}' Virtual Host."
    exit 0
fi

# ユーザー認証情報
USERKEY="${CERTDIR}user.key"
USERPUB="${CERTDIR}user.pub"
if [ ! -f ${USERPUB} ]; then
    openssl genrsa 4096 > ${USERKEY}
    openssl rsa -in ${USERKEY} -pubout > ${USERPUB}
fi

# 秘密鍵作成
KEY="${CERTDIR}${DOMAIN}.key"
if [ ! -f ${KEY} ]; then
    openssl genrsa 4096 > ${KEY}
fi

# CSR作成
CSR="${CERTDIR}${DOMAIN}.csr"
if [ -f ${CSR} ]; then
    mv ${CSR} ${CSR}.`date +%Y%m%d-%H%M%S`
fi
tmp=`mktemp -p /tmp -t opensslconf.XXXXXXXXXXXXXXX`
cat /etc/pki/tls/openssl.cnf > $tmp
printf "[SAN]\nsubjectAltName=DNS:${DOMAIN},DNS:www.${DOMAIN}" >> $tmp
openssl req -new -sha256 -key ${KEY} -subj "/" -reqexts SAN -config $tmp > ${CSR}
rm -rf $tmp

# 発行済み証明書バックアップ
CERT="${CERTDIR}${DOMAIN}.crt"
if [ -f ${CERT} ]; then
    AFTER=`openssl x509 -noout -text -dates -in $CERT | grep notAfter | cut -d'=' -f2`
    AFTER=`env TZ=JST-9 date --date "$AFTER" +%Y%m%d-%H%M`
    cp -pr $CERT $CERT.limit$AFTER
fi

# ドキュメントルート
DOCROOT=`cat $CONF | grep DocumentRoot | awk '{print $2}' | uniq`

## BASIC認証回避
mkdir -p ${DOCROOT}/.well-known/acme-challenge
echo "Satisfy any" > ${DOCROOT}/.well-known/.htaccess
echo "order allow,deny" >> ${DOCROOT}/.well-known/.htaccess
echo "allow from all" >> ${DOCROOT}/.well-known/.htaccess

# 証明書発行処理
cd $CERTDIR
python ${SIGNPG} -d ${DOCROOT} -p ${USERPUB} -in ${CSR} -out ${CERT}

# CA証明書
CA="${CERTDIR}${DOMAIN}.ca-bundle"
if [ -f ${CA} ]; then
    mv ${CA} ${CA}.`date +%Y%m%d-%H%M%S`
fi
#wget -q -O ${CA} https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.pem
TMPCA1=`mktemp -p /tmp -t ca.XXXXXXXXXXXXXXX`
TMPCA2=`mktemp -p /tmp -t ca.XXXXXXXXXXXXXXX`
wget -q -O $TMPCA1 https://letsencrypt.org/certs/isrgrootx1.pem.txt
wget -q -O $TMPCA2 https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem.txt
cat $TMPCA1 $TMPCA2 > $CA
rm -rf $TMPCA1 $TMPCA2

# 不要ファイル削除
rm -rf ${DOCROOT}/.well-known
