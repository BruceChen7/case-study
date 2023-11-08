const std = @import("std");
const option = @import("option.zig");

pub const Dir = struct {
    const Self = @This();
    dir: std.fs.Dir,
    lockFd: ?std.os.fd_t = null,
    pub fn init(dir: std.fs.Dir) Dir {
        return .{
            .dir = dir,
        };
    }
    pub fn deinit(self: *Self) void {
        if (self.lockFd) |fd| {
            std.os.close(fd);
        }
    }
    pub fn lock(self: *Self, fileName: []const u8) !void {
        // open the directory
        const fd = try std.os.openat(self.dir.fd, fileName, std.os.O.CREAT | std.os.O.RDONLY, 0o644);
        errdefer std.os.close(fd);
        // set fd is non-blocking
        _ = std.os.fcntl(fd, std.os.F.SETFL, std.os.O.NONBLOCK) catch |err| {
            std.debug.print("error: {s}\n", .{@errorName(err)});
            return err;
        };

        // try to lock the directory, using flock
        std.os.flock(fd, std.os.LOCK.EX) catch |err| {
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
        var curPath = try self.dir.realpath(".", &buf);
        // iterate all files
        var src_dir = try self.dir.openIterableDir(curPath, .{});
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
    // 获取当前目录
    var dir = std.fs.cwd();
    var dirPath = try dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(dirPath);
    // create file
    var opt = option.default();
    const fileName = try std.fmt.allocPrint(std.testing.allocator, "{d}{s}", .{ 2, opt.mergefileExt });
    defer std.testing.allocator.free(fileName);
    try std.testing.expectEqualSlices(u8, "2.merge", fileName);

    var file = try dir.createFile(fileName, .{});
    // delete file
    defer file.close();
    defer dir.deleteFile(fileName) catch unreachable;

    const curDir = Dir.init(dir);
    const fileList = curDir.getSpecificExtFile(opt.mergefileExt, std.testing.allocator) catch unreachable;
    errdefer fileList.deinit();
    errdefer for (fileList.items) |f| {
        std.testing.allocator.free(f);
    };

    for (fileList.items) |f| {
        var name = try std.fs.path.join(std.testing.allocator, &.{ dirPath, "2.merge" });
        defer std.testing.allocator.free(name);
        try std.testing.expectEqualSlices(u8, name, f);
    }
    for (fileList.items) |f| {
        std.testing.allocator.free(f);
    }
    fileList.deinit();
}
