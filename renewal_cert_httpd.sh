#!/bin/sh

#
# ssl certificate renewal for apache
#
# Author: corokada
#

## それぞれ環境に合わせて修正をしてください。
CERTDIR="`dirname $0`/"

# ユーザー認証情報
USERKEY="${CERTDIR}user.key"
USERPUB="${CERTDIR}user.pub"
if [ ! -f ${USERPUB} ]; then
    openssl genrsa 4096 > ${USERKEY}
    openssl rsa -in ${USERKEY} -pubout > ${USERPUB}
fi

# httpdのパス
HTTPD="/usr/sbin/httpd"

# 発行プログラムのパス
SIGNPG="${CERTDIR}sign_csr.py"

# conf一覧取り出し
for CONFFILE in `$HTTPD -S | grep virtualhost | grep "port 443" | tr -d ' ' | cut -d'(' -f2 | cut -d':' -f1 | sort | uniq`
do
    #ダミー証明書チェック
    if grep -v "#" $CONFFILE | grep -v "pki" | grep -sq "SSLCertificateFile"; then
        CERT=`grep -v "#" $CONFFILE | grep -v "pki" | grep SSLCertificateFile | awk '{print $2}' | uniq`
        # 有効期限を取り出す
        AFTER=`openssl x509 -noout -text -dates -in $CERT | grep notAfter | cut -d'=' -f2`
        AFTER=`env TZ=JST-9 date --date "$AFTER" +%s`
        # 実行タイミングとの残日数を計算する
        NOW=`env TZ=JST-9 date +%s`
        CNT=`echo "$AFTER $NOW" | awk '{printf("%d",(($1-$2)/86400)+0.5)}'`
        echo "$CERT:$CNT"
        # 有効期限20日以内
        if [ "$CNT" -le 20 ]; then
            DOMAIN=`cat $CONFFILE | grep -v "#" | grep ServerName | awk '{print $2}' | grep -v ":"`
            DOCROOT=`cat $CONFFILE | grep DocumentRoot | awk '{print $2}' | uniq`
            KEY=`cat $CONFFILE | grep -v "#" | grep SSLCertificateKeyFile | awk '{print $2}' | uniq`
            CSR=${CERT/.crt/.csr}
            # CSRが無い場合は、作成する
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
            # バックアップ
            AFTER=`openssl x509 -noout -text -dates -in $CERT | grep notAfter | cut -d'=' -f2`
            AFTER=`env TZ=JST-9 date --date "$AFTER" +%Y%m%d-%H%M`
            cp -pr $CERT $CERT.limit$AFTER
            # BASIC認証回避
            mkdir -p ${DOCROOT}/.well-known/acme-challenge
            echo "Satisfy any" > ${DOCROOT}/.well-known/.htaccess
            echo "order allow,deny" >> ${DOCROOT}/.well-known/.htaccess
            echo "allow from all" >> ${DOCROOT}/.well-known/.htaccess
            # 証明書発行処理
            cd ${CERTDIR}
            python ${SIGNPG} -d ${DOCROOT} -p ${USERPUB} -in ${CSR} -out ${CERT}
            # 認証用ディレクトリ削除
            rm -rf ${DOCROOT}/.well-known
            # apache再起動
            apachectl graceful
        fi
    fi
done
