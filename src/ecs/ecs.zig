const std = @import("std");

const sparseSet = @import("sparse_set.zig");

pub const Entity = u32;

pub const System = struct {
    init: *const fn (world: *World) void, // called when system is init enter_tree
    tick: *const fn (world: *World, f32) void, // called every frame process
    deinit: *const fn (world: *World) void, // called when system byebye exit_tree

    pub fn init(
        p_init: *const fn (world: *World) void,
        tick: *const fn (world: *World, f32) void,
        deinit: *const fn (world: *World) void,
    ) System {
        return .{
            .init = p_init,
            .tick = tick,
            .deinit = deinit,
        };
    }
};

// todo calco: maybe use some component id thing instead of this string nonsense
pub const World = struct {
    allocator: std.mem.Allocator, // allocates stuff
    entities: std.ArrayList(Entity), // not really sure why this is here
    components: std.StringHashMap(*anyopaque), // @typeName(T) => SparseSet(C) (in theory, in practice it is an SparseSetAny)
    component_names: std.ArrayList([]const u8), // store all components ever added to this. mainly for deinit purposes
    stores: std.ArrayList(sparseSet.SparseSetAny), // Actual memory store for all *anyopaque in above
    systems: std.ArrayList(System), // Pointers to all systems
    entity_counter: u32, // Number of entities alive

    pub fn init(allocator: std.mem.Allocator) World {
        return .{
            .allocator = allocator,
            .entities = std.ArrayList(Entity).init(allocator),
            .components = std.StringHashMap(*anyopaque).init(allocator),
            .component_names = std.ArrayList([]const u8).init(allocator),
            .stores = std.ArrayList(sparseSet.SparseSetAny).init(allocator),
            .systems = std.ArrayList(System).init(allocator),
            .entity_counter = 0,
        };
    }

    pub fn deinit(self: *World) void {
        self.entities.deinit();

        for (self.component_names.items) |component_name| {
            const anyset: *sparseSet.SparseSetAny = @ptrCast(self.components.get(component_name).?);
            // todo calco this is kinda scuffed but freeing memory should work the same regardless of type
            const set = anyset.asSparseSet(u8);
            set.deinit();
        }
        self.stores.deinit();
        self.components.deinit();

        for (self.systems.items) |system| {
            system.deinit(self);
        }
        self.systems.deinit();

        self.component_names.deinit();
    }

    pub fn createEntity(self: *World) u32 {
        const id = self.entity_counter;
        self.entity_counter += 1;
        self.entities.append(id) catch unreachable;
        return id;
    }

    pub fn removeEntity(self: *World, entity: Entity) void {
        for (self.entities.items, 0..) |e, i| {
            if (e == entity) {
                _ = self.entities.orderedRemove(i);
                break;
            }
        }
    }

    pub fn addComponent(self: *World, entity: Entity, comp: anytype) void {
        const key = @typeName(@TypeOf(comp));
        if (self.components.get(key)) |maybe_store| {
            const anyset: *sparseSet.SparseSetAny = @ptrCast(maybe_store);
            const set = anyset.asSparseSet(@TypeOf(comp));
            set.add(entity, comp);
            return;
        }

        // TODO(calco): THIS IS ABSOLUTELY ABHORRENT LMFAO
        var set = sparseSet.SparseSet(@TypeOf(comp)).init(self.allocator);
        set.add(entity, comp) catch unreachable;
        var anyset: sparseSet.SparseSetAny = undefined;
        @memcpy(anyset.bytes[0..80], @as(*[80]u8, @ptrCast(&set)));
        self.stores.append(anyset) catch unreachable;

        self.components.put(key, @ptrCast(&self.stores.items[self.stores.items.len - 1])) catch unreachable;
    }

    pub fn hasComponent(self: *World, entity: Entity, comptime C: type) bool {
        const key = @typeName(C);
        if (self.components.get(key)) |maybe_store| {
            const anyset: *sparseSet.SparseSetAny = @ptrCast(maybe_store);
            const set = anyset.asSparseSet(C);
            return set.has(entity);
        }
        return false;
    }

    pub fn getComponent(self: *World, entity: Entity, comptime C: type) ?*C {
        const key = @typeName(C);
        if (self.components.get(key)) |maybe_store| {
            const anyset: *sparseSet.SparseSetAny = @ptrCast(maybe_store);
            const set = anyset.asSparseSet(C);
            return set.get(entity);
        }
        return null;
    }

    pub fn addSystem(self: *World, system: System) void {
        self.systems.append(system);
    }

    pub fn hasSystem(self: *World, system: System) bool {
        return self.getSystemIndex(system) != std.math.maxInt(usize);
    }

    pub fn removeSystem(self: *World, system: System) bool {
        const idx = self.getSystemIndex(system);
        if (idx != std.math.maxInt(usize)) {
            self.systems.swapRemove(idx);
            return true;
        }
        return false;
    }

    fn getSystemIndex(self: *World, system: System) usize {
        for (self.systems.items, 0..) |s1, i| {
            if (s1.init == system.init and s1.tick == system.tick and s1.deinit == system.deinit) {
                return i;
            }
        }
        return std.math.maxInt(usize);
    }
};
