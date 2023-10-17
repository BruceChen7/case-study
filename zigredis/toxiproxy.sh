#!/bin/bash

set -euo pipefail
log_level=fatal
LOG_LEVEL=${log_level} toxiproxy-server &
echo "waiting for server to start"

# 8474 is the default port
while ! nc -z localhost 8474; do
    print .
    sleep 1
done
echo "server started"
# https://github.com/Shopify/toxiproxy/tree/main#slicer
# https://github.com/hyperfiddle/electric/blob/67d05d28cc2d2f686d810ea94f66995f0ca815a9/src-dev/toxiproxy.sh#L13

