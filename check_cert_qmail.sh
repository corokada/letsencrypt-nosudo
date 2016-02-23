#!/bin/sh

#
# ssl certificate datecheck for qmail
#
# Author: corokada
#

## それぞれ環境に合わせて修正をしてください。
CERTDIR="`dirname $0`/"

#qmail用の証明書
QMAILCERT="/var/qmail/control/servercert.pem"
if [ ! -f $QMAILCERT ]; then
    exit 0
fi

# 有効期限を取り出す
AFTER=`openssl x509 -noout -text -dates -in $QMAILCERT | grep notAfter | cut -d'=' -f2`
AFTER=`env TZ=JST-9 date --date "$AFTER" +%s`
# 実行タイミングとの残日数を計算する
NOW=`env TZ=JST-9 date +%s`
CNT=`echo "$AFTER $NOW" | awk '{printf("%d",(($1-$2)/86400)+0.5)}'`
echo "$QMAILCERT:$CNT"
