const std = @import("std");

pub const Option = struct {
    segmentFileSize: u32,
    sync: bool,
    mergeFileDir: std.fs.Dir,
    segmentFileDir: std.fs.Dir,
    mergefileExt: []const u8,
    segmentFileExt: []const u8,
};

pub fn default() Option {
    const currentDir = std.fs.cwd();
    return .{
        .segmentFileSize = 1024 * 32,
        .sync = false,
        .mergeFileDir = currentDir,
        .segmentFileDir = currentDir,
        .mergefileExt = ".merge",
        .segmentFileExt = ".segment",
    };
}
