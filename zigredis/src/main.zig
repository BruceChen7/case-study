const std = @import("std");
const client = @import("./client.zig");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    defer _ = gpa.deinit();

    // 获取命令行参数-h, -p
    const args = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), args);

    // 判断args是否是-h -p
    if (args.len != 5) {
        // 打印帮助信息
        std.debug.print("Usage: {s} -h <host> -p <port>\n", .{args[0]});

        std.process.exit(1);
    }
    // 初始化client
    var c = client.Client.init(args[2], try std.fmt.parseInt(u16, args[4], 10));
    try c.connect(alloc);
    // 输出redis> 到终端
    while (true) {
        // 捕捉Ctrl-c信号
        if (std.os.sigaction(std.os.SIG.INT, null, null)) |sa| {
            std.os.sigaction(std.os.SIG.INT, &sa, null);
        }

        try std.io.getStdOut().writer().print("redis> ", .{});
        const line = try std.io.getStdIn().reader().readUntilDelimiterAlloc(alloc, '\n', 1024);
        std.debug.print("{s}\n", .{line});
    }
}
