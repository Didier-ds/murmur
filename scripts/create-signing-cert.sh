#!/bin/zsh
# Creates a self-signed "Murmur Dev" code-signing certificate in the login keychain.
# It's only used to sign Murmur on this Mac, so that macOS keeps its Accessibility
# permission across rebuilds. It isn't an Apple Developer certificate.
set -euo pipefail

if security find-identity -p codesigning | grep -q '"Murmur Dev"'; then
    echo "Murmur Dev certificate already exists."
    exit 0
fi

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir"

cat > cert.cnf <<'CNF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = Murmur Dev
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout key.pem -out cert.pem -config cert.cnf
/usr/bin/openssl pkcs12 -export -inkey key.pem -in cert.pem -name "Murmur Dev" -out murmur.p12 -passout pass:murmur-tmp
security import murmur.p12 -k ~/Library/Keychains/login.keychain-db -P murmur-tmp -T /usr/bin/codesign
echo "Created Murmur Dev signing certificate."
