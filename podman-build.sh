#!/bin/bash

set -x

PODMAN="$(which podman)"

if [ $? != 0 ]; then
  echo "Podman is not installed."
  exit
fi

$PODMAN build --no-cache --network=host \
  --env="$MQADMINCACERT" \
  --env="$MQADMINUSERNAME" \
  --env="$MQADMINPASSWORD" \
  --env="$MQADMINPORT" \
  --env="$MQSSL" \
  --env="$MQSSLCACERT" \
  --env="$MQSSLHOST" \
  --env="$MQSSLUSERNAME" \
  --env="$MQSSLPASSWORD" \
  --env="$MQSSLVHOST" \
  --env="$MQHOST" \
  --env="$MQUSERNAME" \
  --env="$MQPASSWORD" \
  --env="$MQVHOST" \
  .
