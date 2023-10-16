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
        self.stream = try net.tcpConnectToHost(alloc, self.host, self.port);
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
        var res = try self.stream.?.read(buf);
        return res;
    }
};

test "client" {
    const client = Client.init("127.0.0.1", 6379);
    try client.connect();
}
