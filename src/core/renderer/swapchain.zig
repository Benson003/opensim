const std = @import("std");
const vk = @import("../../c.zig").vk;
pub const OpenSimSwapChain = struct {
    _swapchain: vk.VkSwapchainKHR,
    _images: [8]vk.VkImage,
    _image_count: u32,
    _format: vk.VkFormat,
    _extent: vk.VkExtent2D,

    pub fn createSwapChain(
        self: *OpenSimSwapChain,
        physical_device: vk.VkPhysicalDevice,
        device: vk.VkDevice,
        surface: vk.VkSurfaceKHR,
        window: *vk.GLFWwindow,
    ) void {
        const format = chooseSwapSurfaceFormat(physical_device, surface);
        const persent_mode = chooseSwapPresentMode(physical_device, surface);
        const extent = chooseSwapExtent(physical_device, surface, window);

        var capablites = std.mem.zeroes(vk.VkSurfaceCapabilitiesKHR);
        _ = vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &capablites);

        var image_count = capablites.minImageCount + 1;
        if (capablites.maxImageCount > 0 and image_count > capablites.maxImageCount) {
            image_count = capablites.maxImageCount;
        }

        var create_info = std.mem.zeroes(vk.VkSwapchainCreateInfoKHR);
        create_info.sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        create_info.surface = surface;
        create_info.minImageCount = image_count;
        create_info.imageFormat = format.format;
        create_info.imageColorSpace = format.colorSpace;
        create_info.imageExtent = extent;
        create_info.imageArrayLayers = 1;
        create_info.imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
        create_info.imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;
        create_info.preTransform = capablites.currentTransform;
        create_info.compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        create_info.presentMode = persent_mode;
        create_info.clipped = vk.VK_TRUE;

        const result = vk.vkCreateSwapchainKHR(device, &create_info, null, &self._swapchain);

        if (result != vk.VK_SUCCESS) {
            std.debug.panic("Failed to create swapchain", .{});
        }

        _ = vk.vkGetSwapchainImagesKHR(device, self._swapchain, &self._image_count, null);

        _ = vk.vkGetSwapchainImagesKHR(device, self._swapchain, &self._image_count, &self._images);

        self._format = format.format;
        self._extent = extent;
    }

    pub fn cleanup(self: *OpenSimSwapChain, device: vk.VkDevice) void {
        vk.vkDestroySwapchainKHR(device, self._swapchain, null);
    }
};

pub const OpenSimImageView = struct {
    _images_views: [8]vk.VkImageView,
    _image_count: u32,

    pub fn createImageViews(self: *OpenSimImageView, openSimSwapchain: OpenSimSwapChain, device: vk.VkDevice) void {
        self._image_count = openSimSwapchain._image_count;
        for (openSimSwapchain._images[0..openSimSwapchain._image_count], 0..) |image, i| {
            var create_info = std.mem.zeroes(vk.VkImageViewCreateInfo);
            create_info.sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            create_info.image = image;
            create_info.viewType = vk.VK_IMAGE_VIEW_TYPE_2D;
            create_info.format = openSimSwapchain._format;
            create_info.components.r = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            create_info.components.g = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            create_info.components.b = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            create_info.components.a = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            create_info.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
            create_info.subresourceRange.baseMipLevel = 0;
            create_info.subresourceRange.levelCount = 1;
            create_info.subresourceRange.baseArrayLayer = 0;
            create_info.subresourceRange.layerCount = 1;

            const result = vk.vkCreateImageView(device, &create_info, null, &self._images_views[i]);

            if (result != vk.VK_SUCCESS) {
                std.debug.panic("Failed to create image views", .{});
            }
        }
    }

    pub fn cleanup(self: *OpenSimImageView, device: vk.VkDevice) void {
        for (self._images_views[0..self._image_count]) |view| {
            vk.vkDestroyImageView(device, view, null);
        }
    }
};

fn chooseSwapSurfaceFormat(
    physical_device: vk.VkPhysicalDevice,
    surface: vk.VkSurfaceKHR,
) vk.VkSurfaceFormatKHR {
    var format_count: u32 = 0;
    _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, null);
    var formats: [128]vk.VkSurfaceFormatKHR = undefined;
    _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, &formats[0]);

    for (formats[0..format_count]) |format| {
        if (format.format == vk.VK_FORMAT_B8G8R8A8_SRGB and
            format.colorSpace == vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
        {
            return format;
        }
    }
    return formats[0];
}

fn chooseSwapPresentMode(
    physical_device: vk.VkPhysicalDevice,
    surface: vk.VkSurfaceKHR,
) vk.VkPresentModeKHR {
    var mode_count: u32 = 0;
    _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &mode_count, null);

    var modes: [8]vk.VkPresentModeKHR = undefined;
    _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &mode_count, &modes);
    for (modes[0..mode_count]) |mode| {
        if (mode == vk.VK_PRESENT_MODE_MAILBOX_KHR) return mode;
    }

    return vk.VK_PRESENT_MODE_FIFO_KHR;
}
fn chooseSwapExtent(
    physical_device: vk.VkPhysicalDevice,
    surface: vk.VkSurfaceKHR,
    window: *vk.GLFWwindow,
) vk.VkExtent2D {
    var capablites = std.mem.zeroes(vk.VkSurfaceCapabilitiesKHR);
    _ = vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &capablites);

    if (capablites.currentExtent.width != std.math.maxInt(u32)) {
        return capablites.currentExtent;
    }

    var width: c_int = 0;
    var height: c_int = 0;

    vk.glfwGetFramebufferSize(window, &width, &height);

    return vk.VkExtent2D{
        .width = std.math.clamp(
            @as(u32, @intCast(width)),
            capablites.minImageExtent.width,
            capablites.maxImageExtent.width,
        ),
        .height = std.math.clamp(@as(u32, @intCast(height)), capablites.minImageExtent.height, capablites.maxImageExtent.height),
    };
}
