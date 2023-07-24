import sys
import ctypes
import os

LIBC = ctypes.CDLL("libc.so.6")
original_net_ns = open("/proc/self/ns/net", "r")
if True:
    r = LIBC.unshare(CLONE_NEWNET)
    if r != 0:
        print("[!] Are you root? Need unshare systemcall")
        sys.exit(-1)
    LIBC.setns(r, CLONE_NEWNET)


def new_ns():
    r = LIBC.unshare(CLONE_NEWNET)
    if r != 0:
        print("[!] Are you root? Need unshare systemcall")
        sys.exit(-1)
    LIBC.setns(r, CLONE_NEWNS)
    return r

def restore_ns():
    LIBC.setns(original_net_ns.fileno(), CLONE_NEWNET)


ss_bin = os.popen("which ss").read().strip()

def ss(port):
    print(os.popen('%s -t -n -o -a dport = :%s or sport = :%s' % (ss_bin, port, port)).read())
