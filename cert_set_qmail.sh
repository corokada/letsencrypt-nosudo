#!/bin/sh

#
# ssl certificate setting for qmail
#
# Author: corokada
#

if [ -z "$1" ]; then
        echo "usage:$0 [domain-name]"
        exit 0
fi

## ���ꂼ����ɍ��킹�ďC�������Ă��������B
CERTDIR="`pwd`/"

# �h���C���ݒ�
DOMAIN=$1

# qmail�p�ؖ����t���p�X
QMAILCERT="/var/qmail/control/servercert.pem"

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
if [ -f $QMAILCERT ]; then
    cp -pr $QMAILCERT $QMAILCERT.`date +%Y%m%d-%H%M%S`
fi

# �R�s�[
cat ${CERTDIR}${DOMAIN}.{key,crt,ca-bundle} > $QMAILCERT
chown qmaild.qmail $QMAILCERT

# �T�[�r�X�ċN��
/etc/init.d/qmail restart
