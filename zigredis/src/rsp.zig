const std = @import("std");

const RedisRspError = error{
    InvalidResp,
};

pub const ParsedContent = struct {
    data: []const u8,
    ownedData: bool,
};

pub const Resp = struct {
    raw: []const u8,
    pub fn init(data: []const u8) Resp {
        return Resp{
            .raw = data,
        };
    }
    pub fn parse(self: *Resp, alloc: std.mem.Allocator) !ParsedContent {
        var lines = std.mem.tokenizeSequence(u8, self.raw, "\r\n");
        while (lines.next()) |line| {
            if (line.len == 0) {
                return RedisRspError.InvalidResp;
            }
            if (std.mem.eql(u8, line[0..1], "+")) {
                return .{ .data = line[1..], .ownedData = false };
            }
            if (std.mem.eql(u8, line[0..1], "-")) {
                return .{ .data = line[1..], .ownedData = false };
            }
            if (std.mem.eql(u8, line[0..1], ":")) {
                return .{ .data = line[1..], .ownedData = false };
            }
            if (std.mem.eql(u8, line[0..1], "$")) {
                var buf = line[1..];
                if (buf.len == 0) {
                    return RedisRspError.InvalidResp;
                }
                const rsp_len = try std.fmt.parseInt(u32, buf, 10);
                var res = try alloc.alloc(u8, rsp_len);
                errdefer alloc.free(res);
                var l = lines.next();
                if (l == null) {
                    return RedisRspError.InvalidResp;
                }
                buf = l.?;
                if (buf.len != rsp_len) {
                    return RedisRspError.InvalidResp;
                }
                std.mem.copy(u8, res, buf);
                return .{ .data = res, .ownedData = true };
            }
        }
        return RedisRspError.InvalidResp;
    }
};
