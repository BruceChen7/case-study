const std = @import("std");
const FileEntry = struct {
    keySize: u32,
    valueSize: u32,
    key: []const u8,
    value: []const u8,
    path: []const u8,
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
        var dirPath = try dir.realpathAlloc(std.testing.allocator, ".");
        defer alloc.free(dirPath);
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        var subPath = try std.fmt.bufPrint(&buf, "{d}{s}", .{ fileID, ext });
        var name = try std.fs.path.join(alloc, &.{ dirPath, subPath });

        var file = try dir.createFile(subPath, .{ .truncate = true, .read = true, .exclusive = true });
        return .{
            .alloc = alloc,
            .fileID = fileID,
            .fileType = fileType,
            .path = name,
            .file = file,
        };
    }

    pub fn open(self: *CaskFile) !void {
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
