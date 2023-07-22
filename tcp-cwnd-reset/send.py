import socket
import sys
import time

ip = sys.argv[1]
port = int(sys.argv[2])

s = socket.socket()
s.connect((ip, port))

char = "a".encode("utf8")
size = 1 * 1024 * 1024
data = char * size

def send():
    print("start sending...1 M data")
    s.send(data)
    print("sending done")

if __name__ == "__main__":
    while 1:
        send()
        for count in range(10, 0, -1):
            print("sending next in %ds" % count)
            time.sleep(1)
