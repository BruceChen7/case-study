## 什么是bridge
* [Linux 虚拟网络设备](https://morven.life/posts/networking-2-virtual-devices/)
* 叫作网桥，是一种虚拟网络设备，
* 所以具有虚拟网络设备的特征，可以配置 IP、MAC 地址等。
* bridge 是一个虚拟交换机，和物理交换机有类似的功能。
    * bridge 一端连接着协议栈，
    * 另外一端有多个端口，数据在各个端口间转发数据包是基于MAC地址。
* bridge可以工作在二层(链路层)，也可以工作在三层（IP 网路层）。
* 默认情况下，其工作在二层，可以在同一子网内的的不同主机间转发以太网报文；
* 当给 bridge 分配了 IP 地址，也就开启了该 bridge 的三层工作模式。
* 练习需要
    ```bash
    # echo 1 > /proc/sys/net/ipv4/conf/veth1/accept_local
    # echo 1 > /proc/sys/net/ipv4/conf/veth0/accept_local
    # echo 0 > /proc/sys/net/ipv4/conf/veth0/rp_filter
    # echo 0 > /proc/sys/net/ipv4/conf/veth1/rp_filter
    # echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
    ```
    * 有些版本的有可能会 ping 不通，原因是默认情况下内核网络配置导致 veth 设备对无法返回 ARP 包，
    * 解决办法是配置 veth 设备可以返回 ARP 包

* 在 Linux 下，可以用 iproute2 或 brctl 命令对 bridge 进行管理
    ```bash
    sudo ip link add name br0 type bridge
    sudo ip link set br0 up
    ip addr
    1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
        link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
        inet 127.0.0.1/8 scope host lo
           valid_lft forever preferred_lft forever
        inet6 ::1/128 scope host noprefixroute
           valid_lft forever preferred_lft forever
    2: enp0s31f6: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc fq state DOWN group default qlen 1000
        link/ether 8c:16:45:a8:a8:41 brd ff:ff:ff:ff:ff:ff
    3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
        link/ether b4:6b:fc:35:c3:d4 brd ff:ff:ff:ff:ff:ff
        inet 192.168.0.104/24 brd 192.168.0.255 scope global dynamic noprefixroute wlan0
           valid_lft 7092sec preferred_lft 7092sec
        inet6 fe80::1e94:1d0c:1bfd:c0de/64 scope link noprefixroute
           valid_lft forever preferred_lft forever
    4: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1230 qdisc fq state UNKNOWN group default qlen 500
        link/none
        inet 192.168.76.15/32 scope global tun0
           valid_lft forever preferred_lft forever
    5: br0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
        link/ether 3a:44:5a:80:8d:01 brd ff:ff:ff:ff:ff:ff
    ```
* ![img](https://i.loli.net/2020/01/28/JljuUAEyNRfb6Dq.jpg)
* 这样创建出来的 bridge 一端连接着协议栈，其他端口什么也没有连接，
* 需要将其他设备连接到该 bridge 才能有实际的功能：
    ```bash
    # 添加 veth0 和 veth1
    sudo ip link add veth0 type veth peer name veth1
    sudo ip addr add 20.1.0.10/24 dev veth0
    sudo ip addr add 20.1.0.11/24 dev veth1
    sudo ip link set veth0 up
    sudo ip link set veth1 up
    ip addr

    veth1@veth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
        link/ether c6:bb:54:5c:6d:a6 brd ff:ff:ff:ff:ff:ff
        inet 20.1.0.11/24 scope global veth1
           valid_lft forever preferred_lft forever
        inet6 fe80::c4bb:54ff:fe5c:6da6/64 scope link proto kernel_ll
           valid_lft forever preferred_lft forever
    7: veth0@veth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
        link/ether 12:54:f2:a8:2f:82 brd ff:ff:ff:ff:ff:ff
        inet 20.1.0.10/24 scope global veth0
           valid_lft forever preferred_lft forever
        inet6 fe80::1054:f2ff:fea8:2f82/64 scope link proto kernel_ll
           valid_lft forever preferred_lft forever

    # 将 veth0 连接到 br0
    ip link set dev veth0 master br0
    # 查看bridge上连接拉1哪些设备
    bridge link
    7: veth0@veth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master br0 state forwarding priority 32 cost 2
    ```
* ![img](https://i.loli.net/2020/01/28/NCUXi4l7zBo83ev.jpg)
* 一旦 br0 和 veth0 连接之后，它们之间将变成双向通道，
* 内核协议栈和 veth0 之间变成了单通道，
* **协议栈能发数据给veth0**，veth0**从外面收到的数据不会转发给协议栈**，
* 同时**br0的MAC 地址变成了veth0的 MAC 地址**。
* 验证一下：
    ```bash
    ping -c 1 -I veth0 20.1.0.11
    PING 20.1.0.11 (20.1.0.10) 来自 20.1.0.10 veth0 56(84) 字节的数据。
    来自 20.1.0.10 icmp_seq=1 目标主机不可达
    --- 20.1.0.11 ping 统计 ---
    已发送 1 个包， 已接收 0 个包, +1 错误, 100% packet loss, time 0ms
    ```
* 看到 veth0 收到应答包后没有给协议栈，而是直接转发给 br0，这样协议栈得不到 veth1 的 MAC 地址，从而 ping 不通。
* br0 在veth 和协议栈之间将数据包给拦截了。
* 可以理解成下面的结构
    * ![img](https://i.loli.net/2020/01/28/nuKtLZyaRhXqjDp.jpg)
* 但是如果给br0 配置 IP，会怎么样呢？
* 这时候再通过**br0 来 ping 一下 veth1，会发现结果可以通**：
    ```bash
    # ping -c 1 -I br0 20.1.0.11
    PING 20.1.0.11 (20.1.0.11) from 20.1.0.10 br0: 56(84) bytes of data.
    64 bytes from 20.1.0.11: icmp_seq=1 ttl=64 time=0.121 ms

    --- 20.1.0.11 ping statistics ---
    1 packets transmitted, 1 received, 0% packet loss, time 0ms
    rtt min/avg/max/mdev = 0.121/0.121/0.121/0.000 ms
    ```
* 当去掉veth0 的IP，而给 br0 配置了IP之后，协议栈在**路由的时候不会将数据包发给 veth0**，
* 为表达更直观，协议栈和 veth0 之间的连接线去掉，**这时候的veth0 相当于一根网线**。

