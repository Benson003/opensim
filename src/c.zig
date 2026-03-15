pub const vk = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
});

pub const miniaudio = @cImport({
    @cInclude("miniaudio.h");
});
