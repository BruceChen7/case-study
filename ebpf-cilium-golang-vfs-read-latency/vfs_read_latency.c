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


struct output_events {
    u64 elapsed;
    char process_name[32];
};

struct {
    __uint(type, BPF_MAP_TYPE_QUEUE);
    _type(value, struct output_events);
    __uint(max_entries, 2048);
} result_events SEC(".maps");

SEC("kprobe/vfs_read_entry")
int do_entry(struct pt_regs *ctx)
{
    u32 pid;
    u64 ts;
    pid = bpf_get_current_pid_tgid() >> 32;
    ts = bpf_ktime_get_ns();
    bpf_map_update_elem(&read_events, &pid, &ts, BPF_NOEXIST);
    return 0;
}

SEC("kprobe/vfs_read_return")
int do_return(struct pt_regs *ctx)
{
    u32 pid;
    u64 ts;
    pid = bpf_get_current_pid_tgid() >> 32;
    u64* val = (bpf_map_lookup_elem(&read_events, &pid));
    if (val != NULL ) {
        u64 delta = bpf_ktime_get_ns() - *val;
        char comm[32];
        bpf_get_current_comm(comm, sizeof(comm));
        // bpf_printk("pid is %d, comand is %s", pid, comm);
        bpf_map_delete_elem(&read_events, &pid);
        struct output_events output;
        output.elapsed = delta;
        bpf_probe_read(output.process_name, sizeof(output.process_name), comm);
        bpf_printk("pid is %d, comand is %s", pid, output.process_name);
        bpf_map_push_elem(&result_events, &output, BPF_EXIST);
    }
    return 0;
}

