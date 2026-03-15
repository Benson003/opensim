const std = @import("std");
const MAX_ENTITES: u24 = 65536;
pub const Entity_Id = packed struct { index: u24, generation: u8 };
pub const ECSError = error{ MaxEntitesReached, InvalidHandle };
pub const ECS = struct {
    generations: []u8,
    occupied: []u8,
    free_list: []u24,
    free_count: u32,
    entity_count: u32,

    pub fn init(allocator: std.mem.Allocator) !ECS {
        return ECS{
            .generations = try allocator.alloc(u8, MAX_ENTITES),
            .occupied = try allocator.alloc(u8, MAX_ENTITES / 8),
            .free_list = try allocator.alloc(u24, MAX_ENTITES),
            .free_count = 0,
            .entity_count = 0,
        };
    }

    pub fn createEntity(self: *ECS) !Entity_Id {
        if (self.free_count > 0) {
            self.free_count -= 1;
            const index = self.free_list[self.free_count];
            self.generations[index] += 1;
            self.setUsed(index);
            self.entity_count += 1;
            return Entity_Id{
                .index = index,
                .generation = self.generations[index],
            };
        } else if (self.entity_count < MAX_ENTITES) {
            const index: u24 = @intCast(self.entity_count);
            self.entity_count += 1;
            self.setUsed(index);
            return Entity_Id{ .index = index, .generation = 0 };
        } else {
            return ECSError.MaxEntitesReached;
        }
    }

    pub fn destroyEntity(self: *ECS, entity_id: Entity_Id) !void {
        if (self.isUsed(entity_id.index) and self.generations[entity_id.index] == entity_id.generation) {
            self.clearUsed(entity_id.index);
            self.free_list[self.free_count] = entity_id.index;
            self.free_count += 1;
            self.entity_count -= 1;
        } else {
            return ECSError.InvalidHandle;
        }
    }

    fn isUsed(self: *ECS, index: u24) bool {
        const byte_index = index >> 3;
        const bit_index = index & 7;
        return (self.occupied[byte_index] >> @intCast(bit_index)) & 1 != 0;
    }

    fn setUsed(self: *ECS, index: u24) void {
        const byte_index = index >> 3;
        const bit_index = index & 7;
        self.occupied[byte_index] |= @as(u8, 1) << @intCast(bit_index);
    }

    fn clearUsed(self: *ECS, index: u24) void {
        const byte_index = index >> 3;
        const bit_index = index & 7;
        self.occupied[byte_index] &= ~(@as(u8, 1) << @intCast(bit_index));
    }

    pub fn deinit(self: *ECS, allocator: std.mem.Allocator) void {
        allocator.free(self.generations);
        allocator.free(self.occupied);
        allocator.free(self.free_list);
    }
};
