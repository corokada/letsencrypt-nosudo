#!/bin/sh

#
# ssl certificate renewal for apache
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
        # �L������20���ȓ�
        if [ "$CNT" -le 20 ]; then
            DOMAIN=`cat $CONFFILE | grep -v "#" | grep ServerName | awk '{print $2}' | grep -v ":"`
            DOCROOT=`cat $CONFFILE | grep DocumentRoot | awk '{print $2}' | uniq`
            KEY=`cat $CONFFILE | grep -v "#" | grep SSLCertificateKeyFile | awk '{print $2}' | uniq`
            CSR=${CERT/.crt/.csr}
            # CSR�������ꍇ�́A�쐬����
            if [ ! -f "$CSR" ]; then
                FLG=`openssl x509 -noout -text -in $CERT | grep DNS | grep ","`
                if [ "$FLG" == "" ]; then
                    openssl req -new -sha256 -key ${KEY} -subj "/CN=${DOMAIN}" > ${CSR}
                else
                    tmp=`mktemp -p /tmp -t opensslconf.XXXXXXXXXXXXXXX`
                    cat /etc/pki/tls/openssl.cnf > $tmp
                    printf "[SAN]\nsubjectAltName=DNS:${DOMAIN},DNS:www.${DOMAIN}" >> $tmp
                    openssl req -new -sha256 -key ${KEY} -subj "/" -reqexts SAN -config $tmp > ${CSR}
                    rm -rf $tmp
                fi
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
            # apache�ċN��
            apachectl graceful
        fi
    fi
done
