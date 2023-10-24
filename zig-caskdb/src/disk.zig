const DiskEntry = struct {
    keySize: u32,
    valueSize: u32,
    key: []const u8,
    value: []const u8,
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

const FileType = enum {
    SEGMENT,
    WAL,
    MERGE,
};

pub const File = union(FileType) {
    SEGMENT: DiskEntry,
    WAL: DiskEntry,
    MERGE: DiskEntry,
};
