const std = @import("std");
const clap = @import("clap");

fn start_java_process(allocator: std.mem.Allocator, jar_name: []const u8, xms: []const u8, xmx: []const u8) !void {
    var xms_buf: [16]u8 = undefined;
    var xmx_buf: [16]u8 = undefined;

    var xms_flag = try std.fmt.bufPrint(&xms_buf, "-Xms{s}", .{xms});
    var xmx_flag = try std.fmt.bufPrint(&xmx_buf, "-Xmx{s}", .{xmx});

    var process_args = [_][]const u8{ "java", xms_flag, xmx_flag, "-jar", jar_name, "nogui" };

    var java_process = std.ChildProcess.init(&process_args, allocator);
    try java_process.spawn();

    const term = java_process.wait();

    std.testing.expectEqual(term, std.ChildProcess.Term{ .Exited = 0 }) catch {
        return;
    };
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help              Display this help and exit.
        \\-v, --version           Output version information and exit.
        \\-j, --jar      <str>    The .jar file for the Minecraft server.
        \\--Xms          <str>    The initial memory allocation pool for the JVM.
        \\--Xmx          <str>    The maximum memory allocation pool for the JVM.
    );

    var diagnostic = clap.Diagnostic{};

    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .allocator = gpa.allocator(),
        .diagnostic = &diagnostic,
    }) catch |err| {
        return diagnostic.report(std.io.getStdErr().writer(), err) catch {};
    };

    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(stdout, clap.Help, &params, .{});
    if (res.args.version != 0) {
        try stdout.print("0.0.0\n", .{});
        return;
    }

    var jar = res.args.jar orelse "server.jar";

    var initial_pool = res.args.Xms orelse "1G";
    var maximum_pool = res.args.Xmx orelse "1G";

    try start_java_process(gpa.allocator(), jar, initial_pool, maximum_pool);
}
