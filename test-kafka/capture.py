from scapy.all import rdpcap

if __name__ == "__main__":
    r = rdpcap("capture.pcap")
    ## 获取所有的push or ack 的包
