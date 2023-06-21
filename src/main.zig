const std = @import("std");
const httpz = @import("httpz");
const State = @import("state.zig");

const base_path = "ui/build"; // set this to the base path where the findal React app is hosted

pub fn main() !void {
    std.debug.print("Starting Z-Chat server\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var ctx = State.init(allocator);
    defer ctx.deinit();

    var server = try httpz.ServerCtx(*State, *State).init(allocator, .{ .port = 3000 }, &ctx);
    server.notFound(fileServer);

    var router = server.router();
    router.get("/increment", State.increment);
    router.get("/", indexHTML);
    router.get("/events", State.events);
    router.post("/chat", State.chat);

    return server.listen();
}

// note that the error handler return `void` and not `!void`
fn fileServer(ctx: *State, req: *httpz.Request, res: *httpz.Response) !void {
    _ = ctx;
    return serveFile(res, req.url.path);
}

fn indexHTML(ctx: *State, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    _ = ctx;
    return serveFile(res, "/index.html");
}

fn serveFile(res: *httpz.Response, path: []const u8) !void {
    std.debug.print("GET {s}\n", .{path});

    var new_path = try std.mem.concat(res.arena, u8, &[_][]const u8{ base_path, path });
    var index_file = try std.fs.cwd().openFile(new_path, .{});
    defer index_file.close();
    res.body = try index_file.readToEndAlloc(res.arena, 460000); // being just big enough to hold the 456k map file
}
