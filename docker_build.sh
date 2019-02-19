#!/usr/bin/env bash

# Purpose : Build rubyc using docker image ubuntu docker images
# Author  : Ky-Anh Huynh
# License : MIT
# Date    : 2019-Feb-16
# Usage   : Try `$0 help` for more details
# TODO    : Support rubyc-4.0

: "${DOCKER_IMAGE:=ubuntu:16.04}"
: "${RUBY_VERSION:=2.6.0}"

build_base_docker_image() {
  {
    echo "# This file is generated from ${FUNCNAME[0]}."
    echo "# Do not edit this file manually."
    echo "FROM ${DOCKER_IMAGE}"
    echo "ENV DOCKER_IMAGE ${DOCKER_IMAGE}"
    echo "ENV RUBY_VERSION ${RUBY_VERSION}"
    echo "ADD ./docker_build.sh /root/"
    echo "RUN bash /root/docker_build.sh __build_base"
  } > Dockerfile.rubyc_build_base

  docker build -f Dockerfile.rubyc_build_base -t "rubyc-${RUBY_VERSION}-${DOCKER_IMAGE}" .
  docker images | grep -- rubyc-
}

# NOTE: change here invokes new build of base docker image
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

# NOTE: change here invokes new build of base docker image
__build_base() {
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

  __setup
  rbenv install "${RUBY_VERSION}"
  rbenv global "${RUBY_VERSION}"
  ruby -v | grep "${RUBY_VERSION}"

  gem install bundler
}

# NOTE: change here invokes new build of base docker image
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

    export DOCKER_IMAGE="ubuntu:16.04"
    export RUBY_VERSION="2.6.0"

  Without image caching (slow if any error would occur):

    ./docker_build.sh build_rubyc

  With image caching:

    # First we build a base image that contains ruby and other system
    # packages required by the build processes.

    ./docker_build.sh build_base_docker_image

    # Now mount local directory to /src/ and build rubyc by using
    # the previous built docker image.

    # Result is stored in current directory.
    # Warning: This step doesn't build a docker image.

    DOCKER_IMAGE="rubyc-${RUBY_VERSION}-${DOCKER_IMAGE}" \
      ./docker_build.sh build_rubyc

Important notes:

    The build process will delete the local `Gemfile.lock`. This is
    avoid some issue with bundler. Fixing a bundler version can avoid
    this removing step.

EOF
}

"${@:-help}"
