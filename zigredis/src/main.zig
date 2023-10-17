const std = @import("std");
const client = @import("./client.zig");
const req = @import("./req.zig");
const rsp = @import("./rsp.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    defer _ = gpa.deinit();

    // 获取命令行参数-h, -p
    const args = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), args);

    // 判断args是否是-h -p
    if (args.len != 5 and args.len != 1) {
        // 打印帮助信息
        std.debug.print("Usage: {s} -h <host> -p <port>\n", .{args[0]});
        std.process.exit(1);
    }

    var host = if (args.len == 1) "127.0.0.1" else args[2];
    var port = if (args.len == 1) 6379 else std.fmt.parseInt(u16, args[4], 10) catch 6379;
    var c = client.Client.init(host, port);
    try c.connect(alloc);
    defer c.deinit();

    try c.connect(alloc);
    while (true) {
        try std.io.getStdOut().writer().print("{s}:{d}> ", .{ host, port });
        const line = std.io.getStdIn().reader().readUntilDelimiterAlloc(alloc, '\n', 1024) catch |err| {
            if (err == error.EndOfStream) {
                std.debug.print("\n", .{});
                std.debug.print("GoodBye!\n", .{});
            }
            std.process.exit(0);
        };

        var request = req.Request.init(line);
        var command = request.parse(alloc) catch |err| {
            // print errror
            std.debug.print("{s}\n", .{@errorName(err)});
            continue;
        };
        if (command == .Exit) {
            std.process.exit(0);
        }
        var serializeRsp = try command.serialize(alloc);
        defer serializeRsp.deinit(alloc);

        try c.sendTo(alloc, serializeRsp.res[0..serializeRsp.len]);

        var rsp_buf = try alloc.alloc(u8, 1024);
        defer alloc.free(rsp_buf);
        const rsp_size = try c.read(rsp_buf);
        var actRsp = rsp_buf[0..rsp_size];
        var response = rsp.Resp.init(actRsp);
        var val = try response.parse(alloc);
        val.print();
        if (val.ownedData) {
            val.deinit(alloc);
        }
    }
}
