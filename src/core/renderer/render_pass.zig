const std = @import("std");
const vk = @import("../../c.zig").vk;
pub const OpenSimRenderPass = struct {
    _render_pass: vk.VkRenderPass,

    pub fn createRenderPass(
        self: *OpenSimRenderPass,
        device: vk.VkDevice,
        format: vk.VkFormat,
    ) void {
        var color_attachment = std.mem.zeroes(vk.VkAttachmentDescription);
        color_attachment.format = format;
        color_attachment.samples = vk.VK_SAMPLE_COUNT_1_BIT;
        color_attachment.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
        color_attachment.storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE;
        color_attachment.stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        color_attachment.stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
        color_attachment.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
        color_attachment.finalLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

        var color_attachment_ref = std.mem.zeroes(vk.VkAttachmentReference);
        color_attachment_ref.attachment = 0;
        color_attachment_ref.layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        var subpass = std.mem.zeroes(vk.VkSubpassDescription);
        subpass.pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS;
        subpass.colorAttachmentCount = 1;
        subpass.pColorAttachments = &color_attachment_ref;

        var dependency = std.mem.zeroes(vk.VkSubpassDependency);
        dependency.srcSubpass = vk.VK_SUBPASS_EXTERNAL;
        dependency.dstSubpass = 0;
        dependency.srcStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        dependency.srcAccessMask = 0;
        dependency.dstStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        dependency.dstAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

        var render_pass_ci = std.mem.zeroes(vk.VkRenderPassCreateInfo);
        render_pass_ci.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        render_pass_ci.attachmentCount = 1;
        render_pass_ci.pAttachments = &color_attachment;
        render_pass_ci.subpassCount = 1;
        render_pass_ci.pSubpasses = &subpass;
        render_pass_ci.dependencyCount = 1;
        render_pass_ci.pDependencies = &dependency;

        const result = vk.vkCreateRenderPass(device, &render_pass_ci, null, &self._render_pass);
        if (result != vk.VK_SUCCESS) {
            std.debug.panic("Failed to create render pass", .{});
        }
    }

    pub fn cleanup(self: *OpenSimRenderPass, device: vk.VkDevice) void {
        vk.vkDestroyRenderPass(device, self._render_pass, null);
    }
};
