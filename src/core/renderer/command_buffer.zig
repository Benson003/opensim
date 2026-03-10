const std = @import("std");
const vk = @import("../../c.zig").vk;
// How many frames the CPU can be ahead of the GPU.
// 2 = double buffering. CPU records frame 2 while GPU renders frame 1.
// Increasing this reduces GPU idle time but increases input latency.
// For a flight sim 2 is the sweet spot — don't change this without profiling.
const MAX_FRAMES_IN_FLIGHT = 2;

pub const OpenSimCommandBuffer = struct {
    _command_pool: vk.VkCommandPool,
    _command_buffers: [MAX_FRAMES_IN_FLIGHT]vk.VkCommandBuffer,

    pub fn createCommandPool(
        self: *OpenSimCommandBuffer,
        device: vk.VkDevice,
        graphics_family: u32,
    ) void {
        // Command pool is just a memory arena for command buffers.
        // All command buffers allocated from this pool use the graphics queue.
        // RESET_COMMAND_BUFFER_BIT means we can re-record one buffer at a time
        // without wiping the entire pool — essential for per-frame recording.
        var pool_ci = std.mem.zeroes(vk.VkCommandPoolCreateInfo);
        pool_ci.sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        pool_ci.flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        pool_ci.queueFamilyIndex = graphics_family;

        const result = vk.vkCreateCommandPool(device, &pool_ci, null, &self._command_pool);
        if (result != vk.VK_SUCCESS) {
            std.debug.panic("Failed to create command pool", .{});
        }
    }

    pub fn createCommandBuffers(self: *OpenSimCommandBuffer, device: vk.VkDevice) void {
        // One command buffer per frame in flight so they don't overwrite each other.
        // PRIMARY means this buffer gets submitted directly to the GPU queue.
        // If you add multithreaded rendering later, worker threads record SECONDARY
        // buffers which get called from this PRIMARY buffer.
        var alloc_info = std.mem.zeroes(vk.VkCommandBufferAllocateInfo);
        alloc_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        alloc_info.commandPool = self._command_pool;
        alloc_info.level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        alloc_info.commandBufferCount = MAX_FRAMES_IN_FLIGHT;

        const result = vk.vkAllocateCommandBuffers(device, &alloc_info, &self._command_buffers);
        if (result != vk.VK_SUCCESS) {
            std.debug.panic("Failed to allocate command buffers", .{});
        }
    }

    pub fn recordCommandBuffer(
        self: *OpenSimCommandBuffer,
        framebuffer: vk.VkFramebuffer,
        render_pass: vk.VkRenderPass,
        pipeline: vk.VkPipeline,
        extent: vk.VkExtent2D,
        frame_index: u32,
    ) void {
        const cmd = self._command_buffers[frame_index];

        // Wipe this frame's previous recording so we can write fresh commands.
        // We re-record every frame because the framebuffer and state can change.
        _ = vk.vkResetCommandBuffer(cmd, 0);

        // Tell Vulkan we are starting to record commands into this buffer.
        // ONE_TIME_SUBMIT would be faster for buffers recorded once and reused
        // but we re-record every frame so leave flags at 0.
        var begin_info = std.mem.zeroes(vk.VkCommandBufferBeginInfo);
        begin_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

        _ = vk.vkBeginCommandBuffer(cmd, &begin_info);

        // The clear color is what the screen is filled with before drawing anything.
        // This is your background color — change these 4 floats (R, G, B, A) to
        // change the sky/background color. Values are 0.0 to 1.0.
        const clear_color = vk.VkClearValue{
            .color = .{ .float32 = .{ 0.1, 0.1, 0.1, 1.0 } }, // anime sky blue
        };

        // Begin render pass — this binds the framebuffer we are drawing into
        // and clears it to clear_color defined above.
        // renderArea defines which region of the framebuffer to draw into.
        // Almost always set to full extent — only change if you are doing
        // split screen or rendering to a sub-region of a texture.
        var render_pass_begin = std.mem.zeroes(vk.VkRenderPassBeginInfo);
        render_pass_begin.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        render_pass_begin.renderPass = render_pass;
        render_pass_begin.framebuffer = framebuffer;
        render_pass_begin.renderArea.offset = .{ .x = 0, .y = 0 };
        render_pass_begin.renderArea.extent = extent;
        render_pass_begin.clearValueCount = 1;
        render_pass_begin.pClearValues = &clear_color;

        vk.vkCmdBeginRenderPass(cmd, &render_pass_begin, vk.VK_SUBPASS_CONTENTS_INLINE);

        // Bind the graphics pipeline — this tells the GPU which shaders to use
        // and what all the rasterizer, blending, viewport settings are.
        // To switch materials or render modes (outline pass, shadow pass)
        // call vkCmdBindPipeline again with a different pipeline.
        vk.vkCmdBindPipeline(cmd, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);

        // ── THE DRAW CALL ─────────────────────────────────────────────────────
        // This is what sends work to the GPU.
        // vertexCount   = 3 — one triangle, 3 vertices
        // instanceCount = 1 — drawing one instance, not instanced rendering
        // firstVertex   = 0 — start from vertex 0 in the buffer
        // firstInstance = 0 — start from instance 0
        //
        // To draw more triangles later change vertexCount.
        // To draw the same mesh many times (trees, bullets, vortex markers)
        // increase instanceCount and read gl_InstanceIndex in the vertex shader.
        // To draw indexed geometry (real meshes) use vkCmdDrawIndexed instead.
        vk.vkCmdDraw(cmd, 3, 1, 0, 0);

        // Done recording draw calls for this pass.
        // If you add a second pass (outline, bloom, UI) call vkCmdEndRenderPass,
        // then vkCmdBeginRenderPass again with the next pass's framebuffer.
        vk.vkCmdEndRenderPass(cmd);

        // Finished recording. Buffer is now ready to be submitted to the GPU.
        const end_result = vk.vkEndCommandBuffer(cmd);
        if (end_result != vk.VK_SUCCESS) {
            std.debug.panic("Failed to record command buffer", .{});
        }
    }

    pub fn cleanup(self: *OpenSimCommandBuffer, device: vk.VkDevice) void {
        // Destroying the pool automatically frees all command buffers from it.
        // No need to free _command_buffers individually.
        vk.vkDestroyCommandPool(device, self._command_pool, null);
    }
};
