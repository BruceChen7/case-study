const std = @import("std");
pub const FileEntry = struct {
    keySize: u32,
    valueSize: u32,
    key: []const u8,
    value: []const u8,

    const Self = @This();
    pub fn serialize(
        self: *const Self,
        alloc: std.mem.Allocator,
    ) ![]const u8 {
        const len = 4 + 4 + self.keySize + self.valueSize;
        const buf: []u8 = try alloc.alloc(u8, len);
        errdefer alloc.free(buf);
        var fbs = std.io.fixedBufferStream(buf);
        const writer = fbs.writer();
        try writer.writeInt(u32, self.keySize, .little);
        try writer.writeInt(u32, self.valueSize, .little);
        try writer.writeAll(self.key);
        try writer.writeAll(self.value);
        return fbs.getWritten();
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

pub const KeyDirEntry = struct {
    fileID: u32,
    valueSize: u32,
    valuePos: u32,
    key: []const u8,
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

pub const ErrorDB = error{
    NotFound,
    InvalidSegmentFile,
};

pub const CaskFile = struct {
    fileID: u32,
    fileType: FileType,
    path: []const u8,
    alloc: std.mem.Allocator,
    file: ?std.fs.File,
    lastPos: i64 = 0,
    const Self = @This();

    pub fn init(alloc: std.mem.Allocator, fileID: u32, fileType: FileType, ext: []const u8, path: []const u8) !CaskFile {
        const trimmedPath = std.mem.trim(u8, path, &[_]u8{0});
        var dir = try std.fs.openDirAbsolute(trimmedPath, .{});
        const dirPath = try dir.realpathAlloc(alloc, ".");
        defer alloc.free(dirPath);
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const subPath = try std.fmt.bufPrint(&buf, "{d}{s}", .{ fileID, ext });
        const name = try std.fs.path.join(alloc, &.{ dirPath, subPath });
        std.debug.assert(std.fs.path.isAbsolute(name));
        return .{
            .alloc = alloc,
            .fileID = fileID,
            .fileType = fileType,
            .path = name,
            .file = null,
            .lastPos = 0,
        };
    }

    pub fn create(alloc: std.mem.Allocator, fileID: u32, fileType: FileType, ext: []const u8, dirPath: []const u8) !CaskFile {
        const trimmedPath = std.mem.trim(u8, dirPath, &[_]u8{0});
        var dir = try std.fs.openDirAbsolute(trimmedPath, .{});
        var caskFile = try init(alloc, fileID, fileType, ext, dirPath);
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const subPath = try std.fmt.bufPrint(&buf, "{d}{s}", .{ fileID, ext });
        const file = try dir.createFile(subPath, .{ .truncate = true, .read = true, .exclusive = true });
        caskFile.file = file;
        return caskFile;
    }

    pub fn open(self: *Self) !void {
        if (self.file) |f| {
            f.close();
        }
        self.file = try std.fs.openFileAbsolute(self.path, .{ .mode = .read_write });
    }
    pub fn seekLast(self: *Self) !void {
        if (self.file) |f| {
            const pos: i64 = @intCast(try f.getEndPos());
            self.lastPos = pos;
            try f.seekFromEnd(pos);
        }
    }

    pub fn seekPosAndRead(self: *Self, alloc: std.mem.Allocator, pos: i64, nBytes: u32) ![]u8 {
        if (self.file) |f| {
            try f.seekTo(@intCast(pos));
            const buf: []u8 = try alloc.alloc(u8, nBytes);
            const nSize = try f.readAll(buf);
            std.debug.assert(nSize == nBytes);
            return buf;
        }
        return ErrorDB.NotFound;
    }

    pub fn getLastWrittenPos(self: *const Self) i64 {
        return self.lastPos;
    }

    pub fn readAllEntries(self: *Self, alloc: std.mem.Allocator) !std.ArrayList(KeyDirEntry) {
        var entries = std.ArrayList(KeyDirEntry).init(alloc);
        errdefer entries.deinit();
        try self.file.?.seekTo(0);
        var lastPost: u32 = 0;
        var lastValPos: u32 = 0;
        read: while (true) {
            const keySize = self.file.?.reader().readInt(u32, .little) catch |err| {
                if (err == error.EndOfStream) {
                    break :read;
                }
                return err;
            };
            if (keySize == 0) {
                break :read;
            }
            const valueSize = try self.file.?.reader().readInt(u32, .little);
            // read key
            const key = try alloc.alloc(u8, keySize);
            const readKeySize = try self.file.?.readAll(key);
            if (readKeySize != keySize) {
                return ErrorDB.InvalidSegmentFile;
            }
            lastValPos = lastPost + 4 + 4 + keySize;
            lastPost += 4 + 4 + keySize + valueSize;
            try entries.append(.{
                .fileID = self.fileID,
                .valueSize = valueSize,
                .valuePos = lastValPos,
                .key = key,
            });
            try self.file.?.seekTo(lastPost);
        }
        return entries;
    }

    pub fn write(self: *Self, data: []const u8) !void {
        // TODO(ming.chen): use buffer write
        // var buff_out = std.io.bufferedWriter(config_file.writer());
        if (self.file) |f| {
            try f.writeAll(data);
            self.lastPos += @intCast(data.len);
        }
    }

    pub fn deinit(self: *Self) void {
        self.alloc.free(self.path);
        if (self.file) |f| {
            f.close();
        }
    }
};
