#! /bin/env bash
# https://gist.github.com/mtigas/952344

DOMAIN="*.ztaoz.com"
IP="10.177.140.16"
CERT_DIR="${PWD}/cert"
CA_PASSWD=aUth123
SRV_PASSWD=passWd321
CLIENT_ID="ldap"
CLIENT_SERIAL=01

rm -rf ${CERT_DIR}
mkdir -p ${CERT_DIR}
cd ${CERT_DIR}

# CA
openssl genrsa -aes256 -passout pass:${CA_PASSWD} -out ca.pass.key 4096
openssl rsa -passin pass:${CA_PASSWD} -in ca.pass.key -out ca.key
rm -f ca.pass.key
openssl ecparam -genkey -name secp256r1 | openssl ec -out ca.key
openssl req -x509 -new -sha512 -days 3650 -subj "/C=CN/ST=Shanghai/L=Shanghai/O=local/OU=Personal/CN=${DOMAIN}" -key ca.key -out ca.pem

# server
openssl genrsa -aes256 -passout pass:${SRV_PASSWD} -out ${CLIENT_ID}.pass.key 4096
openssl rsa -passin pass:${SRV_PASSWD} -in ${CLIENT_ID}.pass.key -out ${CLIENT_ID}.key
rm -f ${CLIENT_ID}.pass.key
openssl req -new -subj "/C=CN/ST=Shanghai/L=Shanghai/O=local/OU=Personal/CN=${DOMAIN}" -in ${CLIENT_ID}.csr -key ${CLIENT_ID}.key -out ${CLIENT_ID}.csr
cat >v3.ext <<-EOF
authorityKeyIdentifier = keyid,issuer:always
basicConstraints = CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
subjectAltName = @alt_names

[alt_names]
DNS.1=${DOMAIN}
DNS.2=${DOMAIN#*.}
DNS.3=ldap.${DOMAIN#*.}
IP.1 = 127.0.0.1
IP.2 = 0:0:0:0:0:0:0:1
IP.3 = 10.177.0.0/16
IP.4 = ${IP}
EOF
openssl x509 -req -sha512 -days 3650 -extfile v3.ext -in ${CLIENT_ID}.csr -CA ca.pem -CAkey ca.key -set_serial ${CLIENT_SERIAL} -out ${CLIENT_ID}.pem

cat ${CLIENT_ID}.key ${CLIENT_ID}.pem ca.pem >${CLIENT_ID}.full.pem
openssl genrsa -aes256 -passout pass:${CA_PASSWD} -out ca.pass.key 4096
openssl pkcs12 -passout pass:${CA_PASSWD} -export -out ${CLIENT_ID}.full.pfx -inkey ${CLIENT_ID}.key -in ${CLIENT_ID}.pem -certfile ca.pem
rm -f ca.pass.key

openssl verify -CAfile ca.pem ${CLIENT_ID}.pem
openssl x509 -noout -text -in ${CLIENT_ID}.pem
# # 验证当前套接字是否能通过CA的验证
# openssl s_client -connect ldap.${DOMAIN#*.}:636 -showcerts -state -CAfile ca.pem
