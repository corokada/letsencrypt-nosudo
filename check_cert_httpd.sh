#!/bin/sh

#
# ssl certificate datecheck for apache 
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
    fi
done
