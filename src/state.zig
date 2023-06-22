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

// because unicode - all things are a slice of u8 instead of simple bytes
const ChatRequest = struct {
    emoji: []u8,
    byte: []u8,
    char: []u8,
    cuniform: []u8,
};

fn addBytes(self: *Self, bytes: []const u8) void {
    self.document_mutex.lock();
    defer self.document_mutex.unlock();
    self.document.appendSlice(bytes) catch |err| {
        std.debug.print("Error appending to document - allocation error {any}\n", .{err});
    };
    std.debug.print("The document is now '{s}'\n", .{self.document.items});
}

// chat handler for receiving chat update, which has a JSON encoded object with the type of new thing to be added to the document
pub fn chat(self: *Self, req: *httpz.Request, res: *httpz.Response) !void {
    _ = self;
    if (try req.jsonObject()) |v| {
        if (v.get("cuniform")) |cuniform| {
            std.debug.print("got cuniform 0x{s} {s}\n", .{ std.fmt.fmtSliceHexUpper(cuniform.string), cuniform.string });
            self.addBytes(cuniform.string);
        }
        if (v.get("byte")) |byte| {
            std.debug.print("got bytes 0x{s}\n", .{byte.string});
        }
        if (v.get("char")) |char| {
            std.debug.print("got char {s}\n", .{char.string});
            self.addBytes(char.string);
        }
        if (v.get("emoji")) |emoji| {
            std.debug.print("got emoji 0x{s} {s}\n", .{ std.fmt.fmtSliceHexUpper(emoji.string), emoji.string });
            self.addBytes(emoji.string);
        }
    }

    // if (try req.jsonValue()) |v| {
    //     std.debug.print("got value {any}\n", .{v});
    // }

    // if (try req.json(ChatRequest)) |chat_request| {
    //     std.debug.print("Chat Request\n", .{});
    //     std.debug.print(" emoji {s}\n", .{chat_request.emoji});
    //     std.debug.print(" byte {s}\n", .{chat_request.byte});
    //     std.debug.print(" char {s}\n", .{chat_request.char});
    //     std.debug.print(" cuniform {s}\n", .{chat_request.cuniform});
    // }
    res.body = "thanks";
}

pub fn events(self: *Self, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.useEventStream();
    try res.write();

    // Loop forever, emitting the current document
    // loop will block on the Thread.Condition, which gets signalled on a Conditon.broadcast() when the document changes
    while (true) {
        {
            self.document_mutex.lock();
            defer self.document_mutex.unlock();
            // split the document into lines
            var lines = std.mem.tokenizeAny(u8, self.document.items, "\n");
            while (lines.next()) |line| {
                std.debug.print("got line {s}\n", .{line});
                try res.stream.writeAll("data: ");
                try res.stream.writeAll(line);
                try res.stream.writeAll("\n\n");
            }
        }

        std.time.sleep(std.time.ns_per_s * 5);
    }
}
