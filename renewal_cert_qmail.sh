#!/bin/sh

#
# ssl certificate renewal for qmail
#
# Author: corokada
#

## ���ꂼ����ɍ��킹�ďC�������Ă��������B
CERTDIR="`dirname $0`/"

# ���[�U�[�F�؏��
USERKEY="${CERTDIR}user.key"
USERPUB="${CERTDIR}user.pub"
if [ ! -f ${USERPUB} ]; then
    openssl genrsa 4096 > ${USERKEY}
    openssl rsa -in ${USERKEY} -pubout > ${USERPUB}
fi

# httpd�̃p�X
HTTPD="/usr/sbin/httpd"

# ���s�v���O�����̃p�X
SIGNPG="${CERTDIR}sign_csr.py"

#qmail�p�̏ؖ���
QMAILCERT="/var/qmail/control/servercert.pem"
if [ ! -f $QMAILCERT ]; then
    exit 0
fi

# �L�����������o��
AFTER=`openssl x509 -noout -text -dates -in $QMAILCERT | grep notAfter | cut -d'=' -f2`
AFTER=`env TZ=JST-9 date --date "$AFTER" +%s`
# ���s�^�C�~���O�Ƃ̎c�������v�Z����
NOW=`env TZ=JST-9 date +%s`
CNT=`echo "$AFTER $NOW" | awk '{printf("%d",(($1-$2)/86400)+0.5)}'`
echo "$QMAILCERT:$CNT"
# �L������20���ȓ�
if [ "$CNT" -le 20 ]; then
    # �ݒ�����o��
    DOMAIN=`openssl x509 -noout -text -in $QMAILCERT | grep "Subject: CN" | cut -d'=' -f2`
    CONFFILE=`$HTTPD -S | grep "port 80" | grep $DOMAIN | tr -d ' ' | cut -d'(' -f2 | cut -d':' -f1`
    if [ "$CONFFILE" == "" ]; then
        echo "'$CONFFILE' is not exist. Create a '${DOMAIN}' Virtual Host."
        exit 0
    fi
    # �h�L�������g���[�g
    DOCROOT=`cat $CONFFILE | grep DocumentRoot | awk '{print $2}' | uniq`
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
    CSR="${CERTDIR}${DOMAIN}.csr"
    if [ ! -f $CSR ]; then
        echo "'$CSR' is not exist. Create a '${DOMAIN}' Certificate."
        exit 0
    fi
    CA="${CERTDIR}${DOMAIN}.ca-bundle"
    if [ ! -f $CA ]; then
        echo "'$CA' is not exist. Create a '${DOMAIN}' Certificate."
        exit 0
    fi
    # �o�b�N�A�b�v
    AFTER=`openssl x509 -noout -text -dates -in $CERT | grep notAfter | cut -d'=' -f2`
    AFTER=`env TZ=JST-9 date --date "$AFTER" +%Y%m%d-%H%M`
    cp -pr $CERT $CERT.limit$AFTER
    # BASIC�F�؉��
    mkdir -p ${DOCROOT}/.well-known/acme-challenge
    echo "Satisfy any" > ${DOCROOT}/.well-known/.htaccess
    echo "order allow,deny" >> ${DOCROOT}/.well-known/.htaccess
    echo "allow from all" >> ${DOCROOT}/.well-known/.htaccess
    # �ؖ������s����
    cd ${CERTDIR}
    python ${SIGNPG} -d ${DOCROOT} -p ${USERPUB} -in ${CSR} -out ${CERT}
    # �F�ؗp�f�B���N�g���폜
    rm -rf ${DOCROOT}/.well-known
    # ���ݎ�����t���ă��l�[���B
    AFTER=`openssl x509 -noout -text -dates -in $QMAILCERT | grep notAfter | cut -d'=' -f2`
    AFTER=`env TZ=JST-9 date --date "$AFTER" +%Y%m%d-%H%M`
    cp -pr $QMAILCERT $QMAILCERT.limit$AFTER
    # �R�s�[
    cat ${CERTDIR}${DOMAIN}.{key,crt,ca-bundle} > $QMAILCERT
    chown qmaild.qmail $QMAILCERT
    # �T�[�r�X�ċN��
    /etc/init.d/qmail restart
fi
