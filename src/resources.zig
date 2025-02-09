const std = @import("std");

const rl = @import("libs/raylib.zig");

pub const ResourceType = enum(u8) {
    shader = 1,
    texture,
    curve,
    max,
};

pub const Resource = struct {
    name: []const u8,
    path: []const u8,
    type: ResourceType,
    data: *anyopaque,
    spawn_data: *anyopaque = undefined,

    pub fn create(name: []const u8, path: []const u8, @"type": ResourceType, data: *anyopaque) Resource {
        return .{
            .name = name,
            .path = path,
            .type = @"type",
            .data = data,
        };
    }

    pub fn getData(self: *Resource, comptime TData: type) *TData {
        return @ptrCast(@alignCast(self.data));
    }
};

pub const ResourceHashmap = std.StringHashMap(Resource);

pub const ResourceManager = struct {
    allocator: std.mem.Allocator,
    resources: ResourceHashmap,

    pub fn create(allocator: std.mem.Allocator) ResourceManager {
        return .{
            .allocator = allocator,
            .resources = ResourceHashmap.init(allocator),
        };
    }

    pub fn reloadResources(self: *ResourceManager) void {
        var iter = self.resources.valueIterator();
        while (iter.next()) |resource| {
            const resource_cpy = resource.*;
            self.internal_unloadResource(resource);
            _ = self.loadResource(resource_cpy.name, resource_cpy.type, resource_cpy.path, resource_cpy.spawn_data);
        }
    }

    pub fn loadResource(self: *ResourceManager, name: []const u8, @"type": ResourceType, path: []const u8, data: *anyopaque) *Resource {
        return self.resources.getPtr(name) orelse self.internal_loadResource(name, @"type", path, data);
    }

    pub fn getResource(self: *ResourceManager, name: []const u8) ?*Resource {
        return self.resources.getPtr(name);
    }

    pub fn getResourceData(self: *ResourceManager, comptime TData: type, name: []const u8) *TData {
        return self.getResource(name).?.getData(TData);
    }

    pub fn releaseResource(self: *ResourceManager, resource: *Resource) void {
        self.internal_unloadResource(resource);
    }

    pub fn deinit(self: *ResourceManager) void {
        std.log.debug("Deinit Resource Manager.", .{});
        var iter = self.resources.valueIterator();
        while (iter.next()) |resource| {
            self.internal_unloadResource(resource);
        }
        self.resources.deinit();
    }

    fn internal_loadResource(self: *ResourceManager, name: []const u8, @"type": ResourceType, path: []const u8, data: *anyopaque) *Resource {
        std.log.debug("{}", .{data});
        var resource = getResourceFunc(@"type").load(self, path, data);
        resource.spawn_data = data;
        resource.name = name;
        self.resources.put(name, resource) catch unreachable;
        std.log.debug("Loaded {s} resource [\"{s}\" \"{s}\"].", .{ @tagName(resource.type), resource.name, resource.path });
        return self.resources.getPtr(name).?;
    }

    fn internal_unloadResource(self: *ResourceManager, resource: *Resource) void {
        std.log.debug("Unloaded {s} resource [\"{s}\" \"{s}\"].", .{ @tagName(resource.type), resource.name, resource.path });
        getResourceFunc(resource.type).deinit(self, resource);
        _ = self.resources.remove(resource.name);
    }
};

// Loading functions
pub const TextureData = struct { texture: rl.Texture };
fn loadTexture(rm: *ResourceManager, path: []const u8, _: *anyopaque) Resource {
    const tex = rl.LoadTexture(path.ptr);
    const data = rm.allocator.create(TextureData) catch unreachable;
    data.*.texture = tex;
    return Resource.create("", path, ResourceType.texture, data);
}
fn deinitTexture(rm: *ResourceManager, resource: *Resource) void {
    const data = resource.getData(TextureData);
    rl.UnloadTexture(data.texture);
    rm.allocator.destroy(data);
}

pub const ShaderData = struct { shader_id: c_uint, locs: ?[*c]c_int }; // TODO(calco): need to store locs for free
const ShaderDataParam = struct {
    vertex: bool,
    fragment: bool,
    compute: bool,
};
fn loadShader(rm: *ResourceManager, path: []const u8, init_data: *anyopaque) Resource {
    const data_param: *ShaderDataParam = @ptrCast(init_data);
    const data = rm.allocator.create(ShaderData) catch unreachable;
    if (data_param.compute) {
        const compute_data = rl.LoadFileText(path.ptr);
        const compute_shader = rl.rlCompileShader(compute_data, rl.RL_COMPUTE_SHADER);
        data.*.shader_id = rl.rlLoadComputeShaderProgram(compute_shader);
        data.*.locs = null;
        rl.UnloadFileText(compute_data);
    } else {
        const vs = if (data_param.vertex) rl.TextFormat("%s.vert", path.ptr) else null;
        const fs = if (data_param.vertex) rl.TextFormat("%s.vert", path.ptr) else null;
        const shader = rl.LoadShader(vs, fs);
        data.*.shader_id = shader.id;
        data.*.locs = shader.locs;
    }
    return Resource.create("", path, ResourceType.shader, data);
}
fn deinitShader(rm: *ResourceManager, resource: *Resource) void {
    const data = resource.getData(ShaderData);
    if (data.locs) |locs| {
        rl.UnloadShader(.{
            .id = data.shader_id,
            .locs = locs,
        });
    } else {
        rl.rlUnloadShaderProgram(data.shader_id);
    }
    rm.allocator.destroy(data);
}

// Assoc array stuff
pub const ResourceFunc = struct {
    load: *const fn (rm: *ResourceManager, path: []const u8, data: *anyopaque) Resource,
    deinit: *const fn (rm: *ResourceManager, resource: *Resource) void,
};
const resourceFuncs = makeAssocArray(ResourceType, ResourceFunc, @intFromEnum(ResourceType.max), &.{
    .{ .key = ResourceType.texture, .value = .{ .load = &loadTexture, .deinit = &deinitTexture } },
    .{ .key = ResourceType.shader, .value = .{ .load = &loadShader, .deinit = &deinitShader } },
});
fn getResourceFunc(@"type": ResourceType) ResourceFunc {
    return resourceFuncs[@intFromEnum(@"type")];
}

fn AssocArrayPair(comptime TKey: type, comptime TValue: type) type {
    return struct {
        key: TKey,
        value: TValue,
    };
}
fn makeAssocArray(comptime TKey: type, comptime TValue: type, comptime count: comptime_int, comptime pairs: []const AssocArrayPair(TKey, TValue)) [count]TValue {
    var entries: [count]TValue = undefined;
    inline for (pairs) |pair| {
        entries[@intCast(@intFromEnum(pair.key))] = pair.value;
    }
    return entries;
}
