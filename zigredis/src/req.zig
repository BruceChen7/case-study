const std = @import("std");

const CommandType = enum { Get, Set, Auth, Exit };
pub fn GetCommandStr(command: CommandType) []const u8 {
    switch (command) {
        .Get => {
            return "GET";
        },
        .Set => {
            return "SET";
        },
        .Auth => {
            return "AUTH";
        },
        .Exit => {
            return "EXIT";
        },
    }
    return "";
}

pub const KV = struct {
    key: []const u8,
    value: []const u8,
};

pub const SerializeReqRes = struct {
    res: []const u8,
    len: u32,
};

const Command = union(CommandType) {
    Get: []const u8,
    Set: KV,
    Auth: []const u8,
    Exit: void,

    pub fn serialize(self: *const Command, alloc: std.mem.Allocator) !SerializeReqRes {
        switch (self.*) {
            .Get => |key| {
                const buf = try alloc.alloc(u8, 1024);
                const rsp = try std.fmt.bufPrint(buf[0..], "*2\r\n$3\r\nGET\r\n${d}\r\n{s}\r\n", .{ key.len, key });
                return .{ .res = buf, .len = @intCast(rsp.len) };
            },
            .Set => |kv| {
                const buf = try alloc.alloc(u8, 1024);
                const rsp = try std.fmt.bufPrint(buf[0..], "*3\r\n$3\r\nSET\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{ kv.key.len, kv.key, kv.value.len, kv.value });
                return .{ .res = buf, .len = @intCast(rsp.len) };
            },
            else => {
                return RedisClientError.UnknownCommand;
            },
        }
    }
};

const RedisClientError = error{
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

            if (std.mem.eql(u8, buf, GetCommandStr(.Get))) {
                var it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                return Command{ .Get = it.? };
            }
            if (std.mem.eql(u8, buf, GetCommandStr(.Set))) {
                var it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                var key = it.?;
                it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                var value = it.?;
                return Command{
                    .Set = KV{
                        .key = key,
                        .value = value,
                    },
                };
            }
            if (std.mem.eql(u8, buf, GetCommandStr(.Auth))) {
                return Command{
                    .Auth = lines.next().?,
                };
            }

            if (std.mem.eql(u8, buf, GetCommandStr(.Exit))) {
                return Command{
                    .Exit = void{},
                };
            }
        }
        return RedisClientError.UnknownCommand;
    }
};
