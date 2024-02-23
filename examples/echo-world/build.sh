#!/usr/bin/env bash

# INSTALL:
#
#   brew install docker docker-buildx
#   mkdir $HOME/.docker/cli-plugins
#   ln -s $(which docker-buildx) $HOME/.docker/cli-plugins
#
#   docker buildx create --name mybuilder --use
#
#   this script
#
#   docker buildx stop mybuilder
#   docker buildx rm mybuilder

export DOCKER_HOST=${DOCKER_HOST:-unix://$HOME/.lima/docker/sock/docker.sock}

# get a version - this may be overkill
if [ -z "$VERSION" ] ; then
  [ -f VERSION ] || touch VERSION
  # get value from the file
  VERSION=$(< VERSION)
#((VERSION++))
  let "VERSION=${VERSION-0}+1"
fi

# may want to point to file's directory not pwd
# APP=${APP:-${PWD##*/}}
APP=${APP:-echo-world}

echo "building '$APP' VERSION '${VERSION}'"

# send to docker (no platform?)
docker buildx build . --load                                    --tag kbrock/${APP}:${VERSION} --tag kbrock/${APP}:latest
# send to registry
docker buildx build . --push --platform linux/amd64,linux/arm64 --tag kbrock/${APP}:${VERSION} --tag kbrock/${APP}:latest

# update the published VERSION
echo $VERSION > VERSION


