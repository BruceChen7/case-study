const std = @import("std");
const option = @import("option.zig");
const disk = @import("disk.zig");
const Dir = @import("dir.zig").Dir;

const CaskFile = disk.CaskFile;
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
    workingDir: ?Dir = null,

    const Self = @This();

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
        self: *Self,
    ) void {
        for (self.archiveFile.items) |*file| {
            file.deinit();
        }
        self.archiveFile.deinit();
        self.allocator.destroy(self.options);
        if (self.activeFile) |*file| {
            file.deinit();
        }

        if (self.workingDir) |*dir| {
            dir.deinit();
        }
        var iter = self.index.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.index.deinit();
    }

    pub fn open(
        self: *Self,
    ) !void {
        // TODO(ming.chen): use another option
        self.workingDir = try Dir.init(self.options.segmentFileDir[0..]);
        // FIXME(ming.chen):  use another option
        try self.workingDir.?.lock("1.lock");
        errdefer self.workingDir.?.deinit();

        var segmentFileList = try self.workingDir.?.getSpecificExtFile(self.options.segmentFileExt, self.allocator);

        defer segmentFileList.deinit();
        defer for (segmentFileList.items) |f| {
            self.allocator.free(f);
        };
        // 没有文件
        if (segmentFileList.items.len == 0) {
            // 新创建一个segment 文件，并打开
            var file = try CaskFile.create(self.allocator, 0, disk.FileType.SEGMENT, self.options.segmentFileExt, self.options.segmentFileDir[0..]);
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

    fn buildIndex(self: *Self) !void {
        if (self.activeFile) |*file| {
            var entries = try file.readAllEntries(self.allocator);
            defer entries.deinit();
            for (entries.items) |entry| {
                const result = try self.index.getOrPut(entry.key);
                if (result.found_existing) {
                    self.allocator.free(result.value_ptr.*.key);
                    result.value_ptr.* = entry;
                }
                result.key_ptr.* = entry.key;
                result.value_ptr.* = entry;
            }
        } else {
            // TODO(ming.chen): build from merge file or segment file
        }
    }

    fn openSegmentFileList(self: *Self, fileList: std.ArrayList([]u8)) !void {
        const alloc = self.allocator;

        for (fileList.items, 0..) |f, i| {
            const name = std.fs.path.basename(f);
            // split name
            var it = std.mem.splitScalar(u8, name, '.');
            const fileIDStr = it.first();
            // convert fileIDStr to u32
            const fileID = try std.fmt.parseInt(u32, fileIDStr, 10);
            var file = try CaskFile.init(alloc, fileID, .SEGMENT, self.options.segmentFileExt, self.options.segmentFileDir[0..]);
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

    pub fn store(self: *Self, key: []const u8, value: []const u8) !void {
        const entry: disk.FileEntry = .{
            .keySize = @intCast(key.len),
            .valueSize = @intCast(value.len),
            .key = key,
            .value = value,
        };
        const res = try entry.serialize(self.allocator);
        defer self.allocator.free(res);

        const valPos = self.activeFile.?.getLastWrittenPos() + 8 + @as(u32, @intCast(key.len));
        const valSize = value.len;
        try self.activeFile.?.write(res);

        // allocate memory and copy key slice
        const keyDirEntry = disk.KeyDirEntry{
            .fileID = self.activeFile.?.fileID,
            .valuePos = @intCast(valPos),
            .valueSize = @intCast(valSize),
            .key = try self.allocator.dupe(u8, key),
        };
        errdefer self.allocator.free(keyDirEntry.key);
        try self.updateIndex(keyDirEntry.key, &keyDirEntry);
    }

    fn updateIndex(self: *Self, key: []const u8, keyDir: *const disk.KeyDirEntry) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        var result = try self.index.getOrPut(key);
        if (result.found_existing) {
            self.allocator.free(result.value_ptr.*.key);
        }
        result.key_ptr.* = keyDir.key;
        result.value_ptr.* = keyDir.*;
    }

    pub fn load(self: *Self, key: []const u8) ![]const u8 {
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
