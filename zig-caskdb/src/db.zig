const std = @import("std");
const option = @import("option.zig");
const disk = @import("disk.zig");
const directory = @import("dir.zig");

const ArchiveFileList = std.ArrayList([]disk.File);
pub const DB = struct {
    allocator: std.mem.Allocator,
    activeFile: ?disk.File,
    archiveFile: ArchiveFileList,
    mergeFile: ?disk.File,
    options: *option.Option,
    pendingWring: []const u8,

    pub fn init(alloc: std.mem.Allocator, dbOption: ?*const option.Option) !DB {
        var op: *option.Option = try alloc.create(option.Option);
        if (dbOption) |o| {
            op.* = o.*;
        } else {
            op.* = option.default();
        }
        return DB{
            .allocator = alloc,
            .activeFile = null,
            .archiveFile = ArchiveFileList.init(alloc),
            .mergeFile = null,
            .options = op,
            .pendingWring = &[_]u8{},
        };
    }

    pub fn deinit(
        self: *DB,
    ) void {
        self.archiveFile.deinit();
        self.allocator.destroy(self.options);
    }

    pub fn open(
        self: *DB,
    ) !void {
        const dir = directory.Dir.init(self.options.mergeFileDir);
        try dir.getSpecificExtFile(self.options.mergefileExt, self.allocator);
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

test "db" {
    var db = try DB.init(std.testing.allocator, null);
    defer db.deinit();
    try std.testing.expectEqualDeep(db.options, @constCast(&option.default()));
}
