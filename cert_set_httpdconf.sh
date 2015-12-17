#!/bin/sh

usage() {
    echo "usage:$0 -d=[domain-name] -c=[ssl-conf-file]"
}

if [ $# != 2 ]; then
    usage
    exit 0
fi

## それぞれ環境に合わせて修正をしてください。
CERTDIR="./"

## 初期化
DOMAIN=""
CONFFILE=""

## 引数取り出し
for TMP in "$@"
do
    KEY=${TMP%%=*}
    VALUE=${TMP##*=}
    case $KEY in
        "-d" ) DOMAIN=$VALUE ;;
        "-c" ) CONFFILE=$VALUE ;;
    esac
done

## 引数確認
if [ "$DOMAIN" = "" ] || [ "$CONFFILE" = "" ]; then
    usage
    exit 0
fi

## 証明書チェック
TMP="${CERTDIR}${DOMAIN}.crt"
if [ ! -f $TMP ]; then
    usage
    echo "'$TMP' is not exist. Create a '${DOMAIN}' Certificate."
    exit 0
fi

## CONFFILEチェック
if [ ! -f $CONFFILE ]; then
    usage
    echo "'$CONFFILE' is not exist."
    exit 0
fi


## SSL証明書は対象のssl-conf-fileと同じ場所に保存
CONFDIR="${CONFFILE%/*}/"

## コピー先に証明書etcがあるか。
## あったら現在時刻を付けてリネーム。
if [ -f ${CONFDIR}${DOMAIN}.key ]; then
    mv ${CONFDIR}${DOMAIN}.key ${CONFDIR}${DOMAIN}.key`date +%Y%m%d-%H%M%S`
fi
## if [ -f ${CONFDIR}${DOMAIN}.csr ]; then
##     mv ${CONFDIR}${DOMAIN}.csr ${CONFDIR}${DOMAIN}.csr`date +%Y%m%d-%H%M%S`
## fi
if [ -f ${CONFDIR}${DOMAIN}.crt ]; then
    mv ${CONFDIR}${DOMAIN}.crt ${CONFDIR}${DOMAIN}.crt`date +%Y%m%d-%H%M%S`
fi
if [ -f ${CONFDIR}${DOMAIN}.ca-bundle ]; then
    mv ${CONFDIR}${DOMAIN}.ca-bundle ${CONFDIR}${DOMAIN}.ca-bundle`date +%Y%m%d-%H%M%S`
fi

## 証明書etcをコピーする
cp ${CERTDIR}${DOMAIN}.{key,crt,ca-bundle} ${CONFDIR}

## CONFFILEの修正
sed -i -e "/SSLCertificateFile/c\    SSLCertificateFile ${CONFDIR}${DOMAIN}.crt" $CONFFILE
sed -i -e "/SSLCertificateKeyFile/c\    SSLCertificateKeyFile ${CONFDIR}${DOMAIN}.key" $CONFFILE
sed -i -e "/SSLCACertificateFile/c\    SSLCACertificateFile ${CONFDIR}${DOMAIN}.ca-bundle" $CONFFILE
sed -i -e "s/#SSLVerifyClient/SSLVerifyClient/" -e "s/SSLVerifyClient/#SSLVerifyClient/" $CONFFILE
sed -i -e "s/#SSLVerifyDepth/SSLVerifyDepth/" -e "s/SSLVerifyDepth/#SSLVerifyDepth/" $CONFFILE

## apache再起動
/usr/sbin/apachectl graceful
