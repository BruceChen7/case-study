const std = @import("std");
const option = @import("option.zig");
const print = std.debug.print;

pub const Dir = struct {
    const Self = @This();
    dir: std.fs.Dir,
    lockFd: ?std.posix.fd_t = null,
    pub fn init(dirPath: []const u8) !Dir {
        // trim 0x00 from dirPath
        const trimmedPath = std.mem.trim(u8, dirPath, &[_]u8{0});
        const dir = try std.fs.openDirAbsolute(trimmedPath, .{});
        return .{
            .dir = dir,
        };
    }
    pub fn deinit(self: *Self) void {
        if (self.lockFd) |fd| {
            std.posix.close(fd);
        }
        self.dir.close();
    }

    pub fn lock(self: *Self, fileName: []const u8) !void {
        // open the directory
        const flags :std.posix.O = .{
            .ACCMODE = .RDONLY,
            .CREAT = true,
            .NONBLOCK = true
        };
        const fd = try std.posix.openat(self.dir.fd, fileName, flags, 0o644);
        errdefer std.posix.close(fd);

        // try to lock the directory, using flock
        std.posix.flock(fd, std.posix.LOCK.EX) catch |err| {
            if (err == error.WouldBlock) {
                std.debug.print("directory is locked, another process is using it", .{});
                std.process.exit(1);
            }
            std.debug.print("error: {s}\n", .{@errorName(err)});
            return err;
        };
    }

    pub fn getSpecificExtFile(self: *const Self, ext: []const u8, alloc: std.mem.Allocator) !std.ArrayList([]u8) {
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const curPath = try self.dir.realpath(".", &buf);
        // iterate all files
        var src_dir = try self.dir.openDir(curPath, .{.iterate = true});
        defer src_dir.close();
        var it = try src_dir.walk(alloc);
        defer it.deinit();
        var res = std.ArrayList([]u8).init(alloc);
        var numAlloc: u32 = 0;
        errdefer res.deinit();
        errdefer for (0..numAlloc) |i| {
            alloc.free(res.items[i]);
        };

        next_entry: while (try it.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.path, ext)) {
                continue :next_entry;
            }
            if (entry.kind != .file) {
                continue :next_entry;
            }
            const src_sub_path = try std.fs.path.join(alloc, &.{ curPath, entry.path });
            try res.append(src_sub_path[0..src_sub_path.len]);
            numAlloc += 1;
        }
        return res;
    }
};

test "get specific ext file" {
    // 获取当前目录path
    const dir = std.fs.cwd();
    const dirPath = try dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(dirPath);
    // create file
    const opt = option.default();
    const fileName = try std.fmt.allocPrint(std.testing.allocator, "{d}{s}", .{ 2, opt.mergefileExt });
    defer std.testing.allocator.free(fileName);
    try std.testing.expectEqualSlices(u8, "2.merge", fileName);

    var file = try dir.createFile(fileName, .{});
    // delete file
    defer file.close();
    defer dir.deleteFile(fileName) catch unreachable;

    // 获取当前目录absolute path
    const curDir = try Dir.init(dirPath);
    const fileList = curDir.getSpecificExtFile(opt.mergefileExt, std.testing.allocator) catch unreachable;
    errdefer fileList.deinit();
    errdefer for (fileList.items) |f| {
        std.testing.allocator.free(f);
    };

    for (fileList.items) |f| {
        const name = try std.fs.path.join(std.testing.allocator, &.{ dirPath, "2.merge" });
        defer std.testing.allocator.free(name);
        try std.testing.expectEqualSlices(u8, name, f);
    }
    for (fileList.items) |f| {
        std.testing.allocator.free(f);
    }
    fileList.deinit();
}
