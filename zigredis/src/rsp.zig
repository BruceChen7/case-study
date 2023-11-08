const std = @import("std");

const RedisRspError = error{
    InvalidResp,
};

const RspType = enum {
    SimpleString,
    SimpleErrors,
    BulkString,
    Doubles,
    Arrays,
    Integer,
};

const RspData = union(RspType) {
    SimpleString: []const u8,
    SimpleErrors: []const u8,
    BulkString: []const u8,
    Arrays: ?[][]const u8,
    Integer: []const u8,
    Doubles: []const u8,
};

pub const ParsedContent = struct {
    data: RspData,
    ownedData: bool,

    pub fn deinit(self: *ParsedContent, alloc: std.mem.Allocator) void {
        if (self.ownedData) {
            switch (self.data) {
                .SimpleString, .SimpleErrors, .BulkString, .Integer, .Doubles => |s| {
                    alloc.free(s);
                },
                .Arrays => |s| {
                    var i: usize = 0;
                    while (i < s.?.len) : (i += 1) {
                        alloc.free(s.?[i]);
                    }
                    alloc.free(s.?);
                },
            }
        }
    }
    pub fn print(self: *ParsedContent) void {
        switch (self.data) {
            .SimpleString, .SimpleErrors, .BulkString, .Doubles => |s| {
                std.debug.print("{s}\n", .{s});
            },
            .Integer => |s| {
                // TODO(ming.chen): try to color integer
                std.debug.print("(integer) {s}\n", .{s});
            },
            .Arrays => |content| {
                if (content == null) {
                    std.debug.print("(nil)\n", .{});
                    return;
                }
                for (content.?, 0..) |c, i| {
                    if (std.mem.eql(u8, c, "nil")) {
                        std.debug.print("{d}) ({s})\n", .{ i + 1, c });
                    } else {
                        std.debug.print("{d}) \"{s}\"\n", .{ i + 1, c });
                    }
                }
            },
        }
    }
};

pub const Resp = struct {
    raw: []const u8,
    pub fn init(data: []const u8) Resp {
        return Resp{
            .raw = data,
        };
    }

    fn parseLength(buf: []const u8) !i32 {
        if (buf.len == 0) {
            return RedisRspError.InvalidResp;
        }
        if (buf[0] != '$') {
            return RedisRspError.InvalidResp;
        }
        const rsp_len = std.fmt.parseInt(i32, buf[1..], 10) catch |err| {
            std.debug.print("err: {s}\n", .{@errorName(err)});
            return RedisRspError.InvalidResp;
        };
        return rsp_len;
    }
    // TODO(ming.chen):  need to return half read of data
    pub fn parse(self: *Resp, alloc: std.mem.Allocator) !ParsedContent {
        var lines = std.mem.tokenizeSequence(u8, self.raw, "\r\n");
        while (lines.next()) |line| {
            if (line.len == 0) {
                return RedisRspError.InvalidResp;
            }
            if (std.mem.eql(u8, line[0..1], "+")) {
                // is string
                var buf = try alloc.alloc(u8, line.len + 1);
                errdefer alloc.free(buf);
                var res = try std.fmt.bufPrint(buf, "\"{s}\"", .{line[1..]});
                return .{ .data = .{ .SimpleString = res }, .ownedData = true };
            }
            if (std.mem.eql(u8, line[0..1], "-")) {
                return .{ .data = .{ .SimpleErrors = line[1..] }, .ownedData = false };
            }
            //  TODO(ming.chen): need to parse it as integer
            if (std.mem.eql(u8, line[0..1], ":")) {
                return .{ .data = .{ .Integer = line[1..] }, .ownedData = false };
            }
            if (std.mem.eql(u8, line[0..1], ",")) {
                return .{ .data = .{ .Doubles = line[1..] }, .ownedData = false };
            }
            if (std.mem.eql(u8, line[0..1], "$")) {
                var buf = line[1..];
                if (buf.len == 0) {
                    return RedisRspError.InvalidResp;
                }
                if (buf[0] == '-') {
                    if (buf.len < 2) {
                        return RedisRspError.InvalidResp;
                    }
                    if (buf[1] == '1') {
                        return .{ .data = .{ .BulkString = "(nil)" }, .ownedData = false };
                    }
                }
                const rsp_len = try std.fmt.parseInt(u32, buf, 10);
                var l = lines.next();
                if (l == null) {
                    return RedisRspError.InvalidResp;
                }
                buf = l.?;
                if (buf.len != rsp_len) {
                    return RedisRspError.InvalidResp;
                }
                var res = try alloc.alloc(u8, rsp_len);
                errdefer alloc.free(res);
                std.mem.copy(u8, res, buf);
                return .{ .data = .{ .BulkString = res }, .ownedData = true };
            }
            // means array
            if (std.mem.eql(u8, line[0..1], "*")) {
                var buf = line[1..];
                if (buf.len == 0) {
                    return RedisRspError.InvalidResp;
                }
                const array_len = try std.fmt.parseInt(i32, buf[0..], 10);
                if (array_len == -1) {
                    return .{ .data = .{ .Arrays = null }, .ownedData = false };
                }
                var res = try alloc.alloc([]const u8, @intCast(array_len));
                var numAllocated: u32 = 0;
                errdefer for (0..numAllocated) |i| {
                    alloc.free(res[i]);
                };
                errdefer alloc.free(res);

                var i: u32 = 0;
                while (i < array_len) : (i += 1) {
                    const length = if (lines.next()) |l| parseLength(l) catch -1 else -2;
                    if (length == -1) {
                        var val = try alloc.alloc(u8, 3);
                        errdefer alloc.free(val);
                        std.mem.copy(u8, val, "nil");
                        numAllocated += 1;
                        res[i] = val;
                        continue;
                    }
                    if (length < 0) {
                        return RedisRspError.InvalidResp;
                    }
                    if (lines.next()) |l| {
                        if (l.len < length) {
                            return RedisRspError.InvalidResp;
                        }
                        var val = try alloc.alloc(u8, @intCast(length));
                        errdefer alloc.free(val);
                        @memcpy(val, l[0..@intCast(length)]);
                        numAllocated += 1;
                        res[i] = val;
                    } else {
                        return RedisRspError.InvalidResp;
                    }
                }
                return .{ .data = .{ .Arrays = res }, .ownedData = true };
            }
        }
        return RedisRspError.InvalidResp;
    }
};

test "resp parse" {
    // create a string
    const data = "+OK\r\n";
    var buf = data[0..data.len];
    var resp = Resp.init(buf);
    var res = try resp.parse(
        std.testing.allocator,
    );
    defer res.deinit(std.testing.allocator);
    try std.testing.expectEqual(res.ownedData, true);
    try std.testing.expectEqualDeep(res.data.SimpleString, "\"OK\"");

    // create a integer
    const data2 = ":123\r\n";
    var buf2 = data2[0..data2.len];
    var resp2 = Resp.init(buf2);
    var res2 = try resp2.parse(
        std.testing.allocator,
    );
    defer res2.deinit(std.testing.allocator);
    try std.testing.expectEqual(res2.ownedData, false);
    try std.testing.expectEqualDeep(res2.data.Integer, "123");

    // array string
    const data3 = "*3\r\n$3\r\nfoo\r\n$3\r\nbar\r\n$-1\r\n";
    var buf3 = data3[0..data3.len];
    var resp3 = Resp.init(buf3);
    var res3 = try resp3.parse(
        std.testing.allocator,
    );
    defer res3.deinit(std.testing.allocator);
    try std.testing.expectEqual(res3.ownedData, true);
    const arrayRes = res3.data.Arrays.?;
    try std.testing.expectEqual(arrayRes.len, 3);
    try std.testing.expectEqualDeep(arrayRes[0], "foo");
    try std.testing.expectEqualDeep(arrayRes[1], "bar");
    try std.testing.expectEqualDeep(arrayRes[2], "nil");
}
