pub const vk = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
});

pub const stb_image = @cImport({
    @cDefine("STB_IMAGE_IMPLEMENTATION", "1");
    @cInclude("stb_image.h");
});

pub const miniaudio = @cImport({
    @cInclude("miniaudio.h");
});
