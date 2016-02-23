#!/bin/sh

#
# ssl certificate datecheck for apache 
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

# conf�ꗗ���o��
for CONFFILE in `$HTTPD -S | grep virtualhost | grep "port 443" | tr -d ' ' | cut -d'(' -f2 | cut -d':' -f1 | sort | uniq`
do
    #�_�~�[�ؖ����`�F�b�N
    if grep -v "#" $CONFFILE | grep -v "pki" | grep -sq "SSLCertificateFile"; then
        CERT=`grep -v "#" $CONFFILE | grep -v "pki" | grep SSLCertificateFile | awk '{print $2}' | uniq`
        # �L�����������o��
        AFTER=`openssl x509 -noout -text -dates -in $CERT | grep notAfter | cut -d'=' -f2`
        AFTER=`env TZ=JST-9 date --date "$AFTER" +%s`
        # ���s�^�C�~���O�Ƃ̎c�������v�Z����
        NOW=`env TZ=JST-9 date +%s`
        CNT=`echo "$AFTER $NOW" | awk '{printf("%d",(($1-$2)/86400)+0.5)}'`
        echo "$CERT:$CNT"
    fi
done
