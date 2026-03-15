const std = @import("std");
const vk = @import("../../c.zig").vk;
const BufferErrors = error{ BufferCreationFailed, NoSuitableMemoryType, MemoryAllocationFailed, MemoryBindFailed, MemoryMapFailed };

pub const Buffer = struct {
    handle: vk.VkBuffer,
    memory: vk.VkDeviceMemory,
    size: u32,
    pub fn init(self: *Buffer, device: vk.VkDevice, physical_device: vk.VkPhysicalDevice, size: u32, usage: vk.VkBufferUsageFlags) !void {
        self.size = size;

        var buffer_info = std.mem.zeroes(vk.VkBufferCreateInfo);
        buffer_info.sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        buffer_info.size = size;
        buffer_info.usage = usage;
        buffer_info.sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;

        const result = vk.vkCreateBuffer(device, &buffer_info, null, &self.handle);
        if (result != vk.VK_SUCCESS) {
            return BufferErrors.BufferCreationFailed;
        }

        var mem_req = std.mem.zeroes(vk.VkMemoryRequirements);
        vk.vkGetBufferMemoryRequirements(device, self.handle, &mem_req);

        const memory_type = try findMemoryType(physical_device, mem_req.memoryTypeBits, vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);

        var alloc_info = std.mem.zeroes(vk.VkMemoryAllocateInfo);
        alloc_info.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        alloc_info.allocationSize = mem_req.size;
        alloc_info.memoryTypeIndex = memory_type;
        const alloc_result = vk.vkAllocateMemory(device, &alloc_info, null, &self.memory);
        if (alloc_result != vk.VK_SUCCESS) {
            return BufferErrors.MemoryAllocationFailed;
        }
        const bind_result = vk.vkBindBufferMemory(device, self.handle, self.memory, 0);
        if (bind_result != vk.VK_SUCCESS) {
            return BufferErrors.MemoryBindFailed;
        }
    }

    pub fn upload(self: *Buffer, device: vk.VkDevice, data: []const u8) !void {
        var mapped: ?*anyopaque = null;
        const result = vk.vkMapMemory(device, self.memory, 0, self.size, 0, &mapped);
        if (result != vk.VK_SUCCESS) {
            return BufferErrors.MemoryMapFailed;
        }
        @memcpy(@as([*]u8, @ptrCast(mapped)), data);
        vk.vkUnmapMemory(device, self.memory);
    }

    pub fn deinit(self: *Buffer, device: vk.VkDevice) void {
        vk.vkDestroyBuffer(device, self.handle, null);
        vk.vkFreeMemory(device, self.memory, null);
    }

    fn findMemoryType(physical_device: vk.VkPhysicalDevice, type_filter: u32, properties: vk.VkMemoryPropertyFlags) !u32 {
        var mem_properties = std.mem.zeroes(vk.VkPhysicalDeviceMemoryProperties);
        vk.vkGetPhysicalDeviceMemoryProperties(physical_device, &mem_properties);
        for (mem_properties.memoryTypes[0..mem_properties.memoryTypeCount], 0..) |memory_type, i| {
            if ((type_filter & (@as(u32, 1) << @intCast(i))) != 0 and (memory_type.propertyFlags & properties) == properties) {
                return @intCast(i);
            }
        }
        return BufferErrors.NoSuitableMemoryType;
    }
};
