const std = @import("std");

const CommandType = enum {
    Get,
    Set,
    Auth,
    Exit,
    Incr,
    Ping,
    DEL,
    LPUSH,
};
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
        .Incr => {
            return "INCR";
        },
        .Ping => {
            return "PING";
        },
        .DEL => {
            return "DEL";
        },
        .LPUSH => {
            return "LPUSH";
        },
    }
    return "";
}

pub const KV = struct {
    // GET, SET, AUTH, EXIT etc
    commandStr: []const u8,
    // ping is empty
    key: ?[]const u8,
    value: ?[]const u8,
    // for get is 2, for set is 3
    argsNum: u8,
};

pub const SerializeReqRes = struct {
    res: []const u8,
    len: u32,
};

const Command = union(CommandType) {
    Get: KV,
    Incr: KV,
    Set: KV,
    Auth: KV,
    Exit: void,
    Ping: KV,
    DEL: KV,
    LPUSH: KV,

    pub fn serialize(self: *const Command, alloc: std.mem.Allocator) !SerializeReqRes {
        switch (self.*) {
            .Get, .Set, .Auth, .Ping, .DEL, .LPUSH, .Incr => |c| {
                return Command.serializeHelper(alloc, c);
            },
            else => {
                return RedisClientError.UnknownCommand;
            },
        }
    }

    fn serializeHelper(alloc: std.mem.Allocator, command: KV) !SerializeReqRes {
        const buf = try alloc.alloc(u8, 1024);
        const totalNum = command.argsNum + 1;
        const commandStr = command.commandStr;
        const keyLen = if (command.key) |key| key.len else 0;
        const key = command.key orelse "";
        var rsp = try std.fmt.bufPrint(buf[0..], "*{d}\r\n${d}\r\n{s}\r\n", .{ totalNum, commandStr.len, commandStr });
        var validLen = rsp.len;
        if (keyLen != 0) {
            rsp = try std.fmt.bufPrint(buf[rsp.len..], "${d}\r\n{s}\r\n", .{ keyLen, key });
            validLen += rsp.len;
            rsp = buf[0..validLen];
        }
        const valueLen = if (command.value) |value| value.len else 0;
        if (valueLen != 0) {
            rsp = try std.fmt.bufPrint(buf[rsp.len..], "${d}\r\n{s}\r\n", .{ valueLen, command.value.? });
            validLen += rsp.len;
            rsp = buf[0..validLen];
        }
        return .{ .res = buf, .len = @intCast(rsp.len) };
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
                return Command{ .Get = .{ .key = it.?, .argsNum = 1, .value = null, .commandStr = "GET" } };
            }
            if (std.mem.eql(u8, buf, GetCommandStr(.Incr))) {
                var it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                return Command{ .Incr = .{ .key = it.?, .argsNum = 1, .value = null, .commandStr = "INCR" } };
            }
            if (std.mem.eql(u8, buf, GetCommandStr(.Ping))) {
                return Command{ .Ping = .{ .key = null, .argsNum = 0, .value = null, .commandStr = "PING" } };
            }
            if (std.mem.eql(u8, buf, GetCommandStr(.Set))) {
                var it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                const key = it.?;
                it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                const value = it.?;
                return Command{
                    .Set = KV{
                        .key = key,
                        .value = value,
                        .argsNum = 2,
                        .commandStr = "SET",
                    },
                };
            }
            if (std.mem.eql(u8, buf, GetCommandStr(.Auth))) {
                return Command{ .Auth = .{
                    .key = lines.next().?,
                    .argsNum = 1,
                    .value = null,
                    .commandStr = "AUTH",
                } };
            }

            if (std.mem.eql(u8, buf, GetCommandStr(.DEL))) {
                const it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                return Command{ .DEL = .{
                    .key = it.?,
                    .argsNum = 1,
                    .value = null,
                    .commandStr = "DEL",
                } };
            }

            if (std.mem.eql(u8, buf, GetCommandStr(.LPUSH))) {
                var it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                const key = it.?;
                it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                const val = it.?;
                return Command{ .LPUSH = .{
                    .key = key,
                    .argsNum = 2,
                    .value = val,
                    .commandStr = "LPUSH",
                } };
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
