const std = @import("std");
const vk = @import("../../c.zig").vk;
const stb_image = @import("../../c.zig").stb_image;

pub const Texture = struct {
    image: vk.VkImage,
    memory: vk.VkDeviceMemory,
    image_view: vk.VkImageView,
    sampler: vk.VkSampler,
};
