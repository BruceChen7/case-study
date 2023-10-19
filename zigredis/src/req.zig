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
    LTrim,
    LRem,
};

const KV = struct {
    // GET, SET, AUTH, EXIT etc
    commandStr: []const u8,
    // ping is empty
    key: ?[]const u8,
    value: ?std.ArrayList([]const u8),
    // for get is 2, for set is 2 args
    argsNum: u8,

    pub fn deinit(self: KV) void {
        if (self.value) |v| {
            v.deinit();
        }
    }
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
    LTrim: KV,
    LRem: KV,

    pub fn deinit(self: *const Command) void {
        switch (self.*) {
            .Exit => {},
            .Get, .Incr, .Set, .Auth, .Ping, .DEL, .LPUSH, .LPOP, .Select, .LTrim, .LRem => |c| {
                c.deinit();
            },
        }
    }

    pub fn serialize(self: *const Command, alloc: std.mem.Allocator) !SerializeReqRes {
        switch (self.*) {
            .Get, .Set, .Auth, .Ping, .DEL, .LPUSH, .Incr, .LPOP, .Select, .LTrim, .LRem => |c| {
                return Command.serializeHelper(alloc, c);
            },
            else => {
                return RedisClientError.UnknownCommand;
            },
        }
    }
    fn serializeHelper(alloc: std.mem.Allocator, command: KV) !SerializeReqRes {
        const buf = try alloc.alloc(u8, 2048);
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

        if (command.value) |value| {
            for (value.items) |item| {
                const valueLen = item.len;
                if (valueLen != 0) {
                    rsp = try std.fmt.bufPrint(buf[rsp.len..], "${d}\r\n{s}\r\n", .{ valueLen, item });
                    validLen += rsp.len;
                    rsp = buf[0..validLen];
                }
            }
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

    fn parseHelper(alloc: std.mem.Allocator, lines: *std.mem.TokenIterator(u8, .scalar), command: CommandType, argNum: u8) !KV {
        switch (argNum) {
            0 => {
                return KV{ .key = null, .argsNum = argNum, .value = null, .commandStr = @tagName(command) };
            },
            1 => {
                var it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                const key = it.?;
                return KV{ .key = key, .argsNum = argNum, .value = null, .commandStr = @tagName(command) };
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
                var values = std.ArrayList([]const u8).init(alloc);
                try values.append(value);
                return KV{ .key = key, .argsNum = argNum, .value = values, .commandStr = @tagName(command) };
            },
            else => {
                var it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                const key = it.?;
                it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }

                var values = std.ArrayList([]const u8).init(alloc);
                // TODO(ming.chen):  check with argsNum
                while (it != null) : (it = lines.next()) {
                    const value = it.?;
                    try values.append(value);
                }
                return KV{ .key = key, .argsNum = argNum, .value = values, .commandStr = @tagName(command) };
            },
        }
        return;
    }
    pub fn parse(self: *Request, alloc: std.mem.Allocator) !Command {
        self.content = std.mem.trim(u8, self.content, " ");

        var lines = std.mem.tokenizeScalar(u8, self.content, ' ');
        // 遍历lines
        while (lines.next()) |line| {
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Get))) {
                const comand = try parseHelper(alloc, &lines, .Get, 1);
                return Command{ .Get = comand };
            }
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Incr))) {
                const command = try parseHelper(alloc, &lines, .Incr, 1);
                return Command{ .Incr = command };
            }
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Ping))) {
                return Command{ .Ping = .{ .key = null, .argsNum = 0, .value = null, .commandStr = "PING" } };
            }
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Set))) {
                const command = try parseHelper(alloc, &lines, .Set, 2);
                return Command{ .Set = command };
            }
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Select))) {
                const command = try parseHelper(alloc, &lines, .Select, 1);
                return Command{ .Select = command };
            }
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Auth))) {
                const command = try parseHelper(alloc, &lines, .Auth, 1);
                return Command{ .Auth = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.DEL))) {
                const command = try parseHelper(alloc, &lines, .DEL, 1);
                return Command{ .DEL = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.LPOP))) {
                const command = try parseHelper(alloc, &lines, .LPOP, 2);
                return Command{ .LPOP = command };
            }

            // TODO(ming.chen): more args support
            if (std.ascii.eqlIgnoreCase(line, @tagName(.LPUSH))) {
                const command = try parseHelper(alloc, &lines, .LPUSH, 2);
                return Command{ .LPUSH = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.LTrim))) {
                const command = try parseHelper(alloc, &lines, .LTrim, 3);
                return Command{ .LTrim = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.Exit))) {
                return Command{
                    .Exit = void{},
                };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.LRem))) {
                const command = try parseHelper(alloc, &lines, .LRem, 3);
                return Command{ .LRem = command };
            }
        }
        return RedisClientError.UnknownCommand;
    }
};

test "command tests" {
    const cmd: Command = Command{
        .Get = KV{ .key = "key", .argsNum = 1, .value = null, .commandStr = "GET" },
    };
    var rsp = try cmd.serialize(std.testing.allocator);
    defer rsp.deinit(std.testing.allocator);
    try std.testing.expect(std.mem.eql(u8, "*2\r\n$3\r\nGET\r\n$3\r\nkey\r\n", rsp.res[0..rsp.len]));
}
