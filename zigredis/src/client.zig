const std = @import("std");
const net = std.net;
const mem = std.mem;

pub const Client = struct {
    host: []const u8,
    port: u16,
    stream: ?net.Stream,

    pub fn init(host: []const u8, port: u16) Client {
        return Client{
            .host = if (host.len == 0) "localhost" else host,
            .port = port,
            .stream = null,
        };
    }

    pub fn connect(self: *Client, alloc: mem.Allocator) !void {
        // how to set keep alive
        self.stream = try net.tcpConnectToHost(alloc, self.host, self.port);
        const timeout: std.os.timeval = .{ .tv_sec = 3, .tv_usec = 0 };
        // set read timeout
        try std.os.setsockopt(self.stream.?.handle, std.os.SOL.SOCKET, std.os.SO.RCVTIMEO, std.mem.toBytes(timeout)[0..]);
        // set write timeout
        try std.os.setsockopt(self.stream.?.handle, std.os.SOL.SOCKET, std.os.SO.SNDTIMEO, std.mem.toBytes(timeout)[0..]);

        // set keep alive
        var val: i32 = 1;
        try std.os.setsockopt(self.stream.?.handle, std.os.SOL.SOCKET, std.os.SO.KEEPALIVE, std.mem.asBytes(&val));
    }
    pub fn deinit(self: *Client) void {
        if (self.stream) |s| {
            s.close();
        }
    }

    pub fn sendTo(self: *Client, alloc: mem.Allocator, buf: []const u8) !void {
        var i: u32 = 0;
        var len = buf.len;
        while (i < len) {
            var count = self.stream.?.write(buf) catch |err| {
                if (err == std.os.WriteError.BrokenPipe) {
                    // 重新连接
                    self.stream = try net.tcpConnectToHost(alloc, self.host, self.port);
                    try self.sendTo(alloc, buf);
                }
                return err;
            };
            i += @intCast(count);
        }
    }

    pub fn read(self: *Client, buf: []u8) !usize {
        var cnt: usize = 0;
        retry: for (0..3) |_| {
            std.debug.print("i = {d}\n", .{i});
            var now = std.time.milliTimestamp();
            cnt = self.stream.?.read(buf) catch |err| {
                // 只重试3次
                if (err == std.os.ReadError.WouldBlock) {
                    continue :retry;
                }
                // 其余错误直接返错误
                break :retry;
            };
            break :retry;
        }
        return cnt;
    }
};

test "client" {
    var client = Client.init("127.0.0.1", 6379);
    try client.connect(std.testing.allocator);
}
