const std = @import("std");
const client = @import("client.zig");
const req = @import("req.zig");
const rsp = @import("rsp.zig");
const linenose = @cImport(@cInclude("linenoise.h"));
const libc = @cImport(@cInclude("stdlib.h"));
const history = @import("history.zig");
const CmdList = std.ArrayList([]const u8);

var cmdCompleteList: CmdList = undefined;

fn setupCompletion(alloc: std.mem.Allocator) !void {
    cmdCompleteList = CmdList.init(alloc);
    const fields = @typeInfo(req.CommandType).Enum.fields;
    inline for (fields) |field| {
        // 与C 交互的字符串一定要记得这里初始化为0
        var buf = try alloc.alloc(u8, field.name.len + 1);
        @memset(buf, 0);
        var name = std.ascii.lowerString(buf, field.name);
        try cmdCompleteList.append(name);
    }
}

fn deinitCompletionList(alloc: std.mem.Allocator) void {
    for (cmdCompleteList.items) |item| {
        alloc.free(item);
    }
    cmdCompleteList.deinit();
}

pub fn completionCallback(buf: [*c]const u8, lc: [*c]linenose.linenoiseCompletions) callconv(.C) void {
    var b: [:0]const u8 = std.mem.span(buf);
    if (b.len == 0) {
        return;
    }

    for (cmdCompleteList.items) |item| {
        if (b.len > item.len) {
            return;
        }
        const len = b.len;
        if (std.ascii.eqlIgnoreCase(item[0..len], b[0..len])) {
            linenose.linenoiseAddCompletion(lc, item[0..item.len].ptr);
        }
    }
}

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

    linenose.linenoiseSetMultiLine(0);
    linenose.linenoiseSetCompletionCallback(completionCallback);
    _ = linenose.linenoiseHistoryLoad(@as([:0]const u8, "history.txt"));
    try setupCompletion(alloc);
    defer deinitCompletionList(alloc);

    while (true) {
        var buf: [256]u8 = .{0} ** 256;
        const prompt = try std.fmt.bufPrint(&buf, "{s}:{d}> ", .{ host, port });

        const line = linenose.linenoise(prompt[0..prompt.len].ptr);
        if (line == null) {
            std.debug.print("\n", .{});
            std.debug.print("GoodBye!\n", .{});
            std.process.exit(0);
        }
        defer libc.free(line);
        // https://stackoverflow.com/questions/72736997/how-to-pass-a-c-string-into-a-zig-function-expecting-a-zig-string
        const input: [:0]const u8 = std.mem.span(line.?);
        var request = req.Request.init(input);
        var command = request.parse(alloc) catch |err| {
            // print errror
            std.debug.print("{s}\n", .{@errorName(err)});
            continue;
        };
        defer command.deinit();

        if (command == .Exit) {
            std.process.exit(0);
        }
        var serializeRsp = try command.serialize(alloc);
        // TODO(ming.chen): rewrite it
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
        history.saveHistory(input, "history.txt");
    }
}
