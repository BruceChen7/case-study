// +build ignore

#include "vmlinux.h"
#include "bpf_helpers.h"

char __license[] SEC("license") = "Dual MIT/GPL";

struct  {
    // hash type
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 100);
    __type(key, u32);
    __type(value, u64);
} read_events SEC(".maps");

SEC("sys_read/entry")
int do_entry(struct pt_regs *ctx)
{
    u32 pid;
    u64 ts;
    pid = bpf_get_current_pid_tgid();
    ts = bpf_ktime_get_ns();
    bpf_map_update_elem(&read_events, &pid, &ts, BPF_NOEXIST);
    return 0;
}

SEC("sys_read/return")
int do_return(struct pt_regs *ctx)
{
    u32 pid;
    u64 ts;
    pid = bpf_get_current_pid_tgid();
    ts = bpf_ktime_get_ns();
    bpf_map_update_elem(&read_events, &pid, &ts, BPF_NOEXIST);
    return 0;
}

