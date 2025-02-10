const std = @import("std");

pub fn SparseSet(comptime T: type) type {
    return struct {
        const Self = @This();

        entities: std.AutoArrayHashMap(u32, usize),
        data: std.ArrayList(T),

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .entities = std.AutoArrayHashMap(u32, usize).init(allocator),
                .data = std.ArrayList(T).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.entities.deinit();
            self.data.deinit();
        }

        pub fn length(self: *Self) usize {
            return self.data.items.len;
        }

        pub fn add(self: *Self, entity: u32, component: T) !void {
            try self.entities.put(entity, self.data.items.len);
            try self.data.append(component);
        }

        pub fn get(self: *Self, entity: u32) ?*T {
            if (self.entities.get(entity)) |index| {
                return &self.data.items[index];
            }
            return null;
        }

        pub fn has(self: *Self, entity: u32) bool {
            return self.entities.contains(entity);
        }

        pub fn remove(self: *Self, entity: u32) void {
            _ = self.entities.remove(entity);
        }
    };
}

// todo: this is incredibly hacky and bad lmao
// technically sparseset will always be same size tho
pub const SparseSetAny = extern struct {
    bytes: [@sizeOf(SparseSet(u8))]u8,

    pub fn fromPtr(ptr: *anyopaque) *SparseSetAny {
        return @ptrCast(ptr);
    }

    pub fn asSparseSet(self: *SparseSetAny, comptime T: type) *SparseSet(T) {
        return @ptrCast(@alignCast(self));
    }
};
