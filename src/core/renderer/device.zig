const std = @import("std");
const vk = @import("../../c.zig").vk;
pub const OpenSimPhysicalDevice = struct {
    _physical_device: vk.VkPhysicalDevice,

    pub fn pickPhysicalDevice(self: *OpenSimPhysicalDevice, instance: vk.VkInstance) void {
        var device_count: u32 = 0;

        _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, null);

        if (device_count == 0) {
            std.debug.panic("No GPUs with vulkan support", .{});
        }

        var devices: [16]vk.VkPhysicalDevice = undefined;
        _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, &devices);

        for (devices[0..device_count]) |device| {
            if (isDeviceSuitable(device)) {
                self._physical_device = device;
                return;
            }
            std.debug.panic("No sutiable GPU found", .{});
        }
    }
    fn isDeviceSuitable(device: vk.VkPhysicalDevice) bool {
        var properties = std.mem.zeroes(vk.VkPhysicalDeviceProperties);
        vk.vkGetPhysicalDeviceProperties(device, &properties);
        std.debug.print("Found GPU: {s}\n", .{@as([*c]const u8, &properties.deviceName)});
        return true;
    }

    pub fn cleanup(_: *OpenSimPhysicalDevice) void {}
};

pub const QueueFamilyIndices = struct {
    graphics_family: ?u32 = null,
    present_family: ?u32 = null,

    pub fn isComplete(self: QueueFamilyIndices) bool {
        return self.graphics_family != null and self.present_family != null;
    }
};

pub const OpenSimLogicalDevice = struct {
    _device: vk.VkDevice,
    _graphics_queue: vk.VkQueue,
    _present_queue: vk.VkQueue,
    _graphics_family: u32,
    _present_family: u32,

    pub fn createLogicalDevice(
        self: *OpenSimLogicalDevice,
        physical_device: vk.VkPhysicalDevice,
        surface: vk.VkSurfaceKHR,
    ) void {
        const indices = findQueueFamilies(physical_device, surface);
        if (!indices.isComplete()) {
            std.debug.panic("Failed to find sutiable Queue familes", .{});
        }
        const queue_priorty: f32 = 1.0;
        self._graphics_family = indices.graphics_family.?;
        self._present_family = indices.present_family.?;

        var graphics_queue_ci = std.mem.zeroes(vk.VkDeviceQueueCreateInfo);
        graphics_queue_ci.sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        graphics_queue_ci.queueFamilyIndex = indices.graphics_family.?;
        graphics_queue_ci.queueCount = 1;
        graphics_queue_ci.pQueuePriorities = &queue_priorty;

        const device_features = std.mem.zeroes(vk.VkPhysicalDeviceFeatures);

        var device_ci = std.mem.zeroes(vk.VkDeviceCreateInfo);
        device_ci.sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        device_ci.pQueueCreateInfos = &graphics_queue_ci;
        device_ci.queueCreateInfoCount = 1;
        device_ci.pEnabledFeatures = &device_features;

        const device_extensions = [_][*c]const u8{
            "VK_KHR_swapchain",
        };

        device_ci.enabledExtensionCount = device_extensions.len;
        device_ci.ppEnabledExtensionNames = &device_extensions;

        const result = vk.vkCreateDevice(physical_device, &device_ci, null, &self._device);
        if (result != vk.VK_SUCCESS) {
            std.debug.panic("Failed to create logical device", .{});
        }

        vk.vkGetDeviceQueue(self._device, indices.graphics_family.?, 0, &self._graphics_queue);
        vk.vkGetDeviceQueue(self._device, indices.present_family.?, 0, &self._present_queue);
    }

    pub fn cleanup(self: *OpenSimLogicalDevice) void {
        vk.vkDestroyDevice(self._device, null);
    }
};

fn findQueueFamilies(physical_device: vk.VkPhysicalDevice, surface: vk.VkSurfaceKHR) QueueFamilyIndices {
    var indices = QueueFamilyIndices{};

    var queue_family_count: u32 = 0;
    vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);

    var queue_families: [16]vk.VkQueueFamilyProperties = undefined;
    vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, &queue_families);

    for (queue_families[0..queue_family_count], 0..) |family, i| {
        const idx: u32 = @intCast(i);

        if (family.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT != 0) {
            indices.graphics_family = idx;
        }

        var present_support: vk.VkBool32 = vk.VK_FALSE;
        _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(physical_device, idx, surface, &present_support);
        if (present_support == vk.VK_TRUE) {
            indices.present_family = idx;
        }

        if (indices.isComplete()) break;
    }

    return indices;
}
