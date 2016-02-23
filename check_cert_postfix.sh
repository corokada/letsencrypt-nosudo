#!/bin/sh

#
# ssl certificate datecheck for postfix/dovecot
#
# Author: corokada
#

## それぞれ環境に合わせて修正をしてください。
CERTDIR="`dirname $0`/"

# ドメイン設定
DOMAIN=$1

# postfix用証明書フルパス
PCERT=`cat /etc/postfix/main.cf | grep smtpd_tls_cert_file | sed -e "s/ //g" | cut -d'=' -f2`
if echo $PCERT | grep -sq "localhost"; then
    exit 0
fi

# 有効期限を取り出す
AFTER=`openssl x509 -noout -text -dates -in $PCERT | grep notAfter | cut -d'=' -f2`
AFTER=`env TZ=JST-9 date --date "$AFTER" +%s`
# 実行タイミングとの残日数を計算する
NOW=`env TZ=JST-9 date +%s`
CNT=`echo "$AFTER $NOW" | awk '{printf("%d",(($1-$2)/86400)+0.5)}'`
echo "$PCERT:$CNT"
