const std = @import("std");
const httpz = @import("httpz");

const Self = @This();

hits: usize = 0,
document: std.ArrayList(u8),
m: std.Thread.Mutex = .{},
cond: std.Thread.Condition = .{},

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .document = std.ArrayList(u8).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    return self.document.deinit();
}

pub fn increment(self: *Self, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    self.m.lock();
    var hits = self.hits + 1;
    self.hits = hits;
    self.m.unlock();

    res.content_type = httpz.ContentType.TEXT;
    var out = try std.fmt.allocPrint(res.arena, "{d} hits", .{hits});
    res.body = out;
}

const ChatRequest = struct { payload: struct {
    emoji: u8,
    byte: []u8,
    char: u8,
    cuniform: u8,
} };

pub fn chat(self: *Self, req: *httpz.Request, res: *httpz.Response) !void {
    _ = self;
    if (try req.json(ChatRequest)) |chat_request| {
        std.debug.print("Chat Request\n", .{});
        std.debug.print(" emoji {}\n", .{chat_request.payload.emoji});
        std.debug.print(" byte {s}\n", .{chat_request.payload.byte});
        std.debug.print(" char {}\n", .{chat_request.payload.char});
        std.debug.print(" cuniform {}\n", .{chat_request.payload.cuniform});
    }
    res.body = "thanks";
}

pub fn events(self: *Self, req: *httpz.Request, res: *httpz.Response) !void {
    std.debug.print("In a thread now serving the event requests in a big loop\n", .{});
    _ = req;
    _ = self;
    res.header("Content-Type", "text/event-stream");
    res.status = 200;

    try res.write();

    // now sit in a forever loop and emit more every now and then
    while (true) {
        std.debug.print(" writing event ...\n", .{});
        try res.stream.writeAll("event: document\n");
        try res.stream.writeAll("data: 12344\n");
        try res.stream.writeAll("\n");

        std.debug.print("sleep ...\n", .{});
        std.time.sleep(std.time.ns_per_s * 5);
    }
}
