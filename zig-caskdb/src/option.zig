pub const Option = struct {
    segmentFileSize: u32,
    sync: bool,
    mergeFilDir: []const u8,
    segmentFileDir: []const u8,
    mergefileExt: []const u8,
    segmentFileExt: []const u8,
};

pub fn default() Option {
    return .{
        .segmentFileSize = 1024 * 32,
        .sync = false,
        .mergeFilDir = "",
        .segmentFileDir = "",
        .mergefileExt = ".merge",
        .segmentFileExt = ".segment",
    };
}
