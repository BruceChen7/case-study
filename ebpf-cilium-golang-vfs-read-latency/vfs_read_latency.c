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
    __uint(type, BPF_MAP_TYPE_PERF_EVENT_ARRAY);
    __uint(key_size, sizeof(u32));
    __uint(value_size, sizeof(u32));
    __uint(max_entries, 8192);
} result_events SEC(".maps");

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
    u64* val = (bpf_map_lookup_elem(&read_events, &pid));
    if (val != NULL ) {
        u64 delta = bpf_ktime_get_ns() - *val;
        char comm[32];
        bpf_get_current_comm(comm, sizeof(comm));
        bpf_printk("pid is %d, comand is %s", pid, comm);
        struct output_events output;
        output.elapsed = delta;
        bpf_probe_read_user(output.process_name, sizeof(output.process_name), comm);
        bpf_perf_event_output(ctx, &read_events, 0,  &output, sizeof(output));
    }
    return 0;
}

