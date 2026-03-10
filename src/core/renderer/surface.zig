const std = @import("std");
const vk = @import("../../c.zig").vk;
pub const OpenSimSurface = struct {
    _surface: vk.VkSurfaceKHR,
    pub fn createSurface(self: *OpenSimSurface, instance: vk.VkInstance, window: *vk.GLFWwindow) void {
        const result = vk.glfwCreateWindowSurface(instance, window, null, &self._surface);
        if (result != vk.VK_SUCCESS) {
            std.debug.panic("Failed to create window surface", .{});
        }
    }

    pub fn cleanup(self: *OpenSimSurface, instance: vk.VkInstance) void {
        vk.vkDestroySurfaceKHR(instance, self._surface, null);
    }
};
