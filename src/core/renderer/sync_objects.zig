const std = @import("std");
const vk = @import("../../c.zig").vk;

const MAX_FRAMES_IN_FLIGHT = 2;

pub const OpenSimSyncObjects = struct {
    // Semaphores are GPU-GPU sync — they signal between queue operations.
    // The GPU waits on them, the CPU never blocks on a semaphore.

    // Signals when the swapchain image is ready to be drawn into.
    // The GPU waits on this before starting the render pass.
    _image_available: [MAX_FRAMES_IN_FLIGHT]vk.VkSemaphore,

    // Signals when rendering is finished and the image is ready to present.
    // The GPU waits on this before presenting to the screen.
    _render_finished: [MAX_FRAMES_IN_FLIGHT]vk.VkSemaphore,

    // Fences are CPU-GPU sync — the CPU blocks on these.
    // Stops the CPU from recording frame N+2 before the GPU finishes frame N.
    // Without this the CPU would race ahead and overwrite command buffers
    // the GPU is still reading.
    _in_flight: [MAX_FRAMES_IN_FLIGHT]vk.VkFence,

    pub fn createSyncObjects(self: *OpenSimSyncObjects, device: vk.VkDevice) void {
        var semaphore_ci = std.mem.zeroes(vk.VkSemaphoreCreateInfo);
        semaphore_ci.sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

        // SIGNALED flag means the fence starts in the signaled state.
        // Without this the very first frame would wait forever because
        // nothing has signaled the fence yet.
        var fence_ci = std.mem.zeroes(vk.VkFenceCreateInfo);
        fence_ci.sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        fence_ci.flags = vk.VK_FENCE_CREATE_SIGNALED_BIT;

        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            const r1 = vk.vkCreateSemaphore(device, &semaphore_ci, null, &self._image_available[i]);
            const r2 = vk.vkCreateSemaphore(device, &semaphore_ci, null, &self._render_finished[i]);
            const r3 = vk.vkCreateFence(device, &fence_ci, null, &self._in_flight[i]);

            if (r1 != vk.VK_SUCCESS or r2 != vk.VK_SUCCESS or r3 != vk.VK_SUCCESS) {
                std.debug.panic("Failed to create sync objects", .{});
            }
        }
    }

    pub fn cleanup(self: *OpenSimSyncObjects, device: vk.VkDevice) void {
        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            vk.vkDestroySemaphore(device, self._image_available[i], null);
            vk.vkDestroySemaphore(device, self._render_finished[i], null);
            vk.vkDestroyFence(device, self._in_flight[i], null);
        }
    }
};
