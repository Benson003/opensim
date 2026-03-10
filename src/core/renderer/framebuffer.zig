const std = @import("std");
const OpenSimImageView = @import("swapchain.zig").OpenSimImageView;
const vk = @import("../../c.zig").vk;

pub const OpenSimFramebuffer = struct {
    _framebuffers: [8]vk.VkFramebuffer,
    _framebuffer_count: u32,

    pub fn createFramebuffers(
        self: *OpenSimFramebuffer,
        device: vk.VkDevice,
        render_pass: vk.VkRenderPass,
        image_views: *OpenSimImageView,
        extent: vk.VkExtent2D,
    ) void {
        self._framebuffer_count = image_views._image_count;

        for (image_views._images_views[0..image_views._image_count], 0..) |view, i| {
            // each framebuffer binds one image view as its color attachment
            // this is what the render pass writes into during rendering
            const attachments = [_]vk.VkImageView{view};

            var framebuffer_ci = std.mem.zeroes(vk.VkFramebufferCreateInfo);
            framebuffer_ci.sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            // must match the render pass this framebuffer will be used with
            framebuffer_ci.renderPass = render_pass;
            framebuffer_ci.attachmentCount = 1;
            framebuffer_ci.pAttachments = &attachments;
            // must match swapchain extent
            framebuffer_ci.width = extent.width;
            framebuffer_ci.height = extent.height;
            // 1 for non-stereoscopic rendering
            framebuffer_ci.layers = 1;

            const result = vk.vkCreateFramebuffer(device, &framebuffer_ci, null, &self._framebuffers[i]);
            if (result != vk.VK_SUCCESS) {
                std.debug.panic("Failed to create framebuffer", .{});
            }
        }
    }

    pub fn cleanup(self: *OpenSimFramebuffer, device: vk.VkDevice) void {
        for (self._framebuffers[0..self._framebuffer_count]) |fb| {
            vk.vkDestroyFramebuffer(device, fb, null);
        }
    }
};
