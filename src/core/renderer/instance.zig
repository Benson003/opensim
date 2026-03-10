const std = @import("std");
const vk = @import("../../c.zig").vk;

pub const OpenSimInstance = struct {
    _instance: vk.VkInstance,

    const validation_layers = [_][*c]const u8{
        "VK_LAYER_KHRONOS_validation",
    };

    pub fn createInstance(self: *OpenSimInstance) void {
        var appInfo = std.mem.zeroes(vk.VkApplicationInfo);
        appInfo.sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appInfo.pApplicationName = "OpenSim";
        appInfo.applicationVersion = vk.VK_MAKE_VERSION(0, 0, 1);
        appInfo.pEngineName = "OpenSim SDK";
        appInfo.engineVersion = vk.VK_MAKE_VERSION(0, 0, 1);
        appInfo.apiVersion = vk.VK_API_VERSION_1_2;

        var createInfo = std.mem.zeroes(vk.VkInstanceCreateInfo);
        createInfo.sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        createInfo.pApplicationInfo = &appInfo;

        var glfw_extension_count: u32 = 0;
        var glfw_extensions: [*c][*c]const u8 = undefined;

        glfw_extensions = vk.glfwGetRequiredInstanceExtensions(&glfw_extension_count);
        createInfo.enabledExtensionCount = glfw_extension_count;
        createInfo.ppEnabledExtensionNames = glfw_extensions;

        if (!checkValidationLayerSupport()) {
            std.debug.panic("Validation Layers requested but not avilable", .{});
        }

        createInfo.enabledLayerCount = validation_layers.len;
        createInfo.ppEnabledLayerNames = &validation_layers;

        const result = vk.vkCreateInstance(&createInfo, null, &self._instance);

        if (result != vk.VK_SUCCESS) {
            std.debug.panic("Failed to create instance", .{});
        }
    }

    pub fn cleanup(self: *OpenSimInstance) void {
        vk.vkDestroyInstance(self._instance, null);
    }

    fn checkValidationLayerSupport() bool {
        var layer_count: u32 = 0;
        _ = vk.vkEnumerateInstanceLayerProperties(&layer_count, null);

        var available_layers: [64]vk.VkLayerProperties = undefined;
        _ = vk.vkEnumerateInstanceLayerProperties(&layer_count, &available_layers);

        for (validation_layers) |layer_name| {
            var layer_found = false;

            for (available_layers[0..layer_count]) |layer| {
                if (std.mem.eql(u8, std.mem.sliceTo(layer_name, 0), std.mem.sliceTo(&layer.layerName, 0))) {
                    layer_found = true;
                    break;
                }
            }

            if (!layer_found) return false;
        }

        return true;
    }
};
