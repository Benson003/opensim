const std = @import("std");
const vk = @import("../../c.zig").vk;
pub const Vertex2D = struct {
    position: [2]f32,
    uv: [2]f32,
    color: [4]u8,

    pub fn bindingDescription() vk.VkVertexInputBindingDescription {
        var binding_description = std.mem.zeroes(vk.VkVertexInputBindingDescription);
        binding_description.stride = @sizeOf(Vertex2D);
        binding_description.binding = 0;
        binding_description.inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX;
        return binding_description;
    }
    pub fn attributeDescription() [3]vk.VkVertexInputAttributeDescription {
        var postion_decricrptions = std.mem.zeroes(vk.VkVertexInputAttributeDescription);
        postion_decricrptions.offset = @offsetOf(Vertex2D, "position");
        postion_decricrptions.location = 0;
        postion_decricrptions.binding = 0;
        postion_decricrptions.format = vk.VK_FORMAT_R32G32_SFLOAT;

        var uv_decricrptions = std.mem.zeroes(vk.VkVertexInputAttributeDescription);
        uv_decricrptions.offset = @offsetOf(Vertex2D, "uv");
        uv_decricrptions.location = 1;
        uv_decricrptions.binding = 0;
        uv_decricrptions.format = vk.VK_FORMAT_R32G32_SFLOAT;
        var color_decricrptions = std.mem.zeroes(vk.VkVertexInputAttributeDescription);
        color_decricrptions.offset = @offsetOf(Vertex2D, "color");
        color_decricrptions.location = 2;
        color_decricrptions.binding = 0;
        color_decricrptions.format = vk.VK_FORMAT_R8G8B8A8_UNORM;

        return [3]vk.VkVertexInputAttributeDescription{ postion_decricrptions, uv_decricrptions, color_decricrptions };
    }
};
