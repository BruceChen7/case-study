const std = @import("std");
const option = @import("option.zig");

pub const Dir = struct {
    dir: std.fs.Dir,
    pub fn init(dir: std.fs.Dir) Dir {
        return .{ .dir = dir };
    }

    pub fn getSpecificExtFile(self: *const Dir, ext: []const u8, alloc: std.mem.Allocator) !std.ArrayList([]u8) {
        // iterate all files
        var src_dir = try self.dir.openIterableDir("", .{});
        defer src_dir.close();
        var it = try src_dir.walk(alloc);
        var res = std.ArrayList([]u8).init(alloc);
        var numAlloc: u32 = 0;
        errdefer for (0..numAlloc) |i| {
            alloc.free(res.items[i]);
        };
        errdefer res.deinit();

        next_entry: while (try it.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.path, ext)) {
                continue :next_entry;
            }
            // 如果是目录，skip
            var dirPath: []u8 = try alloc.alloc(u8, std.fs.MAX_PATH_BYTES);
            const buf = try self.dir.realpath("", dirPath);
            const src_sub_path = try std.fs.path.join(alloc, &.{ buf, entry.path });
            numAlloc += 1;
            try res.append(src_sub_path);
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
    const fileName = try std.fmt.allocPrint(std.testing.allocator, "{d}{s}", .{ 1, opt.mergefileExt });
    defer std.testing.allocator.free(fileName);
    try std.testing.expectEqualSlices(u8, "1.merge", fileName);
    var file = try dir.createFile(fileName, .{});
    // delete file
    defer file.close();
    defer dir.deleteFile(fileName) catch unreachable;

    const curDir = Dir.init(dir);
    const fileList = curDir.getSpecificExtFile(opt.mergefileExt, std.testing.allocator) catch unreachable;
    _ = fileList;
}
