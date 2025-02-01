const std = @import("std");

const calc = @import("calc.zig");

pub const FractalType = enum {
    binaryTree,
    max,
};

const fractalStepRules = makeFractalStepRules(.{
    .{ .idx = FractalType.binaryTree, .func = binaryTreeRule },
});

const fractalStepRuleFuncRetType = union { slice: []const u8, char: u8 };
const fractalStepRuleFuncType = *const fn (u8) fractalStepRuleFuncRetType;

fn makeFractalStepRules(comptime pairs: anytype) [@intFromEnum(FractalType.max)]fractalStepRuleFuncType {
    var entries: [@intFromEnum(FractalType.max)]fractalStepRuleFuncType = undefined;
    inline for (pairs) |pair| {
        entries[@intFromEnum(pair.idx)] = pair.func;
    }
    return entries;
}

fn binaryTreeRule(c: u8) fractalStepRuleFuncRetType {
    switch (c) {
        '1' => {
            return .{ .slice = "11" };
        },
        '0' => {
            return .{ .slice = "1[0]0" };
        },
        else => {
            return .{ .char = c };
        },
    }
    unreachable;
}

fn stepLSystem(system: []const u8) ![]const u8 {
    std.log.debug("char {any}", .{fractalStepRules[@intFromEnum(FractalType.binaryTree)]('0').slice});

    var str = std.ArrayList(u8).init(std.heap.page_allocator);
    defer str.deinit();
    // var i: usize = 0;
    // while (system[i] != 0) {
    for (system) |c| {
        try switch (c) {
            '1' => {
                try str.appendSlice("11");
            },
            '0' => {
                try str.appendSlice("1[0]0");
            },
            else => str.append(c),
        };

        // i += 1;
    }
    return str.toOwnedSlice();
}

// fn drawLSystem(system: []const u8, pos: calc.v2f, angle: f32) !void {
//     var stack = std.ArrayList(struct { pos: calc.v2f, angle: f32 }).init(arena.allocator());
//     defer stack.deinit();

//     var ppos = pos;
//     var pangle = angle;

//     try stack.append(.{ .pos = pos, .angle = angle });
//     // var i: usize = 0;
//     // while (system[i] != 0) {
//     for (system) |c| {
//         switch (c) {
//             '0' => {
//                 const np = ppos.add(v2f.init_angle(pangle).scale(lLen));
//                 rl.drawLine(
//                     @intFromFloat(ppos.x),
//                     @intFromFloat(ppos.y),
//                     @intFromFloat(np.x),
//                     @intFromFloat(np.y),
//                     rl.Color.red,
//                     // ([_]rl.Color{ rl.Color.red, rl.Color.green, rl.Color.yellow })[@intCast(@mod(i, 3))],
//                 );
//                 ppos = np;
//             },
//             '1' => {
//                 const np = ppos.add(v2f.init_angle(pangle).scale(lLen));
//                 rl.drawLine(
//                     @intFromFloat(ppos.x),
//                     @intFromFloat(ppos.y),
//                     @intFromFloat(np.x),
//                     @intFromFloat(np.y),
//                     rl.Color.red,
//                     // ([_]rl.Color{ rl.Color.red, rl.Color.green, rl.Color.yellow })[@intCast(@mod(i, 3))],
//                 );
//                 ppos = np;
//             },
//             '[' => {
//                 try stack.append(.{ .pos = ppos, .angle = pangle });
//                 pangle -= std.math.pi / 4.0;
//             },
//             ']' => {
//                 const last = stack.pop();
//                 ppos = last.pos;
//                 pangle = last.angle + std.math.pi / 4.0;
//             },
//             else => {},
//         }
//     }
// }
