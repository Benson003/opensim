const std = @import("std");
const vk = @import("../../c.zig").vk;

pub const Texture = struct {
    image: vk.VkImage,
    memory: vk.VkDeviceMemory,
    image_view: vk.VkImageView,
    sampler: vk.VkSampler,
};
