#!/bin/bash
set -euo pipefail
sudo docker run -itd --name test-redis -p 6379:6379 redis
