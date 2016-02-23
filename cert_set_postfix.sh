#!/bin/sh

#
# ssl certificate setting for postfix/dovecot
#
# Author: corokada
#

if [ -z "$1" ]; then
        echo "usage:$0 [domain-name]"
        exit 0
fi

## ���ꂼ����ɍ��킹�ďC�������Ă��������B
CERTDIR="`dirname $0`/"

# �h���C���ݒ�
DOMAIN=$1

# postfix�p�ؖ����t���p�X
PCERT=`cat /etc/postfix/main.cf | grep smtpd_tls_cert_file | sed -e "s/ //g" | cut -d'=' -f2`
PKEY=`cat /etc/postfix/main.cf | grep smtpd_tls_key_file | sed -e "s/ //g" | cut -d'=' -f2`

## �ؖ����`�F�b�N
CERT="${CERTDIR}${DOMAIN}.crt"
if [ ! -f $CERT ]; then
    echo "'$CERT' is not exist. Create a '${DOMAIN}' Certificate."
    exit 0
fi
KEY="${CERTDIR}${DOMAIN}.key"
if [ ! -f $KEY ]; then
    echo "'$KEY' is not exist. Create a '${DOMAIN}' Certificate."
    exit 0
fi
CA="${CERTDIR}${DOMAIN}.ca-bundle"
if [ ! -f $CA ]; then
    echo "'$CA' is not exist. Create a '${DOMAIN}' Certificate."
    exit 0
fi

## ���ɂ���ꍇ�͌��ݎ�����t���ă��l�[���B
CERTTMP=`dirname $PCERT`
if [ -f ${CERTTMP}/${DOMAIN}.crt ]; then
    cp -pr ${CERTTMP}/${DOMAIN}.crt ${CERTTMP}/${DOMAIN}.crt.`date +%Y%m%d-%H%M%S`
fi
KEYTMP=`dirname $PKEY`
if [ -f ${KEYTMP}/${DOMAIN}.key ]; then
    cp -pr ${KEYTMP}/${DOMAIN}.key ${KEYTMP}/${DOMAIN}.key.`date +%Y%m%d-%H%M%S`
fi

# �R�s�[
cat ${CERTDIR}${DOMAIN}.{crt,ca-bundle} > ${CERTTMP}/${DOMAIN}.crt
cat ${CERTDIR}${DOMAIN}.key > ${KEYTMP}/${DOMAIN}.key

# conf�C��
TMP=`echo $PCERT | sed "s/\//\\\\\\\\\//g"`
CERTTMP=`echo $CERTTMP | sed "s/\//\\\\\\\\\//g"`
sed -i -e "s/$TMP/${CERTTMP}\/${DOMAIN}.crt/g" /etc/postfix/main.cf
sed -i -e "s/$TMP/${CERTTMP}\/${DOMAIN}.crt/g" /etc/dovecot/conf.d/10-ssl.conf
TMP=`echo $PKEY | sed "s/\//\\\\\\\\\//g"`
KEYTMP=`echo $KEYTMP | sed "s/\//\\\\\\\\\//g"`
sed -i -e "s/$TMP/${KEYTMP}\/${DOMAIN}.key/g" /etc/postfix/main.cf
sed -i -e "s/$TMP/${KEYTMP}\/${DOMAIN}.key/g" /etc/dovecot/conf.d/10-ssl.conf

# �T�[�r�X�ċN��
/etc/init.d/postfix reload
/etc/init.d/dovecot reload
