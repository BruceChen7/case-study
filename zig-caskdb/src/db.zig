const std = @import("std");

const DiskEntry = struct {
    crc: []const u8,
    ts: u32,
    keySize: u32,
    valueSize: u32,
    key: []const u8,
    value: []const u8,
};

const KeyDirEntry = struct {
    fileID: u32,
    valueSize: u32,
    valuePos: u32,
    ts: u32,
};

pub const DB = struct {
    activeFile: ?std.fs.File,
    allocator: std.mem.Allocator,
    pub fn init(alloc: std.mem.Allocator, dbPath: []const u8) !DB {
        var allocator = alloc;
        const path = try std.fs.realpathAlloc(allocator, dbPath);
        defer allocator.free(path);
        const activeFile = std.fs.openFileAbsolute(path, .{ .mode = .read_write }) catch |err| {
            if (err == error.FileNotFound) {
                // TODO(ming.chen): excluesive file
                var activeFile = try std.fs.createFileAbsolute(path, .{});
                return DB{
                    .activeFile = activeFile,
                    .allocator = alloc,
                };
            }
            return err;
        };
        return DB{
            .activeFile = activeFile,
            .allocator = alloc,
        };
    }

    pub fn deinit(
        self: *DB,
    ) void {
        if (self.activeFile) |file| {
            file.close();
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
