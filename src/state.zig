const std = @import("std");
const httpz = @import("httpz");

const Self = @This();

document_mutex: std.Thread.Mutex = .{},
event_mutex: std.Thread.Mutex = .{},
event_condition: std.Thread.Condition = .{},
document: std.ArrayList(u8),

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .document = std.ArrayList(u8).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    return self.document.deinit();
}

// addBytes will append new bytes to the document, then broadcast an update to all the event streams
fn addBytes(self: *Self, bytes: []const u8) !void {
    self.document_mutex.lock();
    defer self.document_mutex.unlock();
    try self.document.appendSlice(bytes);
    std.debug.print("The document is now '{s}'\n", .{self.document.items});

    // signal the document as updated
    {
        self.event_mutex.lock();
        defer self.event_mutex.unlock();
        self.event_condition.broadcast();
    }
}

// chat handler for receiving chat update, which has a JSON encoded object with the type of new thing to be added to the document
pub fn chat(self: *Self, req: *httpz.Request, res: *httpz.Response) !void {
    if (try req.jsonObject()) |v| {
        if (v.get("cuniform")) |cuniform| {
            // std.debug.print("got cuniform 0x{s} {s}\n", .{ std.fmt.fmtSliceHexUpper(cuniform.string), cuniform.string });
            try self.addBytes(cuniform.string);
        }
        // if (v.get("byte")) |byte| {
        //      std.debug.print("got bytes 0x{s}\n", .{byte.string});
        // }
        if (v.get("char")) |char| {
            // std.debug.print("got char {s}\n", .{char.string});
            try self.addBytes(char.string);
        }
        if (v.get("emoji")) |emoji| {
            // std.debug.print("got emoji 0x{s} {s}\n", .{ std.fmt.fmtSliceHexUpper(emoji.string), emoji.string });
            try self.addBytes(emoji.string);
        }
    }
    res.body = "thanks";
}

pub fn writeDocument(self: *Self, res: *httpz.Response) !void {
    self.document_mutex.lock();
    defer self.document_mutex.unlock();

    try res.stream.writeAll("event: document\n");
    // split the document into lines
    var lines = std.mem.tokenizeAny(u8, self.document.items, "\n");
    while (lines.next()) |line| {
        try res.stream.writeAll("data: ");
        try res.stream.writeAll(line);
        try res.stream.writeAll("\n\n");
    }
}

pub fn events(self: *Self, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;

    const keepalive_time = std.time.ns_per_s * 5;

    // Set us up an event stream header, and send it to the client before doing anything
    res.useEventStream();
    try res.write();

    // on initial connect, send them a copy of the document
    try self.writeDocument(res);

    // aquire a lock on the event_mutiex
    self.event_mutex.lock();
    defer self.event_mutex.unlock();

    // Loop forever, emitting the current document
    // loop will block on the Thread.Condition, which gets signalled on a Conditon.broadcast() when the document changes
    while (true) {
        // note that condition.wait will unlock the event mutex, then wait for either a new event, or a timeout
        // on return, this re-aquires the mutex
        self.event_condition.timedWait(&self.event_mutex, keepalive_time) catch |err| {
            if (err == error.Timeout) {
                try res.stream.writeAll(": keep-alive ping\n\n");
                continue;
            }
        };
        //try if we get here, it means that the event_condition was signalled, so we can send the updated document now
        std.debug.print("got an update signal !\n", .{});
        try self.writeDocument(res);
    }
}
