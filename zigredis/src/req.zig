const std = @import("std");

pub const CommandType = enum {
    Get,
    Incr,
    Set,
    Auth,
    Exit,
    Ping,
    DEL,
    LPUSH,
    LPOP,
    Select,
    LTrim,
    LRem,
    LLEN,
    RPOP,
    RPUSH,
    LINSERT,
    LRANGE,
    EXISTS,
    GETSET,
    MGET,
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
    LLEN: KV,
    RPOP: KV,
    RPUSH: KV,
    LINSERT: KV,
    LRANGE: KV,
    EXISTS: KV,
    GETSET: KV,
    MGET: KV,

    pub fn deinit(self: *const Command) void {
        switch (self.*) {
            .Exit => {},
            inline else => |c| {
                c.deinit();
            },
        }
    }

    pub fn serialize(self: *const Command, alloc: std.mem.Allocator) !SerializeReqRes {
        switch (self.*) {
            .Exit => unreachable,
            inline else => |*c| {
                return Command.serializeHelper(alloc, c);
            },
        }
    }
    fn serializeHelper(alloc: std.mem.Allocator, command: *const KV) !SerializeReqRes {
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

    fn parseHelper(alloc: std.mem.Allocator, lines: *std.mem.TokenIterator(u8, .scalar), command: CommandType, argNum: i8) !KV {
        switch (argNum) {
            0 => {
                return KV{ .key = null, .argsNum = @intCast(argNum), .value = null, .commandStr = @tagName(command) };
            },
            1 => {
                const it = lines.next();
                if (it == null) {
                    return RedisClientError.InvalidCommandParam;
                }
                const key = it.?;
                return KV{ .key = key, .argsNum = @intCast(argNum), .value = null, .commandStr = @tagName(command) };
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
                return KV{ .key = key, .argsNum = @intCast(argNum), .value = values, .commandStr = @tagName(command) };
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

                var cnt: i8 = 0;
                var values = std.ArrayList([]const u8).init(alloc);
                errdefer values.deinit();

                while (it != null) : (it = lines.next()) {
                    const value = it.?;
                    cnt += @intCast(1);
                    try values.append(value);
                }
                if (argNum != -1 and argNum != cnt + 1) {
                    return RedisClientError.InvalidCommandParam;
                }
                var ar = argNum;
                if (argNum == -1) {
                    ar = cnt + 1;
                }
                return KV{ .key = key, .argsNum = @intCast(ar), .value = values, .commandStr = @tagName(command) };
            },
        }
        return;
    }

    pub fn parse(self: *Request, alloc: std.mem.Allocator) !Command {
        self.content = std.mem.trim(u8, self.content, " ");

        var lines = std.mem.tokenizeScalar(u8, self.content, ' ');
        // 遍历lines
        while (lines.next()) |line| {
            // 能否动态的设置Command的tag，避免出现这么多的重复代码？
            if (std.ascii.eqlIgnoreCase(line, @tagName(.Get))) {
                const comand = try parseHelper(alloc, &lines, .Get, 1);
                return Command{ .Get = comand };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.GETSET))) {
                const comand = try parseHelper(alloc, &lines, .GETSET, 2);
                return Command{ .GETSET = comand };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.MGET))) {
                const comand = try parseHelper(alloc, &lines, .MGET, -1);
                return Command{ .MGET = comand };
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

            if (std.ascii.eqlIgnoreCase(line, @tagName(.LPUSH))) {
                const command = try parseHelper(alloc, &lines, .LPUSH, -1);
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

            if (std.ascii.eqlIgnoreCase(line, @tagName(.EXISTS))) {
                const command = try parseHelper(alloc, &lines, .EXISTS, 1);
                return Command{ .EXISTS = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.LLEN))) {
                const command = try parseHelper(alloc, &lines, .LLEN, 1);
                return Command{ .LLEN = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.RPOP))) {
                const command = try parseHelper(alloc, &lines, .RPOP, 2);
                return Command{ .RPOP = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.RPUSH))) {
                const command = try parseHelper(alloc, &lines, .RPUSH, -1);
                return Command{ .RPUSH = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.LRANGE))) {
                const command = try parseHelper(alloc, &lines, .LRANGE, 3);
                return Command{ .LRANGE = command };
            }

            if (std.ascii.eqlIgnoreCase(line, @tagName(.LRem))) {
                const command = try parseHelper(alloc, &lines, .LRem, 3);
                return Command{ .LRem = command };
            }
            if (std.ascii.eqlIgnoreCase(line, @tagName(.LINSERT))) {
                const kv = try parseHelper(alloc, &lines, .LINSERT, 4);
                const value = kv.value.?;
                if (!std.ascii.eqlIgnoreCase(value.items[0], "BEFORE") and !std.ascii.eqlIgnoreCase(value.items[0], "AFTER")) {
                    return RedisClientError.UnknownCommand;
                }
                return Command{ .LINSERT = kv };
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


test "parse" {
    const req = @import("req.zig");
    var request = req.Request.init("LPUSH d 1 2");
    var command = try request.parse(std.testing.allocator);
    defer command.deinit();
    var arraryValues = std.ArrayList([]const u8).init(std.testing.allocator);
    var val1 = "1";
    const sliceVal1: []const u8 = val1[0..];
    const val2 = "2";
    try arraryValues.append(sliceVal1);
    try arraryValues.append(val2);
    defer arraryValues.deinit();

    const expect = Command{
        .LPUSH = KV{ .key = "d", .argsNum = 3, .value = arraryValues, .commandStr = "LPUSH" },
    };
    try std.testing.expectEqualDeep(command, expect);
}
