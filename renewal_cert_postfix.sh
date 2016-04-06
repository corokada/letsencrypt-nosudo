#!/bin/sh

#
# ssl certificate renewal for postfix/dovecot
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

# postfix用証明書フルパス
PCERT=`cat /etc/postfix/main.cf | grep smtpd_tls_cert_file | grep -v localhost | sed -e "s/ //g" | cut -d'=' -f2`
if [ -z "$PCERT" ]; then
    exit 0
fi
if [ ! -f $PCERT ]; then
    exit 0
fi

# 有効期限を取り出す
AFTER=`openssl x509 -noout -text -dates -in $PCERT | grep notAfter | cut -d'=' -f2`
AFTER=`env TZ=JST-9 date --date "$AFTER" +%s`
# 実行タイミングとの残日数を計算する
NOW=`env TZ=JST-9 date +%s`
CNT=`echo "$AFTER $NOW" | awk '{printf("%d",(($1-$2)/86400)+0.5)}'`
echo "$PCERT:$CNT"
# 有効期限20日以内
if [ "$CNT" -le 20 ]; then
    # 設定を取り出す
    DOMAIN=`openssl x509 -noout -text -in $PCERT | grep "Subject: CN" | cut -d'=' -f2`
    CONFFILE=`$HTTPD -S | grep "port 80" | grep $DOMAIN | tr -d ' ' | cut -d'(' -f2 | cut -d':' -f1`
    if [ "$CONFFILE" == "" ]; then
        echo "'$CONFFILE' is not exist. Create a '${DOMAIN}' Virtual Host."
        exit 0
    fi
    # ドキュメントルート
    DOCROOT=`cat $CONFFILE | grep DocumentRoot | awk '{print $2}' | uniq`
    ## 証明書チェック
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
    # バックアップ
    AFTER=`openssl x509 -noout -text -dates -in $CERT | grep notAfter | cut -d'=' -f2`
    AFTER=`env TZ=JST-9 date --date "$AFTER" +%Y%m%d-%H%M`
    cp -pr $CERT $CERT.limit$AFTER
    # BASIC認証回避
    mkdir -p ${DOCROOT}/.well-known/acme-challenge
    rm -rf ${DOCROOT}/.well-known/.htaccess
    echo "Satisfy any" > ${DOCROOT}/.well-known/.htaccess
    echo "order allow,deny" >> ${DOCROOT}/.well-known/.htaccess
    echo "allow from all" >> ${DOCROOT}/.well-known/.htaccess
    # 証明書発行処理
    cd ${CERTDIR}
    python ${SIGNPG} -d ${DOCROOT} -p ${USERPUB} -in ${CSR} -out ${CERT}
    # 認証用ディレクトリ削除
    rm -rf ${DOCROOT}/.well-known
    # 現在時刻を付けてリネーム。
    AFTER=`openssl x509 -noout -text -dates -in $PCERT | grep notAfter | cut -d'=' -f2`
    AFTER=`env TZ=JST-9 date --date "$AFTER" +%Y%m%d-%H%M`
    cp -pr $PCERT $PCERT.limit$AFTER
    # CA証明書
    CA="${CERTDIR}${DOMAIN}.ca-bundle"
    if [ -f ${CA} ]; then
        mv ${CA} ${CA}.limit$AFTER
    fi
    #wget -q -O ${CA} https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.pem
    TMPCA1=`mktemp -p /tmp -t ca.XXXXXXXXXXXXXXX`
    TMPCA2=`mktemp -p /tmp -t ca.XXXXXXXXXXXXXXX`
    wget -q -O $TMPCA1 https://letsencrypt.org/certs/isrgrootx1.pem.txt
    wget -q -O $TMPCA2 https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem.txt
    cat $TMPCA1 $TMPCA2 > $CA
    rm -rf $TMPCA1 $TMPCA2
    # コピー
    cat ${CERTDIR}${DOMAIN}.{crt,ca-bundle} > ${PCERT}
    # サービス再起動
    /etc/init.d/postfix reload
    /etc/init.d/dovecot reload
fi
