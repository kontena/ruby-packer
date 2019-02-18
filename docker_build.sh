#!/usr/bin/env bash

# Purpose : Build ruby using docker image ubuntu:18.04
# Author  : Ky-Anh Huynh
# License : MIT
# Date    : 2019-Feb-16

build_docker_image() {
  {
    : "${DOCKER_IMAGE:=ubuntu:16.04}"
    echo "FROM ${DOCKER_IMAGE}"
    echo "ENV DOCKER_IMAGE ${DOCKER_IMAGE}"
    echo "ADD ./docker_build.sh /root/"
    echo "RUN bash /root/docker_build.sh __build_base"
  } > Dockerfile.rubyc_build_base

  docker build -f Dockerfile.rubyc_build_base -t "rubyc_build_base" .
}

__setup() {
  set -uex

  echo "## Your build environment"
  env
  echo "## DNS resolvers"
  cat /etc/resolv.conf

  export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$HOME/.rbenv/bin:$PATH"
  if command -v rbenv >/dev/null; then
    eval "$(rbenv init -)"
  fi
}

__build_base() {
  __setup

  __apt_get_install() {
    apt-get update
    echo Y | apt-get install \
      build-essential \
      bison git \
      openssl \
      libssl-dev \
      texinfo \
      squashfs-tools \
      wget \
      libreadline-dev zlib1g-dev \
      pkg-config
  }

  __apt_get_install

  [[ -d ~/.rbenv ]] \
  || git clone https://github.com/rbenv/rbenv.git ~/.rbenv
  [[ -d ~/.rbenv/plugins/ruby-build ]] \
  || git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

  rbenv install 2.6.0
  rbenv global 2.6.0
  ruby -v | grep 2.6.0

  gem install bundler
}

_build_rubyc() {
  __setup

  if ! command -v rbenv >/dev/null; then
    __build_base
  fi

  rm -fv Gemfile.lock
  bundler install
  # bundle exec rake rubyc
  # export ENCLOSE_IO_ALWAYS_USE_ORIGINAL_RUBY=1
  # export ENCLOSE_IO_USE_ORIGINAL_RUBY=1

  # FIXME: removing the cache /tmp/rubyc/
  rm -fv rubyc
  # from .travis/test.sh
  ruby -Ilib bin/rubyc bin/rubyc \
    --openssl-dir=/etc/ssl/ \
    --ignore-file=.git \
    --ignore-file=.gitignore \
    --ignore-file=.gitmodules \
    --ignore-file=CHANGELOG.md \
    --ignore-file=ruby.patch \
    --ignore-file=.travis.yml \
    --ignore-file=.travis/test.sh \
    --ignore-file=.travis/install_deps.sh \
    --ignore-file=docker_build.sh \
    -o rubyc
}

# Enter an interactive shell by default, and allow to debug this script.
docker_start() {
  docker run \
    --name rubyc-build --rm -ti \
    -v "$(pwd -P)":/src/ -w /src/ \
    "${DOCKER_IMAGE:-ubuntu:16.04}" bash "$@"
}

build_rubyc() {
  set -xeu
  docker_start "$(basename "${BASH_SOURCE[0]:-$0}")" _build_rubyc
}

help() {
  cat <<'EOF'
Usage:

  Without caching image:

    DOCKER_IMAGE="ubuntu:16.04" ./docker_build.sh build_rubyc

  With caching image:

    DOCKER_IMAGE="ubuntu:16.04"     ./docker_build.sh build_docker_image
    DOCKER_IMAGE="rubyc_build_base" ./docker_build.sh build_rubyc
EOF
}

"${@:-help}"
