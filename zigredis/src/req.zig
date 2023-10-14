const std = @import("std");

const CommandType = enum {
    Get,
    Set,
};

pub const KV = struct {
    key: []const u8,
    value: []const u8,
};

const Command = union(CommandType) {
    Get: []const u8,
    Set: KV,
};

pub const Request = struct {
    content: []const u8,

    pub fn init(data: []const u8) Request {
        return Request{
            .content = data,
        };
    }

    pub fn parse(self: Request) !Command {
        _ = self;
    }
};
