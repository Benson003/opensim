const std = @import("std");
const Buffer = @import("../renderer/buffer.zig").Buffer;
const Vertex2D = @import("vertex.zig").Vertex2D;
const vk = @import("../../c.zig").vk;

pub const Mesh = struct {
    vertex_buffer: Buffer,
    index_buffer: Buffer,
    index_count: u32,

    pub fn init(self: *Mesh, device: vk.VkDevice, physical_device: vk.VkPhysicalDevice, vertices: []const Vertex2D, indices: []const u16) !void {
        try self.vertex_buffer.init(device, physical_device, @intCast(vertices.len * @sizeOf(Vertex2D)), vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);
        try self.vertex_buffer.upload(device, std.mem.sliceAsBytes(vertices));

        try self.index_buffer.init(device, physical_device, @intCast(indices.len * @sizeOf(u16)), vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT);
        try self.index_buffer.upload(device, std.mem.sliceAsBytes(indices));
        self.index_count = @intCast(indices.len);
    }

    pub fn deinit(self: *Mesh, device: vk.VkDevice) void {
        self.index_buffer.deinit(device);
        self.vertex_buffer.deinit(device);
    }
};
