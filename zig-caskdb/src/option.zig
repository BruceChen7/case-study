const std = @import("std");
const print = std.debug.print;

pub const Option = struct {
    segmentFileSize: u32,
    sync: bool,
    mergeFileDir: [std.fs.MAX_PATH_BYTES]u8,
    segmentFileDir: [std.fs.MAX_PATH_BYTES]u8,
    mergefileExt: []const u8,
    segmentFileExt: []const u8,
};

pub fn default() Option {
    const currentDir = std.fs.cwd();
    // acquire current dir path
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var dirPath = currentDir.realpath(".", &buf) catch unreachable;

    var res: Option = .{
        .segmentFileSize = 1024 * 32,
        .sync = false,
        .mergefileExt = ".merge",
        .segmentFileExt = ".segment",
        .mergeFileDir = undefined,
        .segmentFileDir = undefined,
    };
    // copy specified len of dirPath
    std.mem.copyForwards(u8, &res.mergeFileDir, dirPath[0..dirPath.len]);
    std.mem.copyForwards(u8, &res.segmentFileDir, dirPath[0..dirPath.len]);
    return res;
}
