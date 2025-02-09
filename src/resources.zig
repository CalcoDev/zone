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
            _ = self.loadResource(resource_cpy.name, resource_cpy.type, resource_cpy.path);
        }
    }

    pub fn loadResource(self: *ResourceManager, name: []const u8, @"type": ResourceType, path: []const u8) *Resource {
        return self.resources.getPtr(name) orelse self.internal_loadResource(name, @"type", path);
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

    fn internal_loadResource(self: *ResourceManager, name: []const u8, @"type": ResourceType, path: []const u8) *Resource {
        var resource = getResourceFunc(@"type").load(self, path);
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
pub const TextureData = struct {
    texture: rl.Texture,
};

fn loadTexture(rm: *ResourceManager, path: []const u8) Resource {
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

// Assoc array stuff
pub const ResourceFunc = struct {
    load: *const fn (rm: *ResourceManager, path: []const u8) Resource,
    deinit: *const fn (rm: *ResourceManager, resource: *Resource) void,
};
const resourceFuncs = makeAssocArray(ResourceType, ResourceFunc, @intFromEnum(ResourceType.max), &.{
    .{ .key = ResourceType.texture, .value = .{ .load = &loadTexture, .deinit = &deinitTexture } },
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
