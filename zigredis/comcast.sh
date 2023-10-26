#!/bin/bash
set -euo pipefail

# check if the comcast has been installed
if ! command -v comcast &> /dev/null
then
    echo "comcast could not be found"
    echo "installing comcast"
    go install github.com/tylertreat/comcast@latest
fi

system="linux"
# check if it is in linux system or macos
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    system="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    system="macos"
else
    echo "unsupported system"
    exit 1
fi

# if arg num is not 3 or 2, print usage
if [[ $# -ne 4 && $# -ne 1 ]]; then
    echo "usage: comcast.sh start <device> <latency> <packet-loss>  | comcast.sh stop"
    exit 1
fi

# if first subcommand is stop, then stop it
if [[ "$1" == "stop" ]]; then
    comcast --stop
    exit 0
fi

# if first subcommand is not start, print usage
if [[ "$1" != "start" ]]; then
    echo "usage: comcast.sh start <device> <latency> <packet-loss>"
    exit 1
fi

device=$2
latency=$3
packet_loss=$4

if [[ "$system" == "linux" ]]; then
    # $ comcast --device=eth0 --latency=250 --target-bw=1000 --default-bw=1000000 --packet-loss=10% --target-addr=8.8.8.8,10.0.0.0/24 --target-proto=tcp,udp,icmp --target-port=80,22,1000:2000
    comcast --device=${device} --latency=${latency} --target-bw=1000000 --default-bw=1000000 --packet-loss=${packet_loss}% --target-addr=127.0.0.1 --target-proto=tcp --target-port=6379
else
    # not support ip port
    # in mac, latency means src -> dst latency, not rtt time
    comcast --device=${device} --latency=${latency} --target-bw=1000 --packet-loss=${packet_loss}%
fi

