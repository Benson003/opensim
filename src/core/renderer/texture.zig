const std = @import("std");
const vk = @import("../../c.zig").vk;
const stb_image = @import("../../c.zig").stb_image;
const Buffer = @import("buffer.zig").Buffer;
const beginOneTimeCommands = @import("renderer.zig").beginOneTimeCommands;
const endOneTimeCommands = @import("renderer.zig").endOneTimeCommands;
const findMemoryType = @import("buffer.zig").findMemoryType;
pub const TextureErrors = error{ ImageLoadFailed, ImageCreationFailed, MemoryAllocationFailed, ImageViewCreationFailed, SamplerCreationFailed };

fn transitionImageLayout(
    device: vk.VkDevice,
    command_pool: vk.VkCommandPool,
    queue: vk.VkQueue,
    image: vk.VkImage,
    old_layout: vk.VkImageLayout,
    new_layout: vk.VkImageLayout,
) void {
    const cmd = beginOneTimeCommands(device, command_pool);

    var barrier = std.mem.zeroes(vk.VkImageMemoryBarrier);
    barrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barrier.oldLayout = old_layout;
    barrier.newLayout = new_layout;
    barrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
    barrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
    barrier.image = image;
    barrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
    barrier.subresourceRange.baseMipLevel = 0;
    barrier.subresourceRange.levelCount = 1;
    barrier.subresourceRange.baseArrayLayer = 0;
    barrier.subresourceRange.layerCount = 1;

    var src_stage: vk.VkPipelineStageFlags = 0;
    var dst_stage: vk.VkPipelineStageFlags = 0;

    if (old_layout == vk.VK_IMAGE_LAYOUT_UNDEFINED and
        new_layout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
    {
        barrier.srcAccessMask = 0;
        barrier.dstAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT;
        src_stage = vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        dst_stage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT;
    } else if (old_layout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and
        new_layout == vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
    {
        barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT;
        src_stage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT;
        dst_stage = vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
    } else {
        std.debug.panic("unsupported layout transition", .{});
    }

    vk.vkCmdPipelineBarrier(
        cmd,
        src_stage,
        dst_stage,
        0,
        0,
        null,
        0,
        null,
        1,
        &barrier,
    );

    endOneTimeCommands(device, command_pool, queue, cmd);
}

pub const Texture = struct {
    image: vk.VkImage,
    memory: vk.VkDeviceMemory,
    image_view: vk.VkImageView,
    sampler: vk.VkSampler,

    pub fn deinit(self: *Texture, device: vk.VkDevice) void {
        vk.vkDestroySampler(device, self.sampler, null);
        vk.vkDestroyImageView(device, self.image_view, null);
        vk.vkDestroyImage(device, self.image, null);
        vk.vkFreeMemory(device, self.memory, null);
    }

    pub fn init(
        self: *Texture,
        device: vk.VkDevice,
        physical_device: vk.VkPhysicalDevice,
        command_pool: vk.VkCommandPool,
        graphics_queue: vk.VkQueue,
        path: [*:0]const u8,
    ) !void {
        var width: c_int = 0;
        var height: c_int = 0;
        var channels: c_int = 0;

        const pixels = stb_image.stbi_load(path, &width, &height, &channels, stb_image.STBI_rgb_alpha);
        if (pixels == null) {
            return TextureErrors.ImageLoadFailed;
        }
        defer stb_image.stbi_image_free(pixels);
        const image_size: u32 = @intCast(width * height * 4);
        var staging = std.mem.zeroes(Buffer);
        try staging.init(device, physical_device, image_size, vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT);
        defer staging.deinit(device);

        try staging.upload(device, std.mem.sliceAsBytes(pixels[0..@as(usize, image_size)]));

        var image_ci = std.mem.zeroes(vk.VkImageCreateInfo);
        image_ci.sType = vk.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
        image_ci.imageType = vk.VK_IMAGE_TYPE_2D;
        image_ci.extent.width = @intCast(width);
        image_ci.extent.height = @intCast(height);
        image_ci.extent.depth = 1;
        image_ci.mipLevels = 1;
        image_ci.arrayLayers = 1;
        image_ci.format = vk.VK_FORMAT_R8G8B8A8_SRGB;
        image_ci.tiling = vk.VK_IMAGE_TILING_OPTIMAL;
        image_ci.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
        image_ci.usage = vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT | vk.VK_IMAGE_USAGE_SAMPLED_BIT;
        image_ci.sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;
        image_ci.samples = vk.VK_SAMPLE_COUNT_1_BIT;

        const result = vk.vkCreateImage(device, &image_ci, null, &self.image);
        if (result != vk.VK_SUCCESS) {
            return TextureErrors.ImageCreationFailed;
        }

        var mem_requirements = std.mem.zeroes(vk.VkMemoryRequirements);
        vk.vkGetImageMemoryRequirements(device, self.image, &mem_requirements);

        const memory_type = try findMemoryType(
            physical_device,
            mem_requirements.memoryTypeBits,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        );

        var alloc_info = std.mem.zeroes(vk.VkMemoryAllocateInfo);
        alloc_info.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        alloc_info.allocationSize = mem_requirements.size;
        alloc_info.memoryTypeIndex = memory_type;

        const alloc_result = vk.vkAllocateMemory(device, &alloc_info, null, &self.memory);
        if (alloc_result != vk.VK_SUCCESS) {
            return TextureErrors.MemoryAllocationFailed;
        }

        _ = vk.vkBindImageMemory(device, self.image, self.memory, 0);
        transitionImageLayout(device, command_pool, graphics_queue, self.image, vk.VK_IMAGE_LAYOUT_UNDEFINED, vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);

        const copy_cmd = beginOneTimeCommands(device, command_pool);

        var region = std.mem.zeroes(vk.VkBufferImageCopy);
        region.bufferOffset = 0;
        region.bufferRowLength = 0; // 0 means tightly packed
        region.bufferImageHeight = 0; // 0 means tightly packed
        region.imageSubresource.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
        region.imageSubresource.mipLevel = 0;
        region.imageSubresource.baseArrayLayer = 0;
        region.imageSubresource.layerCount = 1;
        region.imageOffset = .{ .x = 0, .y = 0, .z = 0 };
        region.imageExtent = .{
            .width = @intCast(width),
            .height = @intCast(height),
            .depth = 1,
        };

        vk.vkCmdCopyBufferToImage(
            copy_cmd,
            staging.handle,
            self.image,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            &region,
        );

        endOneTimeCommands(device, command_pool, graphics_queue, copy_cmd);
        try self.createImageView(device);
        try self.createSampler(device);

        transitionImageLayout(device, command_pool, graphics_queue, self.image, vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
    }

    fn createImageView(self: *Texture, device: vk.VkDevice) !void {
        var view_ci = std.mem.zeroes(vk.VkImageViewCreateInfo);
        view_ci.sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        view_ci.image = self.image;
        view_ci.viewType = vk.VK_IMAGE_VIEW_TYPE_2D;
        view_ci.format = vk.VK_FORMAT_R8G8B8A8_SRGB;
        view_ci.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
        view_ci.subresourceRange.baseMipLevel = 0;
        view_ci.subresourceRange.levelCount = 1;
        view_ci.subresourceRange.baseArrayLayer = 0;
        view_ci.subresourceRange.layerCount = 1;

        const view_result = vk.vkCreateImageView(device, &view_ci, null, &self.image_view);
        if (view_result != vk.VK_SUCCESS) {
            return TextureErrors.ImageViewCreationFailed;
        }
    }
    fn createSampler(self: *Texture, device: vk.VkDevice) !void {
        var sampler_ci = std.mem.zeroes(vk.VkSamplerCreateInfo);
        sampler_ci.sType = vk.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
        sampler_ci.magFilter = vk.VK_FILTER_LINEAR; // magnification
        sampler_ci.minFilter = vk.VK_FILTER_LINEAR; // minification
        sampler_ci.addressModeU = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT;
        sampler_ci.addressModeV = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT;
        sampler_ci.addressModeW = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT;
        sampler_ci.anisotropyEnable = vk.VK_FALSE;
        sampler_ci.maxAnisotropy = 1.0;
        sampler_ci.borderColor = vk.VK_BORDER_COLOR_INT_OPAQUE_BLACK;
        sampler_ci.unnormalizedCoordinates = vk.VK_FALSE;
        sampler_ci.compareEnable = vk.VK_FALSE;
        sampler_ci.mipmapMode = vk.VK_SAMPLER_MIPMAP_MODE_LINEAR;
        sampler_ci.mipLodBias = 0.0;
        sampler_ci.minLod = 0.0;
        sampler_ci.maxLod = 0.0;

        const result = vk.vkCreateSampler(device, &sampler_ci, null, &self.sampler);
        if (result != vk.VK_SUCCESS) {
            return TextureErrors.SamplerCreationFailed;
        }
    }
};
