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

## それぞれ環境に合わせて修正をしてください。
CERTDIR="`pwd`/"

# ドメイン設定
DOMAIN=$1

# qmail用証明書フルパス
QMAILCERT="/var/qmail/control/servercert.pem"

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
CA="${CERTDIR}${DOMAIN}.ca-bundle"
if [ ! -f $CA ]; then
    echo "'$CA' is not exist. Create a '${DOMAIN}' Certificate."
    exit 0
fi

## 既にある場合は現在時刻を付けてリネーム。
if [ -f $QMAILCERT ]; then
    cp -pr $QMAILCERT $QMAILCERT.`date +%Y%m%d-%H%M%S`
fi

# コピー
cat ${CERTDIR}${DOMAIN}.{key,crt,ca-bundle} > $QMAILCERT
chown qmaild.qmail $QMAILCERT

# サービス再起動
/etc/init.d/qmail restart
