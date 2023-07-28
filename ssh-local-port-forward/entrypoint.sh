#!/bin/sh
set -euo pipefail

# 这部分是通过 docker run -v $HOME/.ssh /tmp/ssh 来指定
for file in /tmp/ssh/*.pub; do
  cat ${file} >> /root/.ssh/authorized_keys
done
chmod 600 /root/.ssh/authorized_keys

# Minimal config for the SSH server:
sed -i '/AllowTcpForwarding/d' /etc/ssh/sshd_config
sed -i '/PermitOpen/d' /etc/ssh/sshd_config
/usr/sbin/sshd -e -D &

#  通过 docker run -e port=xxx 指定
python3 -m http.server --bind 127.0.0.1 ${PORT} &

sleep infinity
