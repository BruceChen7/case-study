const std = @import("std");
const FileEntry = struct {
    keySize: u32,
    valueSize: u32,
    key: []const u8,
    value: []const u8,

    pub fn serialize(self: *const FileEntry) []const u8 {
        _ = self;
        // const len = 4 + 4 + self.keySize + self.valueSize;
        // var fbs = std.io.BufferedWriter(len, u8);
        // const writer = fbs.writer();
        // try writer.writeIntLittle(u32, self.keySize);
        // try writer.writeIntLittle(u32, self.valueSize);
        // try writer.writeAll(self.key);
        // try writer.writeAll(self.value);
    }
    pub fn deserialize(self: *FileEntry, data: []const u8) void {
        _ = data;
        _ = self;
        // const reader = std.io.BufferedReader(data).reader();
        // self.keySize = try reader.readIntLittle(u32);
        // self.valueSize = try reader.readIntLittle(u32);
        // self.key = try reader.readAllAlloc(std.testing.allocator, self.keySize);
        // self.value = try reader.readAllAlloc(std.testing.allocator, self.valueSize);
    }
};

const KeyDirEntry = struct {
    fileID: u32,
    valueSize: u32,
    valuePos: u32,
};

const EntryState = enum {
    NORM,
    DELETED,
};

pub const FileType = enum {
    SEGMENT,
    WAL,
    MERGE,
};

pub const CaskFile = struct {
    fileID: u32,
    fileType: FileType,
    path: []const u8,
    alloc: std.mem.Allocator,
    file: ?std.fs.File,

    pub fn init(alloc: std.mem.Allocator, fileID: u32, fileType: FileType, ext: []const u8, dir: std.fs.Dir) !CaskFile {
        var dirPath = try dir.realpathAlloc(std.testing.allocator, ".");
        defer alloc.free(dirPath);
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        var subPath = try std.fmt.bufPrint(&buf, "{d}{s}", .{ fileID, ext });
        var name = try std.fs.path.join(alloc, &.{ dirPath, subPath });
        return .{
            .alloc = alloc,
            .fileID = fileID,
            .fileType = fileType,
            .path = name,
            .file = null,
        };
    }
    pub fn create(alloc: std.mem.Allocator, fileID: u32, fileType: FileType, ext: []const u8, dir: std.fs.Dir) !CaskFile {
        var caskFile = try init(alloc, fileID, fileType, ext, dir);
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        var subPath = try std.fmt.bufPrint(&buf, "{d}{s}", .{ fileID, ext });
        var file = try dir.createFile(subPath, .{ .truncate = true, .read = true, .exclusive = true });
        caskFile.file = file;
        return caskFile;
    }

    pub fn open(self: *CaskFile) !void {
        if (self.file) |f| {
            f.close();
        }
        self.file = try std.fs.openFileAbsolute(self.path, .{ .mode = .read_write });
    }
    pub fn seekLast(self: *CaskFile) !void {
        if (self.file) |f| {
            const pos: i64 = @intCast(try f.getEndPos());
            try f.seekFromEnd(pos);
        }
    }

    pub fn deinit(self: *CaskFile) void {
        self.alloc.free(self.path);
        if (self.file) |f| {
            f.close();
        }
    }
};
