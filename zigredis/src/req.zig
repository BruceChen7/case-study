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
        // 按照\分割成多个字符串
        // trim self.content的前后的空格
        self.content = std.mem.trim(u8, self.content, " ");

        var lines = std.mem.tokenizeScalar(u8, self.content, ' ');
        // 遍历lines
        while (lines.next()) |line| {
            // 转成大写
            const buf = try alloc.alloc(u8, line.len);
            defer alloc.free(buf);

            _ = std.ascii.upperString(buf, line);

            if (std.mem.eql(u8, buf, "GET")) {
                return Command{
                    .Get = lines.next().?,
                };
            }
            if (std.mem.eql(u8, buf, "SET")) {
                return Command{
                    .Set = KV{
                        .key = lines.next().?,
                        // TODO(ming.chen): add lines compare
                        .value = lines.next().?,
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
