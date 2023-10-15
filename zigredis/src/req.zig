const std = @import("std");

const CommandType = enum { Get, Set, Auth, Exit };

pub const KV = struct {
    key: []const u8,
    value: []const u8,
};

pub const SerializeResp = struct {
    res: []const u8,
    len: u32,
};

const Command = union(CommandType) {
    Get: []const u8,
    Set: KV,
    Auth: []const u8,
    Exit: void,

    pub fn serialize(self: *const Command, alloc: std.mem.Allocator) !SerializeResp {
        switch (self.*) {
            CommandType.Get => |key| {
                // 字符串拼接
                // int covert to string
                const buf = try alloc.alloc(u8, 1024);
                const rsp = try std.fmt.bufPrint(buf[0..], "*2\r\n$3\r\nGET\r\n${d}\r\n{s}\r\n", .{ key.len, key });
                return .{ .res = buf, .len = @intCast(rsp.len) };
            },
            else => {
                return error.UnknownCommand;
            },
        }
    }
};

const RedisCientError = error{
    AllocatorError,
    InvalidCommandParam,
    UnknownCommand,
};

pub const Request = struct {
    content: []const u8,

    pub fn init(data: []const u8) Request {
        return Request{
            .content = data,
        };
    }

    pub fn parse(self: *Request, alloc: std.mem.Allocator) !Command {
        self.content = std.mem.trim(u8, self.content, " ");

        var lines = std.mem.tokenizeScalar(u8, self.content, ' ');
        // 遍历lines
        while (lines.next()) |line| {
            // 转成大写
            const buf = try alloc.alloc(u8, line.len);
            defer alloc.free(buf);

            _ = std.ascii.upperString(buf, line);

            if (std.mem.eql(u8, buf, "GET")) {
                var it = lines.next();
                if (it == null) {
                    return RedisCientError.InvalidCommandParam;
                }
                return Command{ .Get = it.? };
            }
            if (std.mem.eql(u8, buf, "SET")) {
                var it = lines.next();
                if (it == null) {
                    return RedisCientError.InvalidCommandParam;
                }
                var key = it.?;
                it = lines.next();
                if (it == null) {
                    return RedisCientError.InvalidCommandParam;
                }
                var value = it.?;
                return Command{
                    .Set = KV{
                        .key = key,
                        .value = value,
                    },
                };
            }
            if (std.mem.eql(u8, buf, "AUTH")) {
                return Command{
                    .Auth = lines.next().?,
                };
            }

            if (std.mem.eql(u8, buf, "EXIT")) {
                return Command{
                    .Exit = void{},
                };
            }
        }
        return RedisCientError.UnknownCommand;
    }
};
