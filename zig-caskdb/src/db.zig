const std = @import("std");
const option = @import("option.zig");
const disk = @import("disk.zig");
const directory = @import("dir.zig");

const ArchiveFileList = std.ArrayList([]disk.CaskFile);
pub const DB = struct {
    allocator: std.mem.Allocator,
    activeFile: ?*disk.CaskFile,
    archiveFile: ArchiveFileList,
    mergeFile: ?disk.CaskFile,
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
        if (self.activeFile) |file| {
            file.deinit();
        }
    }

    pub fn open(
        self: *DB,
    ) !void {
        const dir = directory.Dir.init(self.options.mergeFileDir);
        var mergeFileList = try dir.getSpecificExtFile(self.options.mergefileExt, self.allocator);
        _ = mergeFileList;
        var segmentFileList = try dir.getSpecificExtFile(self.options.segmentfileExt, self.allocator);
        // 没有文件
        if (segmentFileList.items.len == 0) {
            // 新创建一个segment 文件，并
            var file = try disk.CaskFile.create(self.allocator, 0, disk.FileType.SEGMENT, self.options.segmentFileExt, self.options.segmentFileDir);
            self.activeFile = file;
            try self.activeFile.?.open();
            try self.activeFile.?.seekLast();
        } else {
            // 按照文件名来排序
            std.sort.sort([][]const u8, segmentFileList.items, {}, struct {
                fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                    return std.mem.lessThan(u8, a, b);
                }
            }.lessThan);
            var lastFile: []u8 = segmentFileList.items[segmentFileList.items.len - 1];
            _ = lastFile;
        }
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
