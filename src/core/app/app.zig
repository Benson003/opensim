const std = @import("std");
const vk = @import("../../c.zig").vk;

const OpenSimInstance = @import("../renderer/instance.zig").OpenSimInstance;
const OpenSimSurface = @import("../renderer/surface.zig").OpenSimSurface;
const OpenSimPhysicalDevice = @import("../renderer/device.zig").OpenSimPhysicalDevice;
const OpenSimLogicalDevice = @import("../renderer/device.zig").OpenSimLogicalDevice;
const OpenSimSwapchain = @import("../renderer/swapchain.zig").OpenSimSwapChain;
const OpenSimImageView = @import("../renderer/swapchain.zig").OpenSimImageView;

const OpenSimRenderPass = @import("../renderer/render_pass.zig").OpenSimRenderPass;

const OpenSimPipeline = @import("../renderer/pipline.zig").OpenSimPipeline;
const OpenSimFramebuffer = @import("../renderer/framebuffer.zig").OpenSimFramebuffer;
const OpenSimCommandBuffer = @import("../renderer/renderer.zig").OpenSimCommandBuffer;
const OpenSimSyncObjects = @import("../renderer/sync_objects.zig").OpenSimSyncObjects;

const Mesh = @import("../mesh/mesh.zig").Mesh;
const Vertex2D = @import("../mesh/vertex.zig").Vertex2D;
const RenderContext = @import("../renderer/renderer.zig").RenderContext;

const MAX_FRAMES_IN_FLIGHT = 2;

fn framebufferResizeCallback(window: ?*vk.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    _ = width;
    _ = height;
    const app: *OpenSimApp = @ptrCast(@alignCast(vk.glfwGetWindowUserPointer(window)));
    app._framebuffer_resized = true;
}
pub const OpenSimApp = struct {
    _framebuffer_resized: bool,
    _window: ?*vk.GLFWwindow,
    _instance: OpenSimInstance,
    _surface: OpenSimSurface,
    _physical_device: OpenSimPhysicalDevice,
    _logical_device: OpenSimLogicalDevice,
    _swapchain: OpenSimSwapchain,
    _image_views: OpenSimImageView,
    _render_pass: OpenSimRenderPass,
    _pipeline: OpenSimPipeline,
    _framebuffers: OpenSimFramebuffer,
    _command_buffers: OpenSimCommandBuffer,
    _sync: OpenSimSyncObjects,
    _current_frame: u32,
    _test_mesh: Mesh,

    pub fn init(self: *OpenSimApp) void {
        _ = vk.glfwInit();
        vk.glfwWindowHint(vk.GLFW_CLIENT_API, vk.GLFW_NO_API);

        self._window = vk.glfwCreateWindow(800, 600, "Open Sim", null, null).?;

        // in init after window creation
        vk.glfwSetWindowUserPointer(self._window, self);

        _ = vk.glfwSetFramebufferSizeCallback(self._window, framebufferResizeCallback);
        self._instance.createInstance();
        self._surface.createSurface(self._instance._instance, self._window.?);

        self._physical_device.pickPhysicalDevice(self._instance._instance);
        self._logical_device.createLogicalDevice(self._physical_device._physical_device, self._surface._surface);
        self._swapchain.createSwapChain(self._physical_device._physical_device, self._logical_device._device, self._surface._surface, self._window.?);
        self._image_views.createImageViews(self._swapchain, self._logical_device._device);
        self._render_pass.createRenderPass(self._logical_device._device, self._swapchain._format);
        self._pipeline.createPipeline3d(self._logical_device._device, self._render_pass._render_pass, self._swapchain._extent);
        self._pipeline.createPipeline2d(self._logical_device._device, self._render_pass._render_pass, self._swapchain._extent);
        self._framebuffers.createFramebuffers(self._logical_device._device, self._render_pass._render_pass, &self._image_views, self._swapchain._extent);
        self._command_buffers.createCommandPool(self._logical_device._device, self._logical_device._graphics_family);
        self._command_buffers.createCommandBuffers(self._logical_device._device);
        self._sync.createSyncObjects(self._logical_device._device, self._swapchain._image_count);

        const vertices = [_]Vertex2D{
            .{ .position = .{ 0.0, 0.0 }, .uv = .{ 0.0, 0.0 }, .color = .{ 255, 0, 0, 255 } },
            .{ .position = .{ 200.0, 0.0 }, .uv = .{ 1.0, 0.0 }, .color = .{ 0, 255, 0, 255 } },
            .{ .position = .{ 200.0, 200.0 }, .uv = .{ 1.0, 1.0 }, .color = .{ 0, 0, 255, 255 } },
            .{ .position = .{ 0.0, 200.0 }, .uv = .{ 0.0, 1.0 }, .color = .{ 255, 255, 0, 255 } },
        };
        const indices = [_]u16{ 0, 1, 2, 0, 2, 3 };
        self._test_mesh.init(
            self._logical_device._device,
            self._physical_device._physical_device,
            &vertices,
            &indices,
        ) catch std.debug.panic("Failed to create Test Mesh", .{});
    }

    pub fn run(self: *OpenSimApp) void {
        while (vk.glfwWindowShouldClose(self._window) == 0) {
            vk.glfwPollEvents();
            self.drawFrame();
        }
        _ = vk.vkDeviceWaitIdle(self._logical_device._device);
    }

    fn drawFrame(self: *OpenSimApp) void {
        // 1. wait for this frame slot to be free
        _ = vk.vkWaitForFences(self._logical_device._device, 1, &self._sync._in_flight[self._current_frame], vk.VK_TRUE, std.math.maxInt(u64));
        _ = vk.vkResetFences(self._logical_device._device, 1, &self._sync._in_flight[self._current_frame]);

        // 2. get the next swapchain image to draw into
        var image_index: u32 = 0;
        _ = vk.vkAcquireNextImageKHR(self._logical_device._device, self._swapchain._swapchain, std.math.maxInt(u64), self._sync._image_available[self._current_frame], null, &image_index);

        const ctx = RenderContext{
            .device = self._logical_device._device,
            .render_pass = self._render_pass._render_pass,
            .pipeline_3d = self._pipeline._pipeline3d,
            .pipeline_2d = self._pipeline._pipeline2d,
            .pipeline_layout_2d = self._pipeline._pipeline_layout2d,
            .extent = self._swapchain._extent,
        };
        const frame = self._command_buffers.beginFrame(ctx, self._framebuffers._framebuffers[image_index], self._current_frame);
        OpenSimCommandBuffer.draw3D(frame, ctx);
        OpenSimCommandBuffer.draw2D(frame, ctx, &self._test_mesh);
        OpenSimCommandBuffer.endFrame(frame);

        // 4. submit the command buffer to the graphics queue
        // wait on image_available before starting, signal render_finished when done
        const wait_stage: u32 = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        var submit_info = std.mem.zeroes(vk.VkSubmitInfo);
        submit_info.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submit_info.waitSemaphoreCount = 1;
        submit_info.pWaitSemaphores = &self._sync._image_available[self._current_frame];
        submit_info.pWaitDstStageMask = &wait_stage;
        submit_info.commandBufferCount = 1;
        submit_info.pCommandBuffers = &self._command_buffers._command_buffers[self._current_frame];
        submit_info.signalSemaphoreCount = 1;
        submit_info.pSignalSemaphores = &self._sync._render_finished[self._current_frame];
        submit_info.pWaitSemaphores = &self._sync._image_available[self._current_frame];

        _ = vk.vkQueueSubmit(self._logical_device._graphics_queue, 1, &submit_info, self._sync._in_flight[self._current_frame]);

        // 5. present the finished image to the screen
        var present_info = std.mem.zeroes(vk.VkPresentInfoKHR);
        present_info.sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        present_info.waitSemaphoreCount = 1;
        present_info.pWaitSemaphores = &self._sync._render_finished[self._current_frame];
        present_info.swapchainCount = 1;
        present_info.pSwapchains = &self._swapchain._swapchain;
        present_info.pImageIndices = &image_index;

        const present_result = vk.vkQueuePresentKHR(self._logical_device._present_queue, &present_info);
        if (present_result == vk.VK_ERROR_OUT_OF_DATE_KHR or
            present_result == vk.VK_SUBOPTIMAL_KHR or
            self._framebuffer_resized)
        {
            self._framebuffer_resized = false;
            self.recreateSwapchain();
        }

        // 6. advance to next frame slot
        self._current_frame = (self._current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    fn recreateSwapchain(self: *OpenSimApp) void {
        // handle minimization — wait until window has size again
        var width: c_int = 0;
        var height: c_int = 0;
        while (width == 0 or height == 0) {
            vk.glfwGetFramebufferSize(self._window.?, &width, &height);
            vk.glfwWaitEvents();
        }

        _ = vk.vkDeviceWaitIdle(self._logical_device._device);

        // destroy in reverse order
        self._framebuffers.cleanup(self._logical_device._device);
        self._pipeline.cleanup(self._logical_device._device);
        self._render_pass.cleanup(self._logical_device._device);
        self._image_views.cleanup(self._logical_device._device);
        self._swapchain.cleanup(self._logical_device._device);

        // recreate
        self._swapchain.createSwapChain(self._physical_device._physical_device, self._logical_device._device, self._surface._surface, self._window.?);
        self._image_views.createImageViews(self._swapchain, self._logical_device._device);
        self._render_pass.createRenderPass(self._logical_device._device, self._swapchain._format);
        self._pipeline.createPipeline3d(self._logical_device._device, self._render_pass._render_pass, self._swapchain._extent);
        self._pipeline.createPipeline2d(self._logical_device._device, self._render_pass._render_pass, self._swapchain._extent);
        self._framebuffers.createFramebuffers(self._logical_device._device, self._render_pass._render_pass, &self._image_views, self._swapchain._extent);
    }

    pub fn clean(self: *OpenSimApp) void {
        self._test_mesh.deinit(self._logical_device._device);
        self._sync.cleanup(self._logical_device._device);
        self._command_buffers.cleanup(self._logical_device._device);
        self._framebuffers.cleanup(self._logical_device._device);
        self._pipeline.cleanup(self._logical_device._device);
        self._render_pass.cleanup(self._logical_device._device);
        self._image_views.cleanup(self._logical_device._device);
        self._swapchain.cleanup(self._logical_device._device);
        self._logical_device.cleanup();
        self._physical_device.cleanup();
        self._surface.cleanup(self._instance._instance);
        self._instance.cleanup();

        vk.glfwDestroyWindow(self._window.?);
        vk.glfwTerminate();
    }
};
