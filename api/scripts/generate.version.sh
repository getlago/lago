#!/bin/bash

cd $LAGO_PATH/api

VERSION=`git tag --points-at HEAD | tail -1`

if [ "${#VERSION}" -eq "0" ]; then
  VERSION=`git rev-parse HEAD`
fi

echo "Current version: ${VERSION}"

echo $VERSION > $LAGO_PATH/api/LAGO_VERSION
