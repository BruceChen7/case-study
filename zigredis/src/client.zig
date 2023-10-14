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
};

test "client" {
    const client = Client.init("127.0.0.1", 6379);
    try client.connect();
}
