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
    LPOP,
    Select,
};

pub fn getCommandStr(command: CommandType) []const u8 {
    const fields = @typeInfo(CommandType).Enum.fields;
    inline for (fields) |field| {
        if (field.value == @intFromEnum(command)) {
            // std.debug.print("{s}\n", .{field.name});
            return field.name;
        }
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

    pub fn deinit(self: *SerializeReqRes, alloc: std.mem.Allocator) void {
        alloc.free(self.res);
    }
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
    LPOP: KV,
    Select: KV,

    pub fn serialize(self: *const Command, alloc: std.mem.Allocator) !SerializeReqRes {
        switch (self.*) {
            .Get, .Set, .Auth, .Ping, .DEL, .LPUSH, .Incr, .LPOP, .Select => |c| {
                return Command.serializeHelper(alloc, c);
            },
            else => {
                return RedisClientError.UnknownCommand;
            },
        }
    }
    fn serializeHelper(alloc: std.mem.Allocator, command: KV) !SerializeReqRes {
        const buf = try alloc.alloc(u8, 1024);
        errdefer alloc.free(buf);

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
    NeedMoreData,
};

pub const Request = struct {
    content: []const u8,

    pub fn init(data: []const u8) Request {
        return Request{
            .content = data,
        };
    }

    fn parseHelper(lines: *std.mem.TokenIterator(u8, .scalar), command: CommandType, argNum: u8) !KV {
        switch (argNum) {
            0 => {
                return KV{ .key = null, .argsNum = 0, .value = null, .commandStr = @tagName(command) };
            },
            1 => {
                var it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                const key = it.?;
                return KV{ .key = key, .argsNum = 1, .value = null, .commandStr = @tagName(command) };
            },
            2 => {
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
                return KV{ .key = key, .argsNum = 2, .value = value, .commandStr = @tagName(command) };
            },
            else => {
                return RedisClientError.InvalidCommandParam;
            },
        }
        return;
    }
    pub fn parse(self: *Request) !Command {
        self.content = std.mem.trim(u8, self.content, " ");

        var lines = std.mem.tokenizeScalar(u8, self.content, ' ');
        // 遍历lines
        while (lines.next()) |line| {
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Get))) {
                const comand = try parseHelper(&lines, .Get, 1);
                return Command{ .Get = comand };
            }
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Incr))) {
                const command = try parseHelper(&lines, .Incr, 1);
                return Command{ .Incr = command };
            }
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Ping))) {
                return Command{ .Ping = .{ .key = null, .argsNum = 0, .value = null, .commandStr = "PING" } };
            }
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Set))) {
                const command = try parseHelper(&lines, .Set, 2);
                return Command{ .Set = command };
            }
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Select))) {
                const command = try parseHelper(&lines, .Select, 1);
                return Command{ .Select = command };
            }
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Auth))) {
                const command = try parseHelper(&lines, .Auth, 1);
                return Command{ .Auth = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.DEL))) {
                const command = try parseHelper(&lines, .DEL, 1);
                return Command{ .DEL = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.LPOP))) {
                const command = try parseHelper(&lines, .LPOP, 2);
                return Command{ .LPOP = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.LPUSH))) {
                const command = try parseHelper(&lines, .LPUSH, 2);
                return Command{ .LPUSH = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.Exit))) {
                return Command{
                    .Exit = void{},
                };
            }
        }
        return RedisClientError.UnknownCommand;
    }
};
