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
    ref_count: i32,

    pub fn create(name: []const u8, path: []const u8, @"type": ResourceType, data: *anyopaque) Resource {
        return .{
            .name = name,
            .path = path,
            .type = @"type",
            .data = data,
            .ref_count = 0,
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

    pub fn loadResource(self: *ResourceManager, name: []const u8, @"type": ResourceType, path: []const u8, comptime ref: bool) *Resource {
        const init_res = self.resources.getPtr(name);
        if (init_res != null) {
            if (ref) {
                init_res.?.ref_count += 1;
            }
            return init_res.?;
        }
        std.log.debug("Loaded resource [{s}] with name [{s}]", .{ path, name });
        var resource = getResourceFunc(@"type").load(self, path);
        resource.name = name;
        if (ref) {
            resource.ref_count += 1;
        }
        self.resources.put(name, resource) catch unreachable;
        return &resource;
    }

    pub fn getResource(self: *ResourceManager, name: []const u8, comptime ref: bool) ?*Resource {
        const res = self.resources.getPtr(name);
        if (res != null and ref) {
            res.?.ref_count += 1;
        }
        return res;
    }

    pub fn getResourceData(self: *ResourceManager, comptime TData: type, name: []const u8, comptime ref: bool) *TData {
        return self.getResource(name, ref).?.getData(TData);
    }

    pub fn releaseResource(self: *ResourceManager, resource: *Resource, comptime ref: bool) void {
        resource.ref_count -= 1;
        std.log.debug("Released resource [{s} {s}] (ref_cnt: {}).", .{ resource.name, resource.path, resource.ref_count });
        if (ref and resource.ref_count <= 0) {
            _ = self.resources.remove(resource.name);
            getResourceFunc(resource.type).deinit(self, resource);
            std.log.debug("Deinit resource [{s} {s}].", .{ resource.name, resource.path });
        }
    }

    // TODO(calco): Lmfao, should notify ppl that resources have been released!
    pub fn deinit(self: *ResourceManager) void {
        std.log.debug("Deinit Resource Manager.", .{});
        var iter = self.resources.valueIterator();
        while (iter.next()) |resource| {
            if (resource.ref_count > 0) {
                std.log.warn("Ayo, you are freeing resources that are still referenced! ({s} {s})", .{ resource.name, resource.path });
            }
            getResourceFunc(resource.type).deinit(self, resource);
            std.log.debug("Deinit resource [{s} {s}].", .{ resource.name, resource.path });
        }
        self.resources.deinit();
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

fn deinitTexture(rm: *ResourceManager, self: *Resource) void {
    const data = self.getData(TextureData);
    rl.UnloadTexture(data.texture);
    rm.allocator.destroy(data);
}

// Assoc array stuff
pub const ResourceFunc = struct {
    load: *const fn (rm: *ResourceManager, path: []const u8) Resource,
    deinit: *const fn (rm: *ResourceManager, self: *Resource) void,
};
const resourceFuncs = makeAssocArray(ResourceType, ResourceFunc, @intFromEnum(ResourceType.max), &.{
    .{ .key = ResourceType.texture, .value = .{ .load = &loadTexture, .deinit = &deinitTexture } },
});
fn getResourceFunc(@"type": ResourceType) ResourceFunc {
    return resourceFuncs[@intFromEnum(@"type")];
}

const resourceDatatypes = makeAssocArray(ResourceType, type, @intFromEnum(ResourceType.max), &.{
    .{ .key = ResourceType.texture, .value = TextureData },
});
fn getResourceDatatype(comptime @"type": ResourceType) ResourceFunc {
    return resourceDatatypes[@intFromEnum(@"type")];
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
