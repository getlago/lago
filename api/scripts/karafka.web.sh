#!/bin/bash

if [ -v LAGO_KARAFKA_WEB ] && [ "$LAGO_KARAFKA_WEB" == "true" ]
then
  karafka-web migrate --replication-factor=1
fi
