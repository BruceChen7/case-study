const std = @import("std");
const db = @import("db.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var alloc = gpa.allocator();
    var caskDB = try db.DB.init(alloc, null);
    defer caskDB.close();
    try caskDB.open();
    try caskDB.store("foo", "bar");
    var val = try caskDB.load("foo");
    defer alloc.free(val);
    std.debug.print("{s}\n", .{val});
}
