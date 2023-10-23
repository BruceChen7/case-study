const std = @import("std");
const db = @import("db.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var alloc = gpa.allocator();
    var caskDB = try db.DB.init(alloc, "cask.db");
    defer caskDB.deinit();
    try caskDB.store("foo", "bar");
    try caskDB.load("foo");
}
