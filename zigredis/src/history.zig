const std = @import("std");
const linenoise = @cImport(@cInclude("linenoise.h"));

pub fn loadhistoryCommand() void {}

pub fn saveHistory(command: [:0]const u8, path: [:0]const u8) void {
    _ = linenoise.linenoiseHistoryAdd(command);
    _ = linenoise.linenoiseHistorySave(path);
}
