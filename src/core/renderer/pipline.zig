const std = @import("std");
const vk = @import("../../c.zig").vk;

pub const OpenSimPipeline = struct {
    _pipeline: vk.VkPipeline,
    _pipeline_layout: vk.VkPipelineLayout,

    pub fn createPipeline(
        self: *OpenSimPipeline,
        device: vk.VkDevice,
        render_pass: vk.VkRenderPass,
        extent: vk.VkExtent2D,
    ) void {
        // ── Shader loading ────────────────────────────────────────────────────
        // Read compiled SPIR-V binaries from disk. These are produced by glslc
        // during zig build. Once the pipeline is created the modules are destroyed
        // — Vulkan bakes them in and doesn't need the originals anymore.
        const vert_code = loadShader("shaders/triangle.vert.spv") catch {
            std.debug.panic("Failed to load vertex shader", .{});
        };
        const frag_code = loadShader("shaders/triangle.frag.spv") catch {
            std.debug.panic("Failed to load fragment shader", .{});
        };
        defer std.heap.page_allocator.free(vert_code);
        defer std.heap.page_allocator.free(frag_code);

        const vert_module = createShaderModule(device, vert_code);
        const frag_module = createShaderModule(device, frag_code);
        defer vk.vkDestroyShaderModule(device, vert_module, null);
        defer vk.vkDestroyShaderModule(device, frag_module, null);

        // ── Shader stages ─────────────────────────────────────────────────────
        // Tell Vulkan which module is vertex and which is fragment.
        // pName is the entry point — matches "void main()" in your GLSL files.
        // To add a geometry or tessellation shader, add another stage here.
        var vert_stage = std.mem.zeroes(vk.VkPipelineShaderStageCreateInfo);
        vert_stage.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        vert_stage.stage = vk.VK_SHADER_STAGE_VERTEX_BIT;
        vert_stage.module = vert_module;
        vert_stage.pName = "main";

        var frag_stage = std.mem.zeroes(vk.VkPipelineShaderStageCreateInfo);
        frag_stage.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        frag_stage.stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT;
        frag_stage.module = frag_module;
        frag_stage.pName = "main";

        const shader_stages = [_]vk.VkPipelineShaderStageCreateInfo{ vert_stage, frag_stage };

        // ── Vertex input ──────────────────────────────────────────────────────
        // Describes the format of vertex data coming into the vertex shader.
        // Empty for now because triangle positions are hardcoded in the shader.
        // When you add real meshes, fill in VkVertexInputBindingDescription
        // and VkVertexInputAttributeDescription here to match your vertex struct.
        var vertex_input = std.mem.zeroes(vk.VkPipelineVertexInputStateCreateInfo);
        vertex_input.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

        // ── Input assembly ────────────────────────────────────────────────────
        // How vertices are grouped into primitives.
        // TRIANGLE_LIST = every 3 vertices = 1 triangle, no sharing.
        // Change to TRIANGLE_STRIP for strip-based geometry if needed.
        var input_assembly = std.mem.zeroes(vk.VkPipelineInputAssemblyStateCreateInfo);
        input_assembly.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        input_assembly.topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
        input_assembly.primitiveRestartEnable = vk.VK_FALSE;

        // ── Viewport and scissor ──────────────────────────────────────────────
        // Viewport = region of the framebuffer to render into. Set to full window.
        // minDepth/maxDepth are the depth range — always 0.0 to 1.0 in Vulkan.
        // Scissor = 2D clipping rectangle. Pixels outside are discarded.
        // This is NOT frustum culling — that is a CPU-side 3D operation.
        // Both set to full window extent for now.
        var viewport = std.mem.zeroes(vk.VkViewport);
        viewport.x = 0.0;
        viewport.y = 0.0;
        viewport.width = @floatFromInt(extent.width);
        viewport.height = @floatFromInt(extent.height);
        viewport.minDepth = 0.0;
        viewport.maxDepth = 1.0;

        var scissor = std.mem.zeroes(vk.VkRect2D);
        scissor.offset = .{ .x = 0, .y = 0 };
        scissor.extent = extent;

        var viewport_state = std.mem.zeroes(vk.VkPipelineViewportStateCreateInfo);
        viewport_state.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        viewport_state.viewportCount = 1;
        viewport_state.pViewports = &viewport;
        viewport_state.scissorCount = 1;
        viewport_state.pScissors = &scissor;

        // ── Rasterizer ────────────────────────────────────────────────────────
        // Converts triangles into fragments for the fragment shader.
        // cullMode = discard back faces. If geometry appears invisible, flip
        // frontFace to COUNTER_CLOCKWISE — winding order depends on your mesh exporter.
        // polygonMode = FILL for solid, LINE for wireframe debug, POINT for points.
        // lineWidth > 1.0 requires the wideLines GPU feature to be enabled.
        var rasterizer = std.mem.zeroes(vk.VkPipelineRasterizationStateCreateInfo);
        rasterizer.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rasterizer.depthClampEnable = vk.VK_FALSE;
        rasterizer.rasterizerDiscardEnable = vk.VK_FALSE;
        rasterizer.polygonMode = vk.VK_POLYGON_MODE_FILL;
        rasterizer.lineWidth = 1.0;
        rasterizer.cullMode = vk.VK_CULL_MODE_BACK_BIT;
        rasterizer.frontFace = vk.VK_FRONT_FACE_CLOCKWISE;
        rasterizer.depthBiasEnable = vk.VK_FALSE;

        // ── Multisampling ─────────────────────────────────────────────────────
        // Anti-aliasing via MSAA. Disabled here — 1 sample per pixel.
        // For anime style you likely want sharp edges anyway so this may
        // stay disabled. If you enable it, also update the render pass
        // attachment sample count to match.
        var multisampling = std.mem.zeroes(vk.VkPipelineMultisampleStateCreateInfo);
        multisampling.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        multisampling.sampleShadingEnable = vk.VK_FALSE;
        multisampling.rasterizationSamples = vk.VK_SAMPLE_COUNT_1_BIT;

        // ── Color blending ────────────────────────────────────────────────────
        // Controls how the fragment shader output blends with what's already
        // in the framebuffer. Disabled = fragment output replaces framebuffer directly.
        // To enable transparency (anime effects, UI) set blendEnable = VK_TRUE
        // and configure srcColorBlendFactor/dstColorBlendFactor for alpha blending.
        var color_blend_attachment = std.mem.zeroes(vk.VkPipelineColorBlendAttachmentState);
        color_blend_attachment.colorWriteMask =
            vk.VK_COLOR_COMPONENT_R_BIT |
            vk.VK_COLOR_COMPONENT_G_BIT |
            vk.VK_COLOR_COMPONENT_B_BIT |
            vk.VK_COLOR_COMPONENT_A_BIT;
        color_blend_attachment.blendEnable = vk.VK_FALSE;

        var color_blending = std.mem.zeroes(vk.VkPipelineColorBlendStateCreateInfo);
        color_blending.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        color_blending.logicOpEnable = vk.VK_FALSE;
        color_blending.attachmentCount = 1;
        color_blending.pAttachments = &color_blend_attachment;

        // ── Pipeline layout ───────────────────────────────────────────────────
        // Defines what resources the shaders can access — empty for now.
        // When you add real rendering you'll add:
        //   - Push constants: per-object transform matrices (model/view/projection)
        //   - Descriptor sets: textures, uniform buffers, toon ramp lookup tables
        var layout_ci = std.mem.zeroes(vk.VkPipelineLayoutCreateInfo);
        layout_ci.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;

        const layout_result = vk.vkCreatePipelineLayout(device, &layout_ci, null, &self._pipeline_layout);
        if (layout_result != vk.VK_SUCCESS) {
            std.debug.panic("Failed to create pipeline layout", .{});
        }

        // ── Graphics pipeline ─────────────────────────────────────────────────
        // Assembles all stages above into one immutable GPU object.
        // Immutable means you cannot change it after creation — for different
        // render modes (outline pass, shadow pass) create separate pipelines.
        // subpass = which subpass of the render pass this pipeline belongs to.
        var pipeline_ci = std.mem.zeroes(vk.VkGraphicsPipelineCreateInfo);
        pipeline_ci.sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        pipeline_ci.stageCount = 2;
        pipeline_ci.pStages = &shader_stages;
        pipeline_ci.pVertexInputState = &vertex_input;
        pipeline_ci.pInputAssemblyState = &input_assembly;
        pipeline_ci.pViewportState = &viewport_state;
        pipeline_ci.pRasterizationState = &rasterizer;
        pipeline_ci.pMultisampleState = &multisampling;
        pipeline_ci.pColorBlendState = &color_blending;
        pipeline_ci.layout = self._pipeline_layout;
        pipeline_ci.renderPass = render_pass;
        pipeline_ci.subpass = 0;

        const result = vk.vkCreateGraphicsPipelines(device, null, 1, &pipeline_ci, null, &self._pipeline);
        if (result != vk.VK_SUCCESS) {
            std.debug.panic("Failed to create graphics pipeline", .{});
        }
    }

    pub fn cleanup(self: *OpenSimPipeline, device: vk.VkDevice) void {
        vk.vkDestroyPipeline(device, self._pipeline, null);
        vk.vkDestroyPipelineLayout(device, self._pipeline_layout, null);
    }
};

// Reads a SPIR-V binary from disk into a heap allocated byte slice.
// Caller owns the memory — defer free after pipeline creation.
fn loadShader(path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(std.heap.page_allocator, 1024 * 1024);
}

// Wraps a SPIR-V byte slice into a VkShaderModule.
// pCode cast is safe here — SPIR-V is defined to be u32 aligned and
// our page_allocator guarantees page alignment which exceeds u32 alignment.
fn createShaderModule(device: vk.VkDevice, code: []u8) vk.VkShaderModule {
    var create_info = std.mem.zeroes(vk.VkShaderModuleCreateInfo);
    create_info.sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    create_info.codeSize = code.len;
    create_info.pCode = @ptrCast(@alignCast(code.ptr));

    var shader_module: vk.VkShaderModule = undefined;
    const result = vk.vkCreateShaderModule(device, &create_info, null, &shader_module);
    if (result != vk.VK_SUCCESS) {
        std.debug.panic("Failed to create shader module", .{});
    }
    return shader_module;
}
