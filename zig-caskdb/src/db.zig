const std = @import("std");
const option = @import("option.zig");
const disk = @import("disk.zig");
const directory = @import("dir.zig");

const ArchiveFileList = std.ArrayList(disk.CaskFile);
const Index = std.StringHashMap(disk.KeyDirEntry);
pub const DB = struct {
    allocator: std.mem.Allocator,
    activeFile: ?disk.CaskFile,
    archiveFile: ArchiveFileList,
    mergeFile: ?disk.CaskFile,
    options: *option.Option,
    pendingWring: []const u8,
    mutex: std.Thread.Mutex,
    index: Index,

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
            .index = Index.init(alloc),
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn close(
        self: *DB,
    ) void {
        for (self.archiveFile.items) |*file| {
            file.deinit();
        }
        self.archiveFile.deinit();
        self.allocator.destroy(self.options);
        if (self.activeFile) |*file| {
            file.deinit();
        }
        self.index.deinit();
    }

    pub fn open(
        self: *DB,
    ) !void {
        // TODO(ming.chen): use another option
        const dir = directory.Dir.init(self.options.segmentFileDir);
        var segmentFileList = try dir.getSpecificExtFile(self.options.segmentFileExt, self.allocator);

        defer segmentFileList.deinit();
        defer for (segmentFileList.items) |f| {
            self.allocator.free(f);
        };
        // 没有文件
        if (segmentFileList.items.len == 0) {
            // 新创建一个segment 文件，并打开
            var file = try disk.CaskFile.create(self.allocator, 0, disk.FileType.SEGMENT, self.options.segmentFileExt, self.options.segmentFileDir);
            errdefer file.deinit();
            self.activeFile = file;
            try self.activeFile.?.open();
            try self.activeFile.?.seekLast();
        } else {
            // 按照文件名来排序
            std.sort.block([]u8, segmentFileList.items, {}, struct {
                fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                    return std.mem.lessThan(u8, a, b);
                }
            }.lessThan);

            try self.openSegmentFileList(segmentFileList);
        }
        try self.buildIndex();
    }

    fn buildIndex(self: *DB) !void {
        for (self.archiveFile.items) |*file| {
            _ = file;
            // try file.buildIndex();
        }
    }

    fn openSegmentFileList(self: *DB, fileList: std.ArrayList([]u8)) !void {
        const alloc = self.allocator;

        for (fileList.items, 0..) |f, i| {
            const name = std.fs.path.basename(f);
            // split name
            var it = std.mem.splitScalar(u8, name, '.');
            const fileIDStr = it.first();
            // convert fileIDStr to u32
            const fileID = try std.fmt.parseInt(u32, fileIDStr, 10);
            var file = try disk.CaskFile.init(alloc, fileID, .SEGMENT, self.options.segmentFileExt, self.options.segmentFileDir);
            errdefer file.deinit();
            try file.open();

            if (i == fileList.items.len - 1) {
                self.activeFile = file;
                try self.activeFile.?.seekLast();
            } else {
                try self.archiveFile.append(file);
            }
        }
    }

    pub fn store(self: *DB, key: []const u8, value: []const u8) !void {
        const entry: disk.FileEntry = .{
            .keySize = @intCast(key.len),
            .valueSize = @intCast(value.len),
            .key = key,
            .value = value,
        };
        const res = try entry.serialize(self.allocator);
        defer self.allocator.free(res);

        const valPos = self.activeFile.?.getLastWrittenPos();
        const valSize = value.len;

        try self.activeFile.?.write(res);
        const keyDirEntry: disk.KeyDirEntry = .{
            .fileID = self.activeFile.?.fileID,
            .valuePos = @intCast(valPos),
            .valueSize = @intCast(valSize),
        };
        try self.updateIndex(key, &keyDirEntry);
    }

    fn updateIndex(self: *DB, key: []const u8, keyDir: *const disk.KeyDirEntry) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.index.put(key, keyDir.*);
    }

    pub fn load(self: *DB, key: []const u8) ![]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        var it = self.index.get(key);
        if (it) |entry| {
            const val = try self.activeFile.?.seekPosAndRead(self.allocator, entry.valuePos, entry.valueSize);
            return val;
        }
        return disk.ErrorDB.NotFound;
    }
};

test "db" {
    var db = try DB.init(std.testing.allocator, null);
    defer db.close();
    try db.open();
    try std.testing.expectEqualDeep(db.options, @constCast(&option.default()));
}
