#!/bin/sh

if [ -z "$1" ]; then
        echo "usage:$0 [domain-name]"
        exit 0
fi

DOMAIN=$1
DIRNAME=${DOMAIN//./_}

## それぞれ環境に合わせて修正をしてください。
CERTDIR="./"
DOCROOT="/path/to/${DIRNAME}/public_html"

if [ ! -f ${CERTDIR}user.pub ]; then
    openssl genrsa 4096 > ${CERTDIR}user.key
    openssl rsa -in ${CERTDIR}user.key -pubout > ${CERTDIR}user.pub
fi

if [ -f ${CERTDIR}${DOMAIN}.csr ]; then
    mv ${CERTDIR}${DOMAIN}.csr ${CERTDIR}${DOMAIN}.csr`date +%Y%m%d-%H%M%S`
fi
if [ -f ${CERTDIR}${DOMAIN}.crt ]; then
    mv ${CERTDIR}${DOMAIN}.crt ${CERTDIR}${DOMAIN}.crt`date +%Y%m%d-%H%M%S`
fi

if [ ! -f ${CERTDIR}${DOMAIN}.key ]; then
    openssl genrsa 4096 > ${CERTDIR}${DOMAIN}.key
fi

tmp=`mktemp -p /tmp -t opensslconf.XXXXXXXXXXXXXXX`
cat /etc/pki/tls/openssl.cnf > $tmp
printf "[SAN]\nsubjectAltName=DNS:${DOMAIN},DNS:www.${DOMAIN}" >> $tmp
openssl req -new -sha256 -key ${CERTDIR}${DOMAIN}.key -subj "/" -reqexts SAN -config $tmp > ${CERTDIR}${DOMAIN}.csr
python sign_csr.py -d ${DOCROOT} -p ${CERTDIR}user.pub -in ${CERTDIR}${DOMAIN}.csr -out ${CERTDIR}${DOMAIN}.crt
wget -q -O ${CERTDIR}${DOMAIN}.ca-bundle https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.pem
rm -rf $tmp
