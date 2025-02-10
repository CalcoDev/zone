const std = @import("std");

const sparseSet = @import("sparse_set.zig");

pub const Entity = u32;

pub const System = *const fn (world: *World) void;

pub fn View(comptime ComponentTypes: []const type) type {
    return struct {
        const Self = @This();

        world: *World,
        internal_data: *std.AutoArrayHashMap(u32, usize) = undefined,

        pub const EntityIterator = struct {
            view: *Self,
            index: usize,

            pub fn init(view: *Self) EntityIterator {
                return .{
                    .view = view,
                    .index = 0,
                };
            }

            pub fn next(self: *EntityIterator) ?Entity {
                while (self.index >= 0 and self.index < self.view.internal_data.count()) {
                    const entity = self.view.internal_data.keys()[self.index];
                    self.index += 1;
                    inline for (ComponentTypes) |component_type| {
                        if (!self.view.world.hasComponent(entity, component_type)) {
                            break;
                        }
                    }
                    return entity;
                }
                return null;
            }
        };

        // note calco this was done to better cache and maybe even do like auto type system calls cuz yes
        pub const ComponentIterator = struct {
            view: *Self,
            index: usize,

            pub const ReturnStruct = createStructFromTypeArray(ComponentTypes);

            pub fn init(view: *Self) ComponentIterator {
                return .{
                    .view = view,
                    .index = 0,
                };
            }

            pub fn next(self: *ComponentIterator) ?ReturnStruct {
                var return_struct: ReturnStruct = undefined;
                while (self.index >= 0 and self.index < self.view.internal_data.count()) {
                    const entity = self.view.internal_data.keys()[self.index];
                    self.index += 1;
                    inline for (ComponentTypes) |component_type| {
                        const maybe_component = self.view.world.getComponent(entity, component_type);
                        if (maybe_component) |component| {
                            @field(return_struct, @typeName(component_type)) = component;
                        } else {
                            break;
                        }
                    }
                    return entity;
                }
                return null;
            }
        };

        pub fn init(world: *World) Self {
            var self = Self{ .world = world };

            const first_key = @typeName(ComponentTypes[0]);
            const first_anyset: *sparseSet.SparseSetAny = @ptrCast(world.components.get(first_key).?);
            const sparse_set = first_anyset.asSparseSet(ComponentTypes[0]);

            self.internal_data = &sparse_set.entities;
            return self;
        }

        pub fn getIterator(self: *Self) Self.EntityIterator {
            return Self.EntityIterator.init(self);
        }

        pub fn getCompIterator(self: *Self) Self.ComponentIterator {
            return Self.ComponentIterator.init(self);
        }
    };
}

// todo calco: maybe use some component id thing instead of this string nonsense
pub const World = struct {
    allocator: std.mem.Allocator, // allocates stuff
    entities: std.ArrayList(Entity), // not really sure why this is here
    components: std.StringHashMap(*anyopaque), // @typeName(T) => SparseSet(C) (in theory, in practice it is an SparseSetAny)
    component_names: std.ArrayList([]const u8), // store all components ever added to this. mainly for deinit purposes
    stores: std.ArrayList(sparseSet.SparseSetAny), // Actual memory store for all *anyopaque in above
    systems: std.ArrayList(System), // Pointer to system which is a functoin with custom signature cuz freaky struct comptime
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
            var set = anyset.asSparseSet(@TypeOf(comp));
            set.add(entity, comp) catch unreachable;
            return;
        }

        // TODO(calco): THIS IS ABSOLUTELY ABHORRENT LMFAO
        var set = sparseSet.SparseSet(@TypeOf(comp)).init(self.allocator);
        set.add(entity, comp) catch unreachable;
        var anyset: sparseSet.SparseSetAny = undefined;
        const size = @sizeOf(sparseSet.SparseSet(u8));
        @memcpy(anyset.bytes[0..size], @as(*[size]u8, @ptrCast(&set)));
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
        self.systems.append(system) catch unreachable;
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

    pub fn callSystems(self: *World) void {
        for (self.systems.items) |system| {
            system(self);
        }
    }

    // small helper better syntax, no use function
    pub fn createView(self: *World, comptime types: []const type) View(types) {
        return View(types).init(self);
    }
};

// todo calco this is so frkcing funny lmao
fn createStructFromTypeArray(comptime ComponentTypes: []const type) type {
    comptime var fields: []const std.builtin.Type.StructField = &[_]std.builtin.Type.StructField{};

    for (ComponentTypes) |T| {
        fields = fields ++ &[_]std.builtin.Type.StructField{
            .{
                .name = *@typeName(T), // Use the type name as the field name
                .type = T,
                .default_value = null, // Optional: can be replaced with a valid default
                .is_comptime = false,
                .alignment = @alignOf(T),
            },
        };
    }

    return @Type(.{ .Struct = .{ .fields = fields, .decls = &[_]std.builtin.Type.Declaration{}, .is_tuple = false, .layout = std.builtin.Type.ContainerLayout.auto } });
}
