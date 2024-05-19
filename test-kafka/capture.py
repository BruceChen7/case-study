from scapy.all import PcapReader
from scapy.layers.inet import *


def request():
    # 根据correlation id找到对应的数据包，其在header中
    # 是FETCH request
    # 见 https://github.com/BruceChen7/notes/blob/5826647209406e0db11e017f72178c8aae2613bd/Calendar/Daily%20Notes/2024/2024-05-19.md
    # 要获取topic name, 开始到达的时间戳，以及返回的时间戳, partition id
    res = {}
    with PcapReader("capture.pcap") as pcap_reader:
        for packet in pcap_reader:
            if packet.haslayer(TCP):
                src_port = packet[TCP].sport
                dst_port = packet[TCP].dport
                ## 如果tcp flag 是 PUSH 和ACK
                if dst_port == 9093 and packet[TCP].flags == "PA":
                    tcp_payload = bytes(packet[TCP].payload)
                    # print(tcp_payload)
                    # 获取前4个字节的值
                    body_len = tcp_payload[:4]
                    # 将前4个字节的转换成int
                    # 4个是length
                    request_len = int.from_bytes(body_len, byteorder="big") + 4
                    # 从tcp_payload 读取第5个字节和第6个字节
                    body = tcp_payload[4:6]
                    request_type = int.from_bytes(body, byteorder="big")
                    # 表示是FETCH request
                    if request_type == 1:
                        body = tcp_payload[8:12]
                        correction_id = int.from_bytes(body, byteorder="big")
                        # print(
                        #     f"correlation id: {correction_id} src port {src_port} dst port {dst_port}, request body len {request_len}"
                        # )
                        body = tcp_payload[12:14]
                        client_id_len = int.from_bytes(body, byteorder="big")
                        client_id = tcp_payload[14 : 14 + client_id_len]
                        body = tcp_payload[
                            14 + client_id_len + 29 : client_id_len + 14 + 29 + 2
                        ]
                        topic_len = int.from_bytes(body, byteorder="big")
                        body = tcp_payload[
                            client_id_len + 14 + 29 + 2 : client_id_len
                            + 14
                            + 29
                            + 2
                            + topic_len
                        ]
                        topic = str(body, "utf-8")
                        body = tcp_payload[
                            client_id_len + 14 + 29 + 2 + topic_len : client_id_len
                            + 14
                            + 29
                            + 2
                            + topic_len
                            + 4
                        ]
                        partition = int.from_bytes(body, byteorder="big")
                        res[correction_id] = (
                            packet[IP].src,
                            packet[IP].dst,
                            packet.time,
                            topic,
                            partition,
                        )
    return res


def response(req):
    with PcapReader("capture.pcap") as pcap_reader:
        for packet in pcap_reader:
            if packet.haslayer(TCP):
                src_port = packet[TCP].sport
                dst_port = packet[TCP].dport
                ## 如果tcp flag 是 PUSH 和ACK
                # FIXME: more analysis
                if src_port == 9093 and packet[TCP].flags == "PA":
                    # print("src port " + str(src_port) + " dst port " + str(dst_port))
                    tcp_payload = bytes(packet[TCP].payload)
                    correction_id = int.from_bytes(tcp_payload[4:8], byteorder="big")
                    if req.get(correction_id):
                        topic = req[correction_id][3]
                        time = req[correction_id][2]
                        elapsed = packet.time - time
                        # to millisecond
                        elapsed = elapsed * 1000
                        print(
                            f"correlation id: {correction_id}, topic name: {topic}, elapsed time: {elapsed} ms",
                        )


if __name__ == "__main__":
    res = request()
    response(res)
