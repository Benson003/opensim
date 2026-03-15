const std = @import("std");
const vk = @import("../../c.zig").vk;
const Mesh = @import("../mesh/mesh.zig").Mesh;
// How many frames the CPU can be ahead of the GPU.
// 2 = double buffering. CPU records frame 2 while GPU renders frame 1.
// Increasing this reduces GPU idle time but increases input latency.
// For a flight sim 2 is the sweet spot — don't change this without profiling.

pub const FrameData = struct {
    cmd: vk.VkCommandBuffer,
    extent: vk.VkExtent2D,
    frame_index: u32,
};

pub const RenderContext = struct {
    device: vk.VkDevice,
    render_pass: vk.VkRenderPass,
    pipeline_3d: vk.VkPipeline,
    pipeline_2d: vk.VkPipeline,
    pipeline_layout_2d: vk.VkPipelineLayout, // needed for push constants
    extent: vk.VkExtent2D,
};

pub fn beginOneTimeCommands(device: vk.VkDevice, pool: vk.VkCommandPool) vk.VkCommandBuffer {
    var alloc_info = std.mem.zeroes(vk.VkCommandBufferAllocateInfo);
    alloc_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    alloc_info.level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    alloc_info.commandPool = pool;
    alloc_info.commandBufferCount = 1;

    var cmd: vk.VkCommandBuffer = undefined;
    _ = vk.vkAllocateCommandBuffers(device, &alloc_info, &cmd);

    var begin_info = std.mem.zeroes(vk.VkCommandBufferBeginInfo);
    begin_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    begin_info.flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    _ = vk.vkBeginCommandBuffer(cmd, &begin_info);

    return cmd;
}

pub fn endOneTimeCommands(device: vk.VkDevice, pool: vk.VkCommandPool, queue: vk.VkQueue, cmd: vk.VkCommandBuffer) void {
    _ = vk.vkEndCommandBuffer(cmd);

    var submit_info = std.mem.zeroes(vk.VkSubmitInfo);
    submit_info.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submit_info.commandBufferCount = 1;
    submit_info.pCommandBuffers = &cmd;

    _ = vk.vkQueueSubmit(queue, 1, &submit_info, null);
    _ = vk.vkQueueWaitIdle(queue);

    vk.vkFreeCommandBuffers(device, pool, 1, &cmd);
}

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
    pub fn beginFrame(
        self: *OpenSimCommandBuffer,
        ctx: RenderContext,
        framebuffer: vk.VkFramebuffer,
        frame_index: u32,
    ) FrameData {
        const cmd = self._command_buffers[frame_index];
        _ = vk.vkResetCommandBuffer(cmd, 0);

        var begin_info = std.mem.zeroes(vk.VkCommandBufferBeginInfo);
        begin_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        _ = vk.vkBeginCommandBuffer(cmd, &begin_info);

        const clear_color = vk.VkClearValue{
            .color = .{ .float32 = .{ 0.1, 0.1, 0.1, 1.0 } },
        };

        var render_pass_begin = std.mem.zeroes(vk.VkRenderPassBeginInfo);
        render_pass_begin.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        render_pass_begin.renderPass = ctx.render_pass;
        render_pass_begin.framebuffer = framebuffer;
        render_pass_begin.renderArea.offset = .{ .x = 0, .y = 0 };
        render_pass_begin.renderArea.extent = ctx.extent;
        render_pass_begin.clearValueCount = 1;
        render_pass_begin.pClearValues = &clear_color;

        vk.vkCmdBeginRenderPass(cmd, &render_pass_begin, vk.VK_SUBPASS_CONTENTS_INLINE);

        return FrameData{
            .cmd = cmd,
            .extent = ctx.extent,
            .frame_index = frame_index,
        };
    }

    pub fn draw2D(frame: FrameData, ctx: RenderContext, mesh: *Mesh) void {
        vk.vkCmdBindPipeline(frame.cmd, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, ctx.pipeline_2d);

        // bind vertex buffer
        const offsets = [_]u64{0};
        vk.vkCmdBindVertexBuffers(frame.cmd, 0, 1, &mesh.vertex_buffer.handle, &offsets);

        // bind index buffer
        vk.vkCmdBindIndexBuffer(frame.cmd, mesh.index_buffer.handle, 0, vk.VK_INDEX_TYPE_UINT16);

        // push screen size
        const screen_size = [2]f32{
            @floatFromInt(frame.extent.width),
            @floatFromInt(frame.extent.height),
        };
        vk.vkCmdPushConstants(
            frame.cmd,
            ctx.pipeline_layout_2d,
            vk.VK_SHADER_STAGE_VERTEX_BIT,
            0,
            @sizeOf([2]f32),
            &screen_size,
        );

        // indexed draw
        vk.vkCmdDrawIndexed(frame.cmd, mesh.index_count, 1, 0, 0, 0);
    }

    pub fn draw3D(frame: FrameData, ctx: RenderContext) void {
        vk.vkCmdBindPipeline(frame.cmd, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, ctx.pipeline_3d);
        // placeholder — real mesh drawing comes later
    }

    pub fn endFrame(frame: FrameData) void {
        vk.vkCmdEndRenderPass(frame.cmd);
        const result = vk.vkEndCommandBuffer(frame.cmd);
        if (result != vk.VK_SUCCESS) {
            std.debug.panic("Failed to record command buffer", .{});
        }
    }

    pub fn cleanup(self: *OpenSimCommandBuffer, device: vk.VkDevice) void {
        // Destroying the pool automatically frees all command buffers from it.
        // No need to free _command_buffers individually.
        vk.vkDestroyCommandPool(device, self._command_pool, null);
    }
};
