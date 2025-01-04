const std = @import("std");
const net = std.net;
const mem = std.mem;

pub const Client = struct {
    host: []const u8,
    port: u16,
    stream: ?net.Stream,
    read_buf: []u8,
    alloc: std.mem.Allocator,
    pub fn init(host: []const u8, port: u16, alloc: mem.Allocator) !Client {
        const buf = try alloc.alloc(u8, 1024 * 16);
        return Client{
            .host = if (host.len == 0) "localhost" else host,
            .port = port,
            .stream = null,
            .read_buf = buf,
            .alloc = alloc,
        };
    }

    pub fn connect(self: *Client) !void {
        // how to set keep alive
        self.stream = try net.tcpConnectToHost(self.alloc, self.host, self.port);
        const timeout: std.c.timeval = .{ .tv_sec = 3, .tv_usec = 0 };
        // set read timeout
        try std.posix.setsockopt(self.stream.?.handle, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.toBytes(timeout)[0..]);
        // set write timeout
        try std.posix.setsockopt(self.stream.?.handle, std.posix.SOL.SOCKET, std.posix.SO.SNDTIMEO, std.mem.toBytes(timeout)[0..]);

        // set keep alive
        var val: i32 = 1;
        try std.posix.setsockopt(self.stream.?.handle, std.posix.SOL.SOCKET, std.posix.SO.KEEPALIVE, std.mem.asBytes(&val));
    }

    pub fn deinit(self: *Client) void {
        if (self.stream) |s| {
            s.close();
        }
        self.alloc.free(self.read_buf);
    }

    pub fn sendTo(self: *Client, alloc: mem.Allocator, buf: []const u8) !void {
        var i: u32 = 0;
        const len = buf.len;
        while (i < len) {
            const count = self.stream.?.write(buf) catch |err| {
                if (err == std.posix.WriteError.BrokenPipe) {
                    // 重新连接
                    self.stream = try net.tcpConnectToHost(alloc, self.host, self.port);
                    try self.sendTo(alloc, buf);
                }
                return err;
            };
            i += @intCast(count);
        }
    }

    pub fn read(self: *Client) ![]u8 {
        var cnt: usize = 0;
        const buf = self.read_buf;
        retry: for (0..3) |_| {
            cnt = self.stream.?.read(buf) catch |err| {
                // 只重试3次
                if (err == std.posix.ReadError.WouldBlock) {
                    continue :retry;
                }
                // 其余错误直接返错误
                break :retry;
            };
            break :retry;
        }
        return self.read_buf[0..cnt];
    }
};

test "client" {
    const alloc = std.testing.allocator;
    var client = try Client.init("127.0.0.1", 6379, alloc);
    try client.connect();
}
