#!/bin/sh

#
# ssl certificate create 
#     (hogehoge.com/www.hogehoge.com/mail.hogehoge.com)
#
# Author: corokada
#

if [ -z "$1" ]; then
        echo "usage:$0 [domain-name]"
        exit 0
fi

DOMAIN=$1

## ���ꂼ����ɍ��킹�ďC�������Ă��������B
CERTDIR="`dirname $0`/"

# httpd�̃p�X
HTTPD="/usr/sbin/httpd"

# ���s�v���O�����̃p�X
SIGNPG="${CERTDIR}sign_csr.py"

#CONF
CONF=`$HTTPD -S | grep "port 80" | grep $DOMAIN | tr -d ' ' | cut -d'(' -f2 | cut -d':' -f1`
if [ "$CONF" == "" ]; then
    echo "'$CONF' is not exist. Create a '${DOMAIN}' Virtual Host."
    exit 0
fi

# ���[�U�[�F�؏��
USERKEY="${CERTDIR}user.key"
USERPUB="${CERTDIR}user.pub"
if [ ! -f ${USERPUB} ]; then
    openssl genrsa 4096 > ${USERKEY}
    openssl rsa -in ${USERKEY} -pubout > ${USERPUB}
fi

# �閧���쐬
KEY="${CERTDIR}${DOMAIN}.key"
if [ ! -f ${KEY} ]; then
    openssl genrsa 4096 > ${KEY}
fi

# CSR�쐬
CSR="${CERTDIR}${DOMAIN}.csr"
if [ -f ${CSR} ]; then
    mv ${CSR} ${CSR}.`date +%Y%m%d-%H%M%S`
fi
tmp=`mktemp -p /tmp -t opensslconf.XXXXXXXXXXXXXXX`
cat /etc/pki/tls/openssl.cnf > $tmp
printf "[SAN]\nsubjectAltName=DNS:${DOMAIN},DNS:www.${DOMAIN},DNS:mail.${DOMAIN}" >> $tmp
openssl req -new -sha256 -key ${KEY} -subj "/" -reqexts SAN -config $tmp > ${CSR}
rm -rf $tmp

# ���s�ςݏؖ����o�b�N�A�b�v
CERT="${CERTDIR}${DOMAIN}.crt"
if [ -f ${CERT} ]; then
    AFTER=`openssl x509 -noout -text -dates -in $CERT | grep notAfter | cut -d'=' -f2`
    AFTER=`env TZ=JST-9 date --date "$AFTER" +%Y%m%d-%H%M`
    cp -pr $CERT $CERT.limit$AFTER
fi

# �h�L�������g���[�g
DOCROOT=`cat $CONF | grep DocumentRoot | awk '{print $2}' | uniq`

## BASIC�F�؉��
mkdir -p ${DOCROOT}/.well-known/acme-challenge
echo "Satisfy any" > ${DOCROOT}/.well-known/.htaccess
echo "order allow,deny" >> ${DOCROOT}/.well-known/.htaccess
echo "allow from all" >> ${DOCROOT}/.well-known/.htaccess

# �ؖ������s����
cd $CERTDIR
python ${SIGNPG} -d ${DOCROOT} -p ${USERPUB} -in ${CSR} -out ${CERT}

# CA�ؖ���
CA="${CERTDIR}${DOMAIN}.ca-bundle"
if [ -f ${CA} ]; then
    mv ${CA} ${CA}.`date +%Y%m%d-%H%M%S`
fi
wget -q -O ${CA} https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.pem

# �s�v�t�@�C���폜
rm -rf ${DOCROOT}/.well-known
