const std = @import("std");

const CommandType = enum { Get, Set, Auth };

pub const KV = struct {
    key: []const u8,
    value: []const u8,
};

const Command = union(CommandType) {
    Get: []const u8,
    Set: KV,
    Auth: []const u8,

    pub fn serialize(self: *Command) []const u8 {
        switch (self.*) {
            CommandType.Get => {
                return "GET";
            },
            CommandType.Set => {
                return "SET";
            },
            CommandType.Auth => {
                return "AUTH";
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
        }
        return RedisCientError.UnknownCommand;
    }
};
