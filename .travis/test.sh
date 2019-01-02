#!/bin/sh

set -uex

if [ "$TRAVIS_OS_NAME" = "osx" ]; then
  OPENSSLDIR="/usr/local/etc/openssl"
  TEMP_DIR="$(mktemp -d)"
else
  OPENSSLDIR="/etc/ssl"
  TEMP_DIR="$(mktemp -d --tmpdir=$HOME .rubyc-build.XXXXXX)"
fi

mksquashfs -version

ruby -Ilib bin/rubyc bin/rubyc \
  --openssl-dir=${OPENSSLDIR} \
  --tmpdir=${TEMP_DIR} \
  --clean-tmpdir \
  --ignore-file=.git \
  --ignore-file=.travis.yml \
  --ignore-file=.travis/deploy.sh \
  --ignore-file=.travis/install_deps.sh \
  -o rubyc

strip rubyc || true

./rubyc --version

bundle exec rake test

