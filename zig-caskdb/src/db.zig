const std = @import("std");
const option = @import("option.zig");
const disk = @import("disk.zig");

const ArchiveFileList = std.ArrayList([]disk.File);
pub const DB = struct {
    allocator: std.mem.Allocator,
    activeFile: ?disk.File,
    archiveFile: ArchiveFileList,
    mergeFile: ?disk.File,

    pub fn init(alloc: std.mem.Allocator, o: ?*option.Option) !DB {
        _ = o;
        return DB{
            .allocator = alloc,
            .activeFile = null,
            .archiveFile = ArchiveFileList.init(alloc),
            .mergeFile = null,
        };
    }

    pub fn deinit(
        self: *DB,
    ) void {
        self.archiveFile.deinit();
    }

    pub fn open(
        self: *DB,
    ) !void {
        _ = self;
    }

    pub fn store(self: *DB, key: []const u8, value: []const u8) !void {
        _ = value;
        _ = key;
        _ = self;
    }

    pub fn load(self: *DB, key: []const u8) !void {
        _ = key;
        _ = self;
    }
};
