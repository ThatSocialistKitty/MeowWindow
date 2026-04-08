const std: type = @import("std");
const builtin: type = @import("builtin");
const meowUtilities: type = @import("MeowUtilities");
const vulkan: type = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cInclude("vulkan/vulkan_wayland.h");
    @cInclude("X11/Xlib.h");
    @cInclude("vulkan/vulkan_xlib.h");
    
    if (builtin.target.os.tag == .windows) {
        @cInclude("vulkan/vulkan_win32.h");
    }
    
    @cInclude("vulkan/vulkan_metal.h");
});
const stdC: type = @cImport({
    @cInclude("string.h");
});

// TODO: Get rid of later :3
var rotation: f32 = 0;

const maxFramesInFlight: u32 = 2;

pub const TextureId: type = u32;

const Texture: type = struct {
    id: TextureId,
    albedo: u32,
    albedoFactor: ?[3]f32 = null,
    orm: ?u32 = null,
    ambientOcclusionFactor: ?f32 = null,
    roughnessFactor: ?f32 = null,
    metallicFactor: ?f32 = null,
    normal: ?u32 = null,
    normalFactor: ?f32 = null,
    height: ?u32 = null,
    opacity: ?u32 = null,
    opacityFactor: ?f32 = null,
    emissive: ?u32 = null,
    emissiveFactor: ?[3]f32 = null,
    alphaMode: ?u8 = null,
    alphaCutoff: ?f32 = null
};

const TextureCreateInformation: type = struct {
    albedo: *meowUtilities.miscellaneous.Image,
    ambientOcclusion: ?*meowUtilities.miscellaneous.Image = null,
    roughness: ?*meowUtilities.miscellaneous.Image = null,
    metallic: ?*meowUtilities.miscellaneous.Image = null,
    normal: ?*meowUtilities.miscellaneous.Image = null,
    height: ?*meowUtilities.miscellaneous.Image = null,
    opacity: ?*meowUtilities.miscellaneous.Image = null,
    emission: ?*meowUtilities.miscellaneous.Image = null
};

pub const Context: type = opaque {
    const VulkanTextureId: type = TextureId;
    
    const VulkanTexture: type = struct {
        id: VulkanTextureId,
        image: vulkan.VkImage,
        deviceMemory: vulkan.VkDeviceMemory,
        imageView: vulkan.VkImageView
    };
    
    const Vertex: type = struct {
        position: [3]f32,
        // normal: [3]f32,
        uv: [2]f32,
        // tangent: [4]f32
    };
    
    const Implementation: type = struct {
        allocator: std.mem.Allocator,
        instance: vulkan.VkInstance,
        debugMessenger: vulkan.VkDebugUtilsMessengerEXT,
        surface: vulkan.VkSurfaceKHR,
        physicalDeviceProperties: vulkan.VkPhysicalDeviceProperties,
        physicalDeviceFeatures: vulkan.VkPhysicalDeviceFeatures,
        physicalDeviceQueueFamilyIndex: u32,
        physicalDeviceGraphicsQueue: vulkan.VkQueue,
        physicalDevicePresentQueue: vulkan.VkQueue,
        graphicsPipelineSwapchainCreated: bool,
        physicalDeviceSurfaceCapabilities: vulkan.VkSurfaceCapabilitiesKHR,
        physicalDeviceSurfaceFormats: []vulkan.VkSurfaceFormatKHR,
        physicalDeviceSurfacePresentModes: []vulkan.VkPresentModeKHR,
        physicalDevice: vulkan.VkPhysicalDevice,
        device: vulkan.VkDevice,
        physicalDeviceSurfaceFormat: vulkan.VkSurfaceFormatKHR,
        physicalDeviceSurfacePresentMode: vulkan.VkPresentModeKHR,
        graphicsPipelineViewport: vulkan.VkViewport,
        graphicsPipelineScissor: vulkan.VkRect2D,
        graphicsPipelineDescriptorSetLayout: vulkan.VkDescriptorSetLayout,
        graphicsPipelineLayout: vulkan.VkPipelineLayout,
        graphicsPipelineRenderPass: vulkan.VkRenderPass,
        graphicsPipeline: vulkan.VkPipeline,
        graphicsPipelineSwapchain: vulkan.VkSwapchainKHR,
        graphicsPipelineSwapchainImages: []vulkan.VkImage,
        graphicsPipelineSwapchainImageViews: []vulkan.VkImageView,
        graphicsPipelineSwapchainFramebuffers: []vulkan.VkFramebuffer,
        graphicsPipelineCommandPool: vulkan.VkCommandPool,
        graphicsPipelineCommandBuffers: []vulkan.VkCommandBuffer,
        graphicsPipelineTextureImageSampler: vulkan.VkSampler,
        graphicsPipelineCurrentTextureId: VulkanTextureId,
        graphicsPipelineCurrentVulkanTextureId: VulkanTextureId,
        graphicsPipelineTextures: std.ArrayList(VulkanTexture),
        graphicsPipelineVertexBufferData: std.ArrayList(Vertex),
        graphicsPipelineVertexBuffer: vulkan.VkBuffer,
        graphicsPipelineVertexBufferDeviceMemory: vulkan.VkDeviceMemory,
        graphicsPipelineIndexBufferData: std.ArrayList(u16),
        graphicsPipelineIndexBuffer: vulkan.VkBuffer,
        graphicsPipelineIndexBufferDeviceMemory: vulkan.VkDeviceMemory,
        graphicsPipelineUniformBuffers: []vulkan.VkBuffer,
        graphicsPipelineUniformBufferDeviceMemories: []vulkan.VkDeviceMemory,
        graphicsPipelineUniformBufferMapped: []?*anyopaque,
        graphicsPipelineDescriptorPool: vulkan.VkDescriptorPool,
        graphicsPipelineDescriptorSets: []vulkan.VkDescriptorSet,
        graphicsPipelineCurrentFrame: u32,
        graphicsPipelineImageAvailableSemaphores: []vulkan.VkSemaphore,
        graphicsPipelineRenderFinishedSemaphores: []vulkan.VkSemaphore,
        graphicsPipelineInFlightFences: []vulkan.VkFence,
        graphicsPipelinePreviousRenderEndTimestamp: meowUtilities.time.Timestamp,
        graphicsPipelineDeltaTime: f32
    };
    
    fn debugMessengerCallback(messageSeverity: vulkan.VkDebugUtilsMessageSeverityFlagBitsEXT,messageType: vulkan.VkDebugUtilsMessageTypeFlagsEXT,callbackData: [*c]const vulkan.VkDebugUtilsMessengerCallbackDataEXT,userData: ?*anyopaque) callconv(.c) vulkan.VkBool32 {
        const logSeverityLevel: std.log.Level = switch (messageSeverity) {
            vulkan.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT,vulkan.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => std.log.Level.debug,
            vulkan.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => std.log.Level.warn,
            vulkan.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => std.log.Level.err,
            else => unreachable
        };
        
        meowUtilities.log.print(logSeverityLevel,"Validation layer: {s}",.{callbackData.*.pMessage});
        
        _ = messageType;
        _ = userData;
        
        return vulkan.VK_FALSE;
    }
    
    fn createShaderModule(context: *Implementation,code: []const u8) !vulkan.VkShaderModule {
        const shaderModuleCreateInformation: vulkan.VkShaderModuleCreateInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .pCode = @ptrCast(@alignCast(code)),
            .codeSize = code.len
        };
        
        var shaderModule: vulkan.VkShaderModule = undefined;
        
        if (vulkan.vkCreateShaderModule(context.device,&shaderModuleCreateInformation,null,@ptrCast(&shaderModule)) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        
        return shaderModule;
    }
    
    fn createShaderModuleFromFile(context: *Implementation,path: []const u8) !vulkan.VkShaderModule {
        var selfDirectory: std.fs.Dir = try meowUtilities.fileSystem.openSelfDirectory(.{});
        defer selfDirectory.close();
        
        const file: std.fs.File = try selfDirectory.openFile(path,.{
            .mode = .read_only
        });
        defer file.close();
        
        const contents: []const u8 = try file.readToEndAlloc(context.allocator,std.math.maxInt(usize));
        
        return try createShaderModule(context,contents);
    }
    
    fn selectMemoryType(context: *Implementation,memoryType: u32,properties: vulkan.VkMemoryPropertyFlags) !u32 {
        var memoryProperties: vulkan.VkPhysicalDeviceMemoryProperties = .{};
        vulkan.vkGetPhysicalDeviceMemoryProperties(context.physicalDevice,&memoryProperties);
        
        for (0..memoryProperties.memoryTypeCount) |index| {
            if ((memoryType & (@as(u32,@intCast(1)) << @intCast(index))) > 0 and (memoryProperties.memoryTypes[index].propertyFlags & properties) == properties) {
                return @intCast(index);
            }
        }
        
        return error.UnknownMemoryType;
    }
    
    fn createBuffer(context: *Implementation,sourceBufferLength: usize,usage: vulkan.VkBufferUsageFlags,properties: vulkan.VkMemoryPropertyFlags,buffer: *vulkan.VkBuffer,deviceMemory: *vulkan.VkDeviceMemory) !void {
        const bufferCreateInformation: vulkan.VkBufferCreateInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = sourceBufferLength,
            .usage = usage,
            .sharingMode = vulkan.VK_SHARING_MODE_EXCLUSIVE
        };
        
        if (vulkan.vkCreateBuffer(context.device,&bufferCreateInformation,null,@ptrCast(@alignCast(buffer))) != vulkan.VK_SUCCESS) return error.BufferCreationFailure;
        
        var memoryRequirements: vulkan.VkMemoryRequirements = .{};
        vulkan.vkGetBufferMemoryRequirements(context.device,buffer.*,&memoryRequirements);
        
        const memoryAllocateInformation: vulkan.VkMemoryAllocateInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = memoryRequirements.size,
            .memoryTypeIndex = try selectMemoryType(context,memoryRequirements.memoryTypeBits,properties)
        };
        
        if (vulkan.vkAllocateMemory(context.device,&memoryAllocateInformation,null,@ptrCast(@alignCast(deviceMemory))) != vulkan.VK_SUCCESS) return error.MemoryAllocationFailure;
        
        if (vulkan.vkBindBufferMemory(context.device,buffer.*,deviceMemory.*,0) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
    }
    
    fn allocateCommandBuffer(context: *Implementation) !vulkan.VkCommandBuffer {
        const commandBufferAllocateInformation: vulkan.VkCommandBufferAllocateInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .level = vulkan.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandPool = context.graphicsPipelineCommandPool,
            .commandBufferCount = 1
        };
        
        var commandBuffer: vulkan.VkCommandBuffer = undefined;
        if (vulkan.vkAllocateCommandBuffers(context.device,&commandBufferAllocateInformation,&commandBuffer) != vulkan.VK_SUCCESS) return error.FailedToAllocateCommandBuffer;
        
        const beginInfo: vulkan.VkCommandBufferBeginInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = vulkan.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
        };
        
        if (vulkan.vkBeginCommandBuffer(commandBuffer,&beginInfo) != vulkan.VK_SUCCESS) return error.FailedToBeginCommandBuffer;
        
        return commandBuffer;
    }
    
    fn deallocateCommandBuffer(context: *Implementation,commandBuffer: vulkan.VkCommandBuffer) !void {
        if (vulkan.vkEndCommandBuffer(commandBuffer) != vulkan.VK_SUCCESS) return error.FailedToEndCommandBuffer;
        
        const submitInformation: vulkan.VkSubmitInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .pCommandBuffers = &commandBuffer,
            .commandBufferCount = 1
        };
        
        if (vulkan.vkQueueSubmit(context.physicalDeviceGraphicsQueue,1,&submitInformation,null) != vulkan.VK_SUCCESS) return error.QueueSubmissionFailure;
        
        if (vulkan.vkQueueWaitIdle(context.physicalDeviceGraphicsQueue) != vulkan.VK_SUCCESS) return error.FailedToWaitForIdleQueue;
        
        vulkan.vkFreeCommandBuffers(
            context.device,
            context.graphicsPipelineCommandPool,
            1,
            &commandBuffer
        );
    }
    
    fn copyBuffer(context: *Implementation,sourceBuffer: vulkan.VkBuffer,destinationBuffer: vulkan.VkBuffer,bufferSize: vulkan.VkDeviceSize) !void {
        const commandBuffer: vulkan.VkCommandBuffer = try allocateCommandBuffer(context);
        
        const bufferCopy: vulkan.VkBufferCopy = .{
            .srcOffset = 0,
            .dstOffset = 0,
            .size = bufferSize
        };
        
        vulkan.vkCmdCopyBuffer(commandBuffer,sourceBuffer,destinationBuffer,1,&bufferCopy);
        
        try deallocateCommandBuffer(context,commandBuffer);
    }
    
    fn copyWithStagingBuffer(context: *Implementation,buffer: vulkan.VkBuffer,T: type,data: []const T) !void {
        const bufferSize: vulkan.VkDeviceSize = data.len * @sizeOf(T);
        
        var stagingBuffer: vulkan.VkBuffer = undefined;
        var stagingBufferDeviceMemory: vulkan.VkDeviceMemory = undefined;
        
        try createBuffer(context,bufferSize,vulkan.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,vulkan.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vulkan.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,&stagingBuffer,&stagingBufferDeviceMemory);
        
        // Copy data to staging buffer
        {
            var stagingBufferData: ?*anyopaque = null;
            
            if (vulkan.vkMapMemory(context.device,stagingBufferDeviceMemory,0,bufferSize,0,&stagingBufferData) != vulkan.VK_SUCCESS) return error.MemoryMappingFailure;
            
            _ = stdC.memcpy(stagingBufferData,@ptrCast(data.ptr),bufferSize);
            
            vulkan.vkUnmapMemory(context.device,stagingBufferDeviceMemory);
        }
        
        try copyBuffer(context,stagingBuffer,buffer,bufferSize);
        
        vulkan.vkDestroyBuffer(context.device,stagingBuffer,null);
        vulkan.vkFreeMemory(context.device,stagingBufferDeviceMemory,null);
    }
    
    fn transitionImageLayout(context: *Implementation,image: vulkan.VkImage,format: vulkan.VkFormat,oldLayout: vulkan.VkImageLayout,newLayout: vulkan.VkImageLayout) !void {
        const commandBuffer: vulkan.VkCommandBuffer = try allocateCommandBuffer(context);
        
        var imageMemoryBarrier: vulkan.VkImageMemoryBarrier = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            .oldLayout = oldLayout,
            .newLayout = newLayout,
            .srcQueueFamilyIndex = vulkan.VK_QUEUE_FAMILY_IGNORED,
            .dstQueueFamilyIndex = vulkan.VK_QUEUE_FAMILY_IGNORED,
            .image = image,
            .subresourceRange = .{
                .aspectMask = getValue: {
                    if (format == vulkan.VK_FORMAT_D32_SFLOAT or format == vulkan.VK_FORMAT_D32_SFLOAT_S8_UINT or format == vulkan.VK_FORMAT_D24_UNORM_S8_UINT) {
                        var mask: vulkan.VkImageAspectFlags = vulkan.VK_IMAGE_ASPECT_DEPTH_BIT;
                        
                        if (format == vulkan.VK_FORMAT_D32_SFLOAT_S8_UINT or format == vulkan.VK_FORMAT_D24_UNORM_S8_UINT) {
                            mask |= vulkan.VK_IMAGE_ASPECT_STENCIL_BIT;
                        }
                        
                        break :getValue mask;
                    } else {
                        break :getValue vulkan.VK_IMAGE_ASPECT_COLOR_BIT;
                    }
                },
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1
            },
            .srcAccessMask = 0,
            .dstAccessMask = 0
        };
        
        var sourceStageMask: vulkan.VkPipelineStageFlags = undefined;
        var destinationStageMask: vulkan.VkPipelineStageFlags = undefined;
        
        if (oldLayout == vulkan.VK_IMAGE_LAYOUT_UNDEFINED and newLayout == vulkan.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
            imageMemoryBarrier.srcAccessMask = 0;
            imageMemoryBarrier.dstAccessMask = vulkan.VK_ACCESS_TRANSFER_WRITE_BIT;
            
            sourceStageMask = vulkan.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
            destinationStageMask = vulkan.VK_PIPELINE_STAGE_TRANSFER_BIT;
        } else if (oldLayout == vulkan.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and newLayout == vulkan.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
            imageMemoryBarrier.srcAccessMask = vulkan.VK_ACCESS_TRANSFER_WRITE_BIT;
            imageMemoryBarrier.dstAccessMask = vulkan.VK_ACCESS_SHADER_READ_BIT;
            
            sourceStageMask = vulkan.VK_PIPELINE_STAGE_TRANSFER_BIT;
            destinationStageMask = vulkan.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
        } else {
            return error.UnsupportedLayoutTransition;
        }
        
        vulkan.vkCmdPipelineBarrier(
            commandBuffer,
            sourceStageMask,
            destinationStageMask,
            0,
            0,
            null,
            0,
            null,
            1,
            &imageMemoryBarrier,
        );
        
        try deallocateCommandBuffer(context,commandBuffer);
    }
    
    fn copyBufferToImage(context: *Implementation,buffer: vulkan.VkBuffer,image: vulkan.VkImage,width: u32,height: u32) !void {
        const commandBuffer: vulkan.VkCommandBuffer = try allocateCommandBuffer(context);
        
        const bufferImageCopy: vulkan.VkBufferImageCopy = .{
            .bufferOffset = 0,
            .bufferRowLength = 0,
            .bufferImageHeight = 0,
            .imageSubresource = .{
                .aspectMask = vulkan.VK_IMAGE_ASPECT_COLOR_BIT,
                .mipLevel = 0,
                .baseArrayLayer = 0,
                .layerCount = 1
            },
            .imageOffset = .{
                .x = 0,
                .y = 0,
                .z = 0
            },
            .imageExtent = .{
                .width = width,
                .height = height,
                .depth = 1
            }
        };
        
        vulkan.vkCmdCopyBufferToImage(
            commandBuffer,
            buffer,
            image,
            vulkan.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            &bufferImageCopy
        );
        
        try deallocateCommandBuffer(context,commandBuffer);
    }
    
    fn createVulkanTexture(context: *Implementation,image: *meowUtilities.miscellaneous.Image) !VulkanTextureId {
        var texture: VulkanTexture = undefined;
        
        texture.id = context.graphicsPipelineCurrentVulkanTextureId;
        defer context.graphicsPipelineCurrentVulkanTextureId += 1;
        
        const imageMetadata: meowUtilities.miscellaneous.Image.Metadata = image.getMetadata();
        
        // Create and transition image
        {
            var stagingBuffer: vulkan.VkBuffer = undefined;
            var stagingBufferDeviceMemory: vulkan.VkDeviceMemory = undefined;
            
            try createBuffer(context,imageMetadata.size,vulkan.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,vulkan.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vulkan.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,&stagingBuffer,&stagingBufferDeviceMemory);
            
            // Copy data to staging buffer
            {
                var stagingBufferData: ?*anyopaque = null;
                
                if (vulkan.vkMapMemory(context.device,stagingBufferDeviceMemory,0,imageMetadata.size,0,&stagingBufferData) != vulkan.VK_SUCCESS) return error.MemoryMappingFailure;
                
                _ = stdC.memcpy(stagingBufferData,@ptrCast(image.getPixels().ptr),imageMetadata.size);
                
                vulkan.vkUnmapMemory(context.device,stagingBufferDeviceMemory);
            }
            
            const imageCreateInformation: vulkan.VkImageCreateInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
                .imageType = vulkan.VK_IMAGE_TYPE_2D,
                .extent = .{
                    .width = imageMetadata.dimensions[0],
                    .height = imageMetadata.dimensions[1],
                    .depth = 1
                },
                .mipLevels = 1,
                .arrayLayers = 1,
                .format = vulkan.VK_FORMAT_R8G8B8A8_SRGB,
                .tiling = vulkan.VK_IMAGE_TILING_OPTIMAL,
                .initialLayout = vulkan.VK_IMAGE_LAYOUT_UNDEFINED,
                .usage = vulkan.VK_IMAGE_USAGE_TRANSFER_DST_BIT | vulkan.VK_IMAGE_USAGE_SAMPLED_BIT,
                .samples = vulkan.VK_SAMPLE_COUNT_1_BIT,
                .sharingMode = vulkan.VK_SHARING_MODE_EXCLUSIVE,
                // .flags = vulkan.VK_IMAGE_CREATE_SPARSE_BINDING_BIT TODO: Sparse textures :D
            };
            
            if (vulkan.vkCreateImage(context.device,&imageCreateInformation,null,&texture.image) != vulkan.VK_SUCCESS) return error.ImageCreationFailure;
            
            var memoryRequirements: vulkan.VkMemoryRequirements = .{};
            vulkan.vkGetImageMemoryRequirements(context.device,texture.image,&memoryRequirements);
            
            const memoryAllocateInformation: vulkan.VkMemoryAllocateInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
                .allocationSize = memoryRequirements.size,
                .memoryTypeIndex = try selectMemoryType(context,memoryRequirements.memoryTypeBits,vulkan.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
            };
            
            if (vulkan.vkAllocateMemory(context.device,&memoryAllocateInformation,null,&texture.deviceMemory) != vulkan.VK_SUCCESS) return error.DeviceMemoryAllicationFailure;
            
            if (vulkan.vkBindImageMemory(context.device,texture.image,texture.deviceMemory,0) != vulkan.VK_SUCCESS) return error.FailedToBindImageMemory;
            
            try transitionImageLayout(context,texture.image,vulkan.VK_FORMAT_R8G8B8A8_SRGB,vulkan.VK_IMAGE_LAYOUT_UNDEFINED,vulkan.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);
            
            try copyBufferToImage(context,stagingBuffer,texture.image,imageMetadata.dimensions[0],imageMetadata.dimensions[1]);
            
            try transitionImageLayout(context,texture.image,vulkan.VK_FORMAT_R8G8B8A8_SRGB,vulkan.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,vulkan.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
        }
        
        // Create image view
        {
            var imageViewCreateInformation: vulkan.VkImageViewCreateInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = texture.image,
                .viewType = vulkan.VK_IMAGE_VIEW_TYPE_2D,
                .format = vulkan.VK_FORMAT_R8G8B8A8_SRGB,
                .subresourceRange = .{
                    .aspectMask = vulkan.VK_IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1
                }
            };
            
            if (vulkan.vkCreateImageView(context.device,&imageViewCreateInformation,null,&texture.imageView) != vulkan.VK_SUCCESS) return error.FailedToCreateImageView;
        }
        
        // Update descriptor sets
        {
            for (0..maxFramesInFlight) |index| {
                const writeDescriptorSets: []const vulkan.VkWriteDescriptorSet = &.{
                    .{
                        .sType = vulkan.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                        .descriptorType = vulkan.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                        .dstSet = context.graphicsPipelineDescriptorSets[index],
                        .dstBinding = 0,
                        .dstArrayElement = 0,
                        .descriptorCount = 1,
                        .pBufferInfo = &vulkan.VkDescriptorBufferInfo {
                            .buffer = context.graphicsPipelineUniformBuffers[index],
                            .offset = 0,
                            .range = @sizeOf(UniformBufferObject)
                        },
                        .pImageInfo = null,
                        .pTexelBufferView = null
                    },
                    .{
                        .sType = vulkan.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                        .descriptorType = vulkan.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                        .dstSet = context.graphicsPipelineDescriptorSets[index],
                        .dstBinding = 1,
                        .dstArrayElement = 0,
                        .descriptorCount = 1,
                        .pImageInfo = &vulkan.VkDescriptorImageInfo {
                            .imageLayout = vulkan.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                            .imageView = texture.imageView,
                            .sampler = context.graphicsPipelineTextureImageSampler
                        },
                        .pBufferInfo = null,
                        .pTexelBufferView = null
                    }
                };
                
                vulkan.vkUpdateDescriptorSets(context.device,@intCast(writeDescriptorSets.len),@ptrCast(writeDescriptorSets.ptr),0,null);
            }
        }
        
        context.graphicsPipelineTextures.append(context.allocator,texture) catch unreachable;
        
        return texture.id;
    }
    
    fn createTexture(context: *Implementation,textureCreateInformation: TextureCreateInformation) !Texture {
        defer textureCreateInformation.albedo.destroy();
        
        defer context.graphicsPipelineCurrentTextureId += 1;
        
        return .{
            .id = context.graphicsPipelineCurrentTextureId,
            .albedo = try createVulkanTexture(context,textureCreateInformation.albedo)
        };
    }
    
    fn appendModel(context: *Implementation,vertices: []const Vertex,indices: []const u16,textureCreateInformation: ?TextureCreateInformation) !void {
        context.graphicsPipelineVertexBufferData.appendSlice(context.allocator,vertices) catch unreachable;
        try copyWithStagingBuffer(context,context.graphicsPipelineVertexBuffer,Vertex,context.graphicsPipelineVertexBufferData.items);
        
        context.graphicsPipelineIndexBufferData.appendSlice(context.allocator,indices) catch unreachable;
        try copyWithStagingBuffer(context,context.graphicsPipelineIndexBuffer,u16,context.graphicsPipelineIndexBufferData.items);
        
        if (textureCreateInformation != null) {
            _ = try createTexture(context,textureCreateInformation.?);
        }
    }
    
    pub const CreationError: type = error {
        ObjectRetrievalFailure,
        FileSystemFailure,
        ModelCreationFailure,
        BufferCreationFailure
    };
    
    pub const WaylandWindowHandles: type = struct {
        display: *anyopaque,
        surface: *anyopaque
    };
    
    const UniformBufferObject: type = struct {
        model: meowUtilities.math.Matrix(4,4),
        view: meowUtilities.math.Matrix(4,4),
        projection: meowUtilities.math.Matrix(4,4)
    };
    
    pub fn create(allocator: std.mem.Allocator,windowHandles: *anyopaque,platform: @Type(.enum_literal),imageSize: [2]i32) CreationError!*Context {
        const context: *Implementation = allocator.create(Implementation) catch unreachable;
        
        const methods: *Context = @ptrCast(context);
        
        errdefer methods.destroy();
        
        context.allocator = allocator;
        
        const layerNames: []const [*:0]const u8 = &.{
            "VK_LAYER_KHRONOS_validation"
        };
        
        // Create instance
        {
            const instanceExtensionNames: []const [*:0]const u8 = comptime getValue: {
                var value: []const [*:0]const u8 = &.{
                    vulkan.VK_KHR_SURFACE_EXTENSION_NAME
                };
                
                value = value ++ switch (builtin.target.os.tag) {
                    .linux => .{vulkan.VK_KHR_WAYLAND_SURFACE_EXTENSION_NAME,vulkan.VK_KHR_XLIB_SURFACE_EXTENSION_NAME},
                    .windows => .{vulkan.VK_KHR_WIN32_SURFACE_EXTENSION_NAME},
                    .macos => .{vulkan.VK_EXT_METAL_SURFACE_EXTENSION_NAME},
                    else => unreachable
                };
                
                if (builtin.mode == .Debug) {
                    value = value ++ .{vulkan.VK_EXT_DEBUG_UTILS_EXTENSION_NAME};
                }
                
                break :getValue value;
            };
            
            const applicationInformation: vulkan.VkApplicationInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_APPLICATION_INFO,
                .apiVersion = vulkan.VK_API_VERSION_1_4
            };
            
            const instanceCreateInformation: vulkan.VkInstanceCreateInfo = comptime getValue: {
                var value: vulkan.VkInstanceCreateInfo = .{
                    .sType = vulkan.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                    .pApplicationInfo = &applicationInformation,
                    .ppEnabledExtensionNames = @ptrCast(instanceExtensionNames.ptr),
                    .enabledExtensionCount = @intCast(instanceExtensionNames.len)
                };
                
                if (builtin.mode == .Debug) {
                    value.ppEnabledLayerNames = @ptrCast(layerNames.ptr);
                    value.enabledLayerCount = @intCast(layerNames.len);
                    
                    const validationFeatureExtensionEnables: []const vulkan.VkValidationFeatureEnableEXT = &.{
                        vulkan.VK_VALIDATION_FEATURE_ENABLE_DEBUG_PRINTF_EXT
                    };
                    
                    value.pNext = &vulkan.VkValidationFeaturesEXT {
                        .sType = vulkan.VK_STRUCTURE_TYPE_VALIDATION_FEATURES_EXT,
                        .pEnabledValidationFeatures = @ptrCast(validationFeatureExtensionEnables.ptr),
                        .enabledValidationFeatureCount = @intCast(validationFeatureExtensionEnables.len),
                        .pNext = &vulkan.VkDebugUtilsMessengerCreateInfoEXT {
                            .sType = vulkan.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
                            .messageSeverity = vulkan.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT | vulkan.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | vulkan.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT | vulkan.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT,
                            .messageType = vulkan.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | vulkan.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | vulkan.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
                            .pfnUserCallback = debugMessengerCallback
                        }
                    };
                }
                
                break :getValue value;
            };
            
            if (vulkan.vkCreateInstance(&instanceCreateInformation,null,&context.instance) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        }
        
        // Create surface
        {
            switch (platform) {
                .Wayland => {
                    const handles: *WaylandWindowHandles = @ptrCast(@alignCast(windowHandles));
                    
                    const createInformation: vulkan.VkWaylandSurfaceCreateInfoKHR = .{
                        .sType = vulkan.VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR,
                        .display = @ptrCast(handles.display),
                        .surface = @ptrCast(handles.surface)
                    };
                    
                    if (vulkan.vkCreateWaylandSurfaceKHR(context.instance,&createInformation,null,&context.surface) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
                },
                else => unreachable
            }
        }
        
        // Select physical device, create logical device, and create graphics queue
        {
            var physicalDeviceCount: u32 = 0;
            
            if (vulkan.vkEnumeratePhysicalDevices(context.instance,&physicalDeviceCount,null) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            
            const physicalDevices: []vulkan.VkPhysicalDevice = context.allocator.alloc(vulkan.VkPhysicalDevice,physicalDeviceCount) catch unreachable;
            defer context.allocator.free(physicalDevices);
            
            if (vulkan.vkEnumeratePhysicalDevices(context.instance,&physicalDeviceCount,@ptrCast(physicalDevices.ptr)) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            
            var finalPhysicalDevice: vulkan.VkPhysicalDevice = undefined;
            var finalPhysicalDeviceProperties: vulkan.VkPhysicalDeviceProperties = undefined;
            var finalPhysicalDeviceFeatures: vulkan.VkPhysicalDeviceFeatures = undefined;
            
            var finalPhysicalDeviceQueueFamilyIndex: u32 = 0;
            
            var finalPhysicalDeviceSurfaceCapabilities: vulkan.VkSurfaceCapabilitiesKHR = undefined;
            var finalPhysicalDeviceSurfaceFormats: []vulkan.VkSurfaceFormatKHR = undefined;
            var finalPhysicalDeviceSurfacePresentModes: []vulkan.VkPresentModeKHR = undefined;
            
            for (physicalDevices) |physicalDevice| {
                var properties: vulkan.VkPhysicalDeviceProperties = undefined;
                vulkan.vkGetPhysicalDeviceProperties(physicalDevice,&properties);
                
                var features: vulkan.VkPhysicalDeviceFeatures = undefined;
                vulkan.vkGetPhysicalDeviceFeatures(physicalDevice,&features);
                
                var queueFamilyRequirements: struct {
                    graphics: bool = false,
                    present: bool = false
                } = .{};
                
                var queueFamilyIndex: u32 = 0;
                
                var surfaceCapabilities: vulkan.VkSurfaceCapabilitiesKHR = undefined;
                var surfaceFormats: []vulkan.VkSurfaceFormatKHR = undefined;
                var surfacePresentModes: []vulkan.VkPresentModeKHR = undefined;
                
                // Check for queue famlies and validate if requirements are met
                {
                    var queueFamilyCount: u32 = 0;
                    vulkan.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice,&queueFamilyCount,null);
                    
                    const queueFamilies: []vulkan.VkQueueFamilyProperties = context.allocator.alloc(vulkan.VkQueueFamilyProperties,queueFamilyCount) catch unreachable;
                    defer context.allocator.free(queueFamilies);
                    
                    vulkan.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice,&queueFamilyCount,@ptrCast(queueFamilies.ptr));
                    
                    for (queueFamilies,0..) |queueFamily,queueFamilyIndex1| {
                        queueFamilyIndex = @intCast(queueFamilyIndex1);
                        
                        // Graphics
                        {
                            if (!queueFamilyRequirements.graphics) {
                                if (queueFamily.queueFlags & vulkan.VK_QUEUE_GRAPHICS_BIT != 0) {
                                    queueFamilyRequirements.graphics = true;
                                }
                            }
                        }
                        
                        // Present
                        {
                            if (!queueFamilyRequirements.present) {
                                var presentationSupported: vulkan.VkBool32 = vulkan.VK_FALSE;
                                
                                if (vulkan.vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice,queueFamilyIndex,context.surface,&presentationSupported) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
                                
                                if (presentationSupported == vulkan.VK_TRUE) {
                                    queueFamilyRequirements.present = true;
                                }
                            }
                        }
                        
                        // If requirements are met set formats and present modes
                        {
                            var surfaceFormatCount: u32 = 0;
                            var surfacePresentModeCount: u32 = 0;
                            
                            if (vulkan.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice,context.surface,&surfaceCapabilities) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
                            
                            if (vulkan.vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice,context.surface,&surfaceFormatCount,null) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
                            
                            if (vulkan.vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice,context.surface,&surfacePresentModeCount,null) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
                            
                            if (queueFamilyRequirements.graphics and queueFamilyRequirements.present and surfaceFormatCount > 0 and surfacePresentModeCount > 0) {
                                surfaceFormats = context.allocator.alloc(vulkan.VkSurfaceFormatKHR,surfaceFormatCount) catch unreachable;
                                
                                if (vulkan.vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice,context.surface,&surfaceFormatCount,@ptrCast(surfaceFormats.ptr)) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
                                
                                surfacePresentModes = context.allocator.alloc(vulkan.VkPresentModeKHR,surfacePresentModeCount) catch unreachable;
                                
                                if (vulkan.vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice,context.surface,&surfacePresentModeCount,@ptrCast(surfacePresentModes.ptr)) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
                                
                                break;
                            }
                        }
                    }
                }
                
                if (features.geometryShader == vulkan.VK_TRUE) {
                    finalPhysicalDevice = physicalDevice;
                    finalPhysicalDeviceProperties = properties;
                    finalPhysicalDeviceFeatures = features;
                    finalPhysicalDeviceQueueFamilyIndex = queueFamilyIndex;
                    finalPhysicalDeviceSurfaceCapabilities = surfaceCapabilities;
                    finalPhysicalDeviceSurfaceFormats = surfaceFormats;
                    finalPhysicalDeviceSurfacePresentModes = surfacePresentModes;
                    break;
                }
            }
            
            // Create device and device queues
            {
                context.physicalDevice = finalPhysicalDevice;
                
                context.physicalDeviceProperties = finalPhysicalDeviceProperties;
                context.physicalDeviceFeatures = finalPhysicalDeviceFeatures;
                context.physicalDeviceSurfaceCapabilities = finalPhysicalDeviceSurfaceCapabilities;
                context.physicalDeviceSurfaceFormats = finalPhysicalDeviceSurfaceFormats;
                context.physicalDeviceSurfacePresentModes = finalPhysicalDeviceSurfacePresentModes;
                
                context.physicalDeviceQueueFamilyIndex = finalPhysicalDeviceQueueFamilyIndex;
                
                const deviceExtensionNames: []const [*:0]const u8 = &.{
                    vulkan.VK_KHR_SWAPCHAIN_EXTENSION_NAME
                };
                
                var deviceCreateInformation: vulkan.VkDeviceCreateInfo = vulkan.VkDeviceCreateInfo {
                    .sType = vulkan.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                    .queueCreateInfoCount = 1,
                    .pEnabledFeatures = &finalPhysicalDeviceFeatures,
                    .pQueueCreateInfos = &vulkan.VkDeviceQueueCreateInfo {
                        .sType = vulkan.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                        .queueFamilyIndex = finalPhysicalDeviceQueueFamilyIndex,
                        .queueCount = 1,
                        .pQueuePriorities = &@as(f32,@floatFromInt(1))
                    },
                    .ppEnabledExtensionNames = @ptrCast(deviceExtensionNames.ptr),
                    .enabledExtensionCount = @intCast(deviceExtensionNames.len),
                    .pNext = &vulkan.VkPhysicalDeviceDescriptorIndexingFeatures {
                        .sType = vulkan.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES,
                        .shaderSampledImageArrayNonUniformIndexing = vulkan.VK_TRUE,
                        .runtimeDescriptorArray = vulkan.VK_TRUE,
                        .descriptorBindingVariableDescriptorCount = vulkan.VK_TRUE,
                        .descriptorBindingPartiallyBound = vulkan.VK_TRUE,
                        .descriptorBindingSampledImageUpdateAfterBind = vulkan.VK_TRUE
                    }
                };
                
                if (builtin.mode == .Debug) {
                    deviceCreateInformation.ppEnabledLayerNames = @ptrCast(layerNames.ptr);
                    deviceCreateInformation.enabledLayerCount = @intCast(layerNames.len);
                }
                
                if (vulkan.vkCreateDevice(context.physicalDevice,&deviceCreateInformation,null,&context.device) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
                vulkan.vkGetDeviceQueue(context.device,context.physicalDeviceQueueFamilyIndex,0,&context.physicalDeviceGraphicsQueue);
                vulkan.vkGetDeviceQueue(context.device,context.physicalDeviceQueueFamilyIndex,0,&context.physicalDevicePresentQueue);
            }
        }
        
        const maxTextures: u32 = meowUtilities.math.min(u32,&.{context.physicalDeviceProperties.limits.maxDescriptorSetSampledImages,context.physicalDeviceProperties.limits.maxPerStageDescriptorSampledImages});
        
        // Create graphics pipeline
        {
            // Select surface format
            {
                context.physicalDeviceSurfaceFormat = context.physicalDeviceSurfaceFormats[0];
                
                for (context.physicalDeviceSurfaceFormats) |physicalDeviceSurfaceFormat| {
                    if (physicalDeviceSurfaceFormat.format == vulkan.VK_FORMAT_B8G8R8A8_SRGB and physicalDeviceSurfaceFormat.colorSpace == vulkan.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
                        context.physicalDeviceSurfaceFormat = physicalDeviceSurfaceFormat;
                        break;
                    }
                }
            }
            
            // Select surface present mode
            {
                context.physicalDeviceSurfacePresentMode = vulkan.VK_PRESENT_MODE_FIFO_KHR;
                
                for (context.physicalDeviceSurfacePresentModes) |physicalDeviceSurfacePresentMode| {
                    if (physicalDeviceSurfacePresentMode == vulkan.VK_PRESENT_MODE_MAILBOX_KHR) {
                        context.physicalDeviceSurfacePresentMode = physicalDeviceSurfacePresentMode;
                        break;
                    }
                }
            }
            
            const vertexShaderModule: vulkan.VkShaderModule = createShaderModuleFromFile(context,"shaders/shader.vert.spv") catch return CreationError.FileSystemFailure;
            const fragmentShaderModule: vulkan.VkShaderModule = createShaderModuleFromFile(context,"shaders/shader.frag.spv") catch return CreationError.FileSystemFailure;
            
            const shaderStageCreateInformations: []const vulkan.VkPipelineShaderStageCreateInfo = &.{
                .{
                    .sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    .stage = vulkan.VK_SHADER_STAGE_VERTEX_BIT,
                    .module = vertexShaderModule,
                    .pName = "main"
                },
                .{
                    .sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    .stage = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
                    .module = fragmentShaderModule,
                    .pName = "main"
                }
            };
            
            const vertexInputAttributeDescriptions: []const vulkan.VkVertexInputAttributeDescription = &.{
                .{
                    .binding = 0,
                    .location = 0,
                    .format = vulkan.VK_FORMAT_R32G32B32_SFLOAT,
                    .offset = @offsetOf(Vertex,"position")
                },
                .{
                    .binding = 0,
                    .location = 1,
                    .format = vulkan.VK_FORMAT_R32G32_SFLOAT,
                    .offset = @offsetOf(Vertex,"uv")
                }
            };
            
            context.graphicsPipelineViewport = .{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(context.physicalDeviceSurfaceCapabilities.currentExtent.width),
                .height = @floatFromInt(context.physicalDeviceSurfaceCapabilities.currentExtent.height),
                .minDepth = 0,
                .maxDepth = 1
            };
            
            context.graphicsPipelineScissor = .{
                .offset = .{
                    .x = 0,
                    .y = 0
                },
                .extent = context.physicalDeviceSurfaceCapabilities.currentExtent
            };
            
            // Create descriptor set layout
            {
                const descriptorSetLayoutBindings: []const vulkan.VkDescriptorSetLayoutBinding = &.{
                    .{
                        .descriptorType = vulkan.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                        .stageFlags = vulkan.VK_SHADER_STAGE_VERTEX_BIT,
                        .binding = 0,
                        .descriptorCount = 1
                    },
                    .{
                        .descriptorType = vulkan.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                        .stageFlags = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
                        .binding = 1,
                        .descriptorCount = maxTextures / maxFramesInFlight
                    }
                };
                
                const descriptorSetLayoutCreateInformation: vulkan.VkDescriptorSetLayoutCreateInfo = .{
                    .sType = vulkan.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
                    .pBindings = @ptrCast(descriptorSetLayoutBindings.ptr),
                    .bindingCount = @intCast(descriptorSetLayoutBindings.len),
                    .flags = vulkan.VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT,
                    .pNext = &vulkan.VkDescriptorSetLayoutBindingFlagsCreateInfo {
                        .sType = vulkan.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
                        .bindingCount = @intCast(descriptorSetLayoutBindings.len),
                        .pBindingFlags = &([_]vulkan.VkDescriptorBindingFlags {
                            0,
                            vulkan.VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT | vulkan.VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT | vulkan.VK_DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT
                        })
                    }
                };
                
                if (vulkan.vkCreateDescriptorSetLayout(context.device,&descriptorSetLayoutCreateInformation,null,&context.graphicsPipelineDescriptorSetLayout) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            }
            
            const graphicsPipelineLayoutCreateInformation: vulkan.VkPipelineLayoutCreateInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
                .pPushConstantRanges = &vulkan.VkPushConstantRange {
                    .stageFlags = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
                    .size = @sizeOf(meowUtilities.time.Timestamp)
                },
                .pushConstantRangeCount = 1,
                .pSetLayouts = &context.graphicsPipelineDescriptorSetLayout,
                .setLayoutCount = 1
            };
            
            if (vulkan.vkCreatePipelineLayout(context.device,&graphicsPipelineLayoutCreateInformation,null,&context.graphicsPipelineLayout) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            
            const renderPassCreateInformation: vulkan.VkRenderPassCreateInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
                .pAttachments = &vulkan.VkAttachmentDescription {
                    .format = context.physicalDeviceSurfaceFormat.format,
                    .samples = vulkan.VK_SAMPLE_COUNT_1_BIT,
                    .loadOp = vulkan.VK_ATTACHMENT_LOAD_OP_CLEAR,
                    .storeOp = vulkan.VK_ATTACHMENT_STORE_OP_STORE,
                    .stencilLoadOp = vulkan.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                    .stencilStoreOp = vulkan.VK_ATTACHMENT_STORE_OP_DONT_CARE,
                    .initialLayout = vulkan.VK_IMAGE_LAYOUT_UNDEFINED,
                    .finalLayout = vulkan.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
                },
                .attachmentCount = 1,
                .pSubpasses = &vulkan.VkSubpassDescription {
                    .pipelineBindPoint = vulkan.VK_PIPELINE_BIND_POINT_GRAPHICS,
                    .pColorAttachments = &vulkan.VkAttachmentReference {
                        .attachment = 0,
                        .layout = vulkan.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
                    },
                    .colorAttachmentCount = 1
                },
                .subpassCount = 1,
                .pDependencies = &vulkan.VkSubpassDependency {
                    .srcSubpass = vulkan.VK_SUBPASS_EXTERNAL,
                    .srcStageMask = vulkan.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                    .dstStageMask = vulkan.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                    .dstAccessMask = vulkan.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT
                },
                .dependencyCount = 1
            };
            
            if (vulkan.vkCreateRenderPass(context.device,&renderPassCreateInformation,null,&context.graphicsPipelineRenderPass) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            
            const dynamicStates: []const vulkan.VkDynamicState = &.{vulkan.VK_DYNAMIC_STATE_VIEWPORT,vulkan.VK_DYNAMIC_STATE_SCISSOR};
            
            const graphicsPipelineCreateInformation: vulkan.VkGraphicsPipelineCreateInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
                .pStages = @ptrCast(shaderStageCreateInformations.ptr),
                .stageCount = @intCast(shaderStageCreateInformations.len),
                .pVertexInputState = &vulkan.VkPipelineVertexInputStateCreateInfo {
                    .sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
                    .pVertexBindingDescriptions = &vulkan.VkVertexInputBindingDescription {
                        .binding = 0,
                        .stride = @sizeOf(Vertex),
                        .inputRate = vulkan.VK_VERTEX_INPUT_RATE_VERTEX
                    },
                    .vertexBindingDescriptionCount = 1,
                    .pVertexAttributeDescriptions = @ptrCast(vertexInputAttributeDescriptions.ptr),
                    .vertexAttributeDescriptionCount = @intCast(vertexInputAttributeDescriptions.len)
                },
                .pInputAssemblyState = &vulkan.VkPipelineInputAssemblyStateCreateInfo {
                    .sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
                    .topology = vulkan.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
                    .primitiveRestartEnable = vulkan.VK_FALSE
                },
                .pViewportState = &vulkan.VkPipelineViewportStateCreateInfo {
                    .sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
                    .pViewports = &context.graphicsPipelineViewport,
                    .viewportCount = 1,
                    .pScissors = &context.graphicsPipelineScissor,
                    .scissorCount = 1
                },
                .pRasterizationState = &vulkan.VkPipelineRasterizationStateCreateInfo {
                    .sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
                    .depthClampEnable = vulkan.VK_FALSE,
                    .rasterizerDiscardEnable = vulkan.VK_FALSE,
                    .polygonMode = vulkan.VK_POLYGON_MODE_FILL,
                    .cullMode = vulkan.VK_CULL_MODE_BACK_BIT,
                    .frontFace = vulkan.VK_FRONT_FACE_CLOCKWISE,
                    .depthBiasEnable = vulkan.VK_FALSE,
                    .lineWidth = 1
                },
                .pMultisampleState = &vulkan.VkPipelineMultisampleStateCreateInfo {
                    .sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
                    .sampleShadingEnable = vulkan.VK_FALSE,
                    .rasterizationSamples = vulkan.VK_SAMPLE_COUNT_1_BIT,
                    .minSampleShading = 1,
                    .alphaToCoverageEnable = vulkan.VK_FALSE,
                    .alphaToOneEnable = vulkan.VK_FALSE
                },
                .pColorBlendState = &vulkan.VkPipelineColorBlendStateCreateInfo {
                    .sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
                    .logicOpEnable = vulkan.VK_FALSE,
                    .logicOp = vulkan.VK_LOGIC_OP_COPY,
                    .pAttachments = &vulkan.VkPipelineColorBlendAttachmentState {
                        .blendEnable = vulkan.VK_FALSE,
                        .srcColorBlendFactor = vulkan.VK_BLEND_FACTOR_ONE,
                        .dstColorBlendFactor = vulkan.VK_BLEND_FACTOR_ZERO,
                        .colorBlendOp = vulkan.VK_BLEND_OP_ADD,
                        .srcAlphaBlendFactor = vulkan.VK_BLEND_FACTOR_ONE,
                        .dstAlphaBlendFactor = vulkan.VK_BLEND_FACTOR_ZERO,
                        .alphaBlendOp = vulkan.VK_BLEND_OP_ADD,
                        .colorWriteMask = vulkan.VK_COLOR_COMPONENT_R_BIT | vulkan.VK_COLOR_COMPONENT_G_BIT | vulkan.VK_COLOR_COMPONENT_B_BIT | vulkan.VK_COLOR_COMPONENT_A_BIT
                    },
                    .attachmentCount = 1,
                    .blendConstants = .{0,0,0,0}
                },
                .pDynamicState = &vulkan.VkPipelineDynamicStateCreateInfo {
                    .sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
                    .pDynamicStates = @ptrCast(dynamicStates.ptr),
                    .dynamicStateCount = @intCast(dynamicStates.len)
                },
                .renderPass = context.graphicsPipelineRenderPass,
                .layout = context.graphicsPipelineLayout,
                .basePipelineIndex = -1
            };
            
            if (vulkan.vkCreateGraphicsPipelines(context.device,null,1,&graphicsPipelineCreateInformation,null,&context.graphicsPipeline) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        }
        
        // Create swapchain
        {
            context.graphicsPipelineSwapchainCreated = false;
            context.graphicsPipelineCurrentFrame = 0;
            
            try methods.createSwapchain(imageSize);
        }
        
        // Create command pool
        {
            const commandPoolCreateInformation: vulkan.VkCommandPoolCreateInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
                .flags = vulkan.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
                .queueFamilyIndex = context.physicalDeviceQueueFamilyIndex
            };
            
            if (vulkan.vkCreateCommandPool(context.device,&commandPoolCreateInformation,null,&context.graphicsPipelineCommandPool) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        }
        
        // Create command buffers
        {
            context.graphicsPipelineCommandBuffers = context.allocator.alloc(vulkan.VkCommandBuffer,maxFramesInFlight) catch unreachable;
            
            for (0..maxFramesInFlight) |index| {
                const commandBufferAllocateInformation: vulkan.VkCommandBufferAllocateInfo = .{
                    .sType = vulkan.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
                    .level = vulkan.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
                    .commandBufferCount = 1,
                    .commandPool = context.graphicsPipelineCommandPool
                };
                
                if (vulkan.vkAllocateCommandBuffers(context.device,@ptrCast(&commandBufferAllocateInformation),&context.graphicsPipelineCommandBuffers[index]) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            }
        }
        
        // Create texture image sampler
        {
            var samplerCreateInformation: vulkan.VkSamplerCreateInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
                .pNext = null,
                .flags = 0,
                .magFilter = vulkan.VK_FILTER_LINEAR,
                .minFilter = vulkan.VK_FILTER_LINEAR,
                .mipmapMode = vulkan.VK_SAMPLER_MIPMAP_MODE_LINEAR,
                .addressModeU = vulkan.VK_SAMPLER_ADDRESS_MODE_REPEAT,
                .addressModeV = vulkan.VK_SAMPLER_ADDRESS_MODE_REPEAT,
                .addressModeW = vulkan.VK_SAMPLER_ADDRESS_MODE_REPEAT,
                .mipLodBias = 0,
                .anisotropyEnable = vulkan.VK_TRUE,
                .maxAnisotropy = context.physicalDeviceProperties.limits.maxSamplerAnisotropy,
                .compareEnable = vulkan.VK_FALSE,
                .compareOp = vulkan.VK_COMPARE_OP_ALWAYS,
                .minLod = 0,
                .maxLod = 0,
                .borderColor = vulkan.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
                .unnormalizedCoordinates = vulkan.VK_FALSE
            };
            
            if (vulkan.vkCreateSampler(context.device,&samplerCreateInformation,null,&context.graphicsPipelineTextureImageSampler) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        }
        
        // Initialize texture arraylist
        {
            context.graphicsPipelineCurrentVulkanTextureId = 0;
            context.graphicsPipelineCurrentTextureId = 0;
            context.graphicsPipelineTextures = .empty;
        }
        
        // Create buffers
        {
            // Vertex
            {
                createBuffer(context,std.math.pow(usize,2,16),vulkan.VK_BUFFER_USAGE_TRANSFER_DST_BIT | vulkan.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,vulkan.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,&context.graphicsPipelineVertexBuffer,&context.graphicsPipelineVertexBufferDeviceMemory) catch return CreationError.BufferCreationFailure;
                context.graphicsPipelineVertexBufferData = .empty;
            }
            
            // Index
            {
                createBuffer(context,std.math.pow(usize,2,16),vulkan.VK_BUFFER_USAGE_TRANSFER_DST_BIT | vulkan.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,vulkan.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,&context.graphicsPipelineIndexBuffer,&context.graphicsPipelineIndexBufferDeviceMemory) catch return CreationError.BufferCreationFailure;
                context.graphicsPipelineIndexBufferData = .empty;
            }
            
            // Uniform
            {
                const bufferSize: vulkan.VkDeviceSize = @sizeOf(UniformBufferObject);
                
                context.graphicsPipelineUniformBuffers = context.allocator.alloc(vulkan.VkBuffer,maxFramesInFlight) catch unreachable;
                context.graphicsPipelineUniformBufferDeviceMemories = context.allocator.alloc(vulkan.VkDeviceMemory,maxFramesInFlight) catch unreachable;
                context.graphicsPipelineUniformBufferMapped = context.allocator.alloc(?*anyopaque,maxFramesInFlight) catch unreachable;
                
                for (0..maxFramesInFlight) |index| {
                    createBuffer(context,bufferSize,vulkan.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,vulkan.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vulkan.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,&context.graphicsPipelineUniformBuffers[index],&context.graphicsPipelineUniformBufferDeviceMemories[index]) catch return CreationError.BufferCreationFailure;
                    
                    if (vulkan.vkMapMemory(context.device,context.graphicsPipelineUniformBufferDeviceMemories[index],0,bufferSize,0,&context.graphicsPipelineUniformBufferMapped[index]) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
                }
            }
        }
        
        // Create descriptor pool
        {
            const descriptorPoolSizes: []const vulkan.VkDescriptorPoolSize = &.{
                .{
                    .type = vulkan.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                    .descriptorCount = maxFramesInFlight
                },
                .{
                    .type = vulkan.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                    .descriptorCount = maxTextures
                }
            };
            
            const descriptorPoolCreateInformation: vulkan.VkDescriptorPoolCreateInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
                .maxSets = maxFramesInFlight,
                .pPoolSizes = @ptrCast(descriptorPoolSizes.ptr),
                .poolSizeCount = @intCast(descriptorPoolSizes.len),
                .flags = vulkan.VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT
            };
            
            if (vulkan.vkCreateDescriptorPool(context.device,&descriptorPoolCreateInformation,null,&context.graphicsPipelineDescriptorPool) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        }
        
        // Create descriptor sets
        {
            const descriptorSetAllocateInformation: vulkan.VkDescriptorSetAllocateInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
                .descriptorPool = context.graphicsPipelineDescriptorPool,
                .pSetLayouts = &([_]vulkan.VkDescriptorSetLayout {context.graphicsPipelineDescriptorSetLayout} ** maxFramesInFlight),
                .descriptorSetCount = maxFramesInFlight,
                .pNext = &vulkan.VkDescriptorSetVariableDescriptorCountAllocateInfo {
                    .sType = vulkan.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_VARIABLE_DESCRIPTOR_COUNT_ALLOCATE_INFO,
                    .pDescriptorCounts = &([_]u32 {1,maxTextures / maxFramesInFlight}),
                    .descriptorSetCount = maxFramesInFlight
                }
            };
            
            context.graphicsPipelineDescriptorSets = context.allocator.alloc(vulkan.VkDescriptorSet,maxFramesInFlight) catch unreachable;
            
            if (vulkan.vkAllocateDescriptorSets(context.device,&descriptorSetAllocateInformation,@ptrCast(context.graphicsPipelineDescriptorSets.ptr)) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            
            for (0..maxFramesInFlight) |index| {
                const descriptorBufferInformation: vulkan.VkDescriptorBufferInfo = .{
                    .buffer = context.graphicsPipelineUniformBuffers[index],
                    .offset = 0,
                    .range = @sizeOf(UniformBufferObject)
                };
                
                const writeDescriptorSet: vulkan.VkWriteDescriptorSet = .{
                    .sType = vulkan.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                    .descriptorType = vulkan.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                    .dstSet = context.graphicsPipelineDescriptorSets[index],
                    .dstBinding = 0,
                    .dstArrayElement = 0,
                    .descriptorCount = 1,
                    .pBufferInfo = &descriptorBufferInformation
                };
                
                vulkan.vkUpdateDescriptorSets(context.device,1,&writeDescriptorSet,0,null);
            }
        }
        
        // Create synchronization objects
        {
            context.graphicsPipelineImageAvailableSemaphores = context.allocator.alloc(vulkan.VkSemaphore,maxFramesInFlight) catch unreachable;
            context.graphicsPipelineRenderFinishedSemaphores = context.allocator.alloc(vulkan.VkSemaphore,context.graphicsPipelineSwapchainImages.len) catch unreachable;
            context.graphicsPipelineInFlightFences = context.allocator.alloc(vulkan.VkFence,maxFramesInFlight) catch unreachable;
            
            const semaphoreCreateInformation: vulkan.VkSemaphoreCreateInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
            };
            
            const fenceCreateInformation: vulkan.VkFenceCreateInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
                .flags = vulkan.VK_FENCE_CREATE_SIGNALED_BIT
            };
            
            for (0..maxFramesInFlight) |index| {
                if (vulkan.vkCreateSemaphore(context.device,&semaphoreCreateInformation,null,&context.graphicsPipelineImageAvailableSemaphores[index]) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
                if (vulkan.vkCreateFence(context.device,&fenceCreateInformation,null,&context.graphicsPipelineInFlightFences[index]) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            }
            
            for (0..context.graphicsPipelineSwapchainImages.len) |index| {
                if (vulkan.vkCreateSemaphore(context.device,&semaphoreCreateInformation,null,&context.graphicsPipelineRenderFinishedSemaphores[index]) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            }
        }
        
        context.graphicsPipelinePreviousRenderEndTimestamp = 0;
        context.graphicsPipelineDeltaTime = 0;
        
        // TODO: Fix
        
        appendModel(
            context,
            &.{
                .{
                    .position = .{-0.5,-0.5,0},
                    .uv = .{1,0}
                },
                .{
                    .position = .{0.5,-0.5,0},
                    .uv = .{0,0}
                },
                .{
                    .position = .{0.5,0.5,0},
                    .uv = .{0,1}
                },
                .{
                    .position = .{-0.5,0.5,0},
                    .uv = .{1,1}
                }
            },
            &.{0,1,2,2,3,0},
            null,
        ) catch return CreationError.ModelCreationFailure;
        
        _ = createTexture(context,.{
            .albedo = meowUtilities.miscellaneous.Image.createFromFile(context.allocator,"../../source/textures/meow.png") catch return CreationError.ObjectRetrievalFailure
        }) catch return CreationError.ObjectRetrievalFailure;
        
        // _ = createTexture(context,.{
        //     .albedo = meowUtilities.miscellaneous.Image.createFromFile(context.allocator,"../../source/textures/default.png") catch return CreationError.ObjectRetrievalFailure
        // }) catch return CreationError.ObjectRetrievalFailure;
        
        // BUG: Only 1 texture seems to be loaded at a time O.o
        // BUG: Also like it takes foreverrrrrr to load in a big texture... which like... it shouldn't O.o
        
        return @ptrCast(context);
    }
    
    pub fn destroy(self: *@This()) void {
        const context: *Implementation = @ptrCast(@alignCast(self));
        context.allocator.destroy(context);
    }
    
    pub fn renderFrame(self: *@This()) !void {
        const context: *Implementation = @ptrCast(@alignCast(self));
        
        if (vulkan.vkWaitForFences(context.device,1,&context.graphicsPipelineInFlightFences[context.graphicsPipelineCurrentFrame],vulkan.VK_TRUE,std.math.maxInt(u64)) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        
        var imageIndex: u32 = 0;
        
        if (vulkan.vkAcquireNextImageKHR(context.device,context.graphicsPipelineSwapchain,std.math.maxInt(u64),context.graphicsPipelineImageAvailableSemaphores[context.graphicsPipelineCurrentFrame],null,&imageIndex) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        
        if (vulkan.vkResetFences(context.device,1,&context.graphicsPipelineInFlightFences[context.graphicsPipelineCurrentFrame]) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        
        const commandBuffer: vulkan.VkCommandBuffer = context.graphicsPipelineCommandBuffers[context.graphicsPipelineCurrentFrame];
        
        if (vulkan.vkResetCommandBuffer(commandBuffer,0) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        
        // Record command buffer
        {
            const commandBufferBeginInformation: vulkan.VkCommandBufferBeginInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
            };
            
            if (vulkan.vkBeginCommandBuffer(commandBuffer,&commandBufferBeginInformation) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            
            const enlapsedTime: meowUtilities.time.Timestamp = 0;
            
            vulkan.vkCmdPushConstants(
                commandBuffer,
                context.graphicsPipelineLayout,
                vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
                0,
                @sizeOf(meowUtilities.time.Timestamp),
                &enlapsedTime
            );
            
            const clearColor: vulkan.VkClearValue = .{
                .color = .{
                    .uint32 = .{0,0,0,1}
                }
            };
            
            const renderPassBeginInformation: vulkan.VkRenderPassBeginInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
                .renderPass = context.graphicsPipelineRenderPass,
                .framebuffer = context.graphicsPipelineSwapchainFramebuffers[imageIndex],
                .renderArea = .{
                    .extent = context.physicalDeviceSurfaceCapabilities.currentExtent
                },
                .pClearValues = &clearColor,
                .clearValueCount = 1
            };
            
            vulkan.vkCmdBeginRenderPass(commandBuffer,&renderPassBeginInformation,vulkan.VK_SUBPASS_CONTENTS_INLINE);
            
            vulkan.vkCmdBindPipeline(commandBuffer,vulkan.VK_PIPELINE_BIND_POINT_GRAPHICS,context.graphicsPipeline);
            
            context.graphicsPipelineViewport.width = @floatFromInt(context.physicalDeviceSurfaceCapabilities.currentExtent.width);
            context.graphicsPipelineViewport.height = @floatFromInt(context.physicalDeviceSurfaceCapabilities.currentExtent.height);
            vulkan.vkCmdSetViewport(commandBuffer,0,1,&context.graphicsPipelineViewport);
            
            context.graphicsPipelineScissor.extent = context.physicalDeviceSurfaceCapabilities.currentExtent;
            vulkan.vkCmdSetScissor(commandBuffer,0,1,&context.graphicsPipelineScissor);
            
            const vertexBuffers: []const vulkan.VkBuffer = &.{context.graphicsPipelineVertexBuffer};
            const offsets: []const vulkan.VkDeviceSize = &.{0};
            vulkan.vkCmdBindVertexBuffers(commandBuffer,0,1,@ptrCast(vertexBuffers.ptr),@ptrCast(offsets.ptr));
            
            vulkan.vkCmdBindIndexBuffer(commandBuffer,context.graphicsPipelineIndexBuffer,0,vulkan.VK_INDEX_TYPE_UINT16);
            
            vulkan.vkCmdBindDescriptorSets(commandBuffer,vulkan.VK_PIPELINE_BIND_POINT_GRAPHICS,context.graphicsPipelineLayout,0,1,&context.graphicsPipelineDescriptorSets[context.graphicsPipelineCurrentFrame],0,null);
            
            vulkan.vkCmdDrawIndexed(commandBuffer,@intCast(context.graphicsPipelineIndexBufferData.items.len),1,0,0,0);
            
            vulkan.vkCmdEndRenderPass(commandBuffer);
            
            if (vulkan.vkEndCommandBuffer(commandBuffer) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        }
        
        // Update uniform buffer
        {
            rotation += 0.001;
            
            const uniformBufferObject: UniformBufferObject = .{
                .model = meowUtilities.math.ScaleMatrix(1).rotate(rotation,.Z),
                .view = meowUtilities.math.ViewMatrix(.{0,0.1,1},.{0,0,0},.{0,0,1}),
                .projection = meowUtilities.math.ProjectionMatrix(100,@as(f32,@floatFromInt(context.physicalDeviceSurfaceCapabilities.currentExtent.width)) / @as(f32,@floatFromInt(context.physicalDeviceSurfaceCapabilities.currentExtent.height)),0.1,10)
            };
            
            _ = stdC.memcpy(context.graphicsPipelineUniformBufferMapped[context.graphicsPipelineCurrentFrame],&uniformBufferObject,@sizeOf(UniformBufferObject));
        }
        
        const submitInformation: vulkan.VkSubmitInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .pWaitSemaphores = &context.graphicsPipelineImageAvailableSemaphores[context.graphicsPipelineCurrentFrame],
            .waitSemaphoreCount = 1,
            .pWaitDstStageMask = @ptrCast(&vulkan.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT),
            .pCommandBuffers = &commandBuffer,
            .commandBufferCount = 1,
            .pSignalSemaphores = &context.graphicsPipelineRenderFinishedSemaphores[imageIndex],
            .signalSemaphoreCount = 1
        };
        
        if (vulkan.vkQueueSubmit(context.physicalDeviceGraphicsQueue,1,&submitInformation,context.graphicsPipelineInFlightFences[context.graphicsPipelineCurrentFrame]) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        
        const presentInformation: vulkan.VkPresentInfoKHR = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .pWaitSemaphores = &context.graphicsPipelineRenderFinishedSemaphores[imageIndex],
            .waitSemaphoreCount = 1,
            .pSwapchains = &context.graphicsPipelineSwapchain,
            .swapchainCount = 1,
            .pImageIndices = &imageIndex
        };
        
        if (vulkan.vkQueuePresentKHR(context.physicalDevicePresentQueue,&presentInformation) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        
        context.graphicsPipelineCurrentFrame = (context.graphicsPipelineCurrentFrame + 1) % maxFramesInFlight;
        
        const nowTimestamp: meowUtilities.time.Timestamp = meowUtilities.time.getUniversalTimestamp();
        context.graphicsPipelineDeltaTime = @as(f32,@floatFromInt(nowTimestamp - context.graphicsPipelinePreviousRenderEndTimestamp)) / @as(f32,@floatFromInt(std.time.ms_per_s));
        context.graphicsPipelinePreviousRenderEndTimestamp = nowTimestamp;
    }
    
    pub fn createSwapchain(self: *@This(),imageSize: [2]i32) CreationError!void {
        const context: *Implementation = @ptrCast(@alignCast(self));
        
        _ = vulkan.vkDeviceWaitIdle(context.device);
        
        if (context.graphicsPipelineSwapchainCreated) {
            self.destroySwapchain();
        }
        
        if (vulkan.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(context.physicalDevice,context.surface,&context.physicalDeviceSurfaceCapabilities) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        
        // Create swapchain and images
        {
            context.physicalDeviceSurfaceCapabilities.currentExtent.width = std.math.clamp(@as(u32,@intCast(imageSize[0])),context.physicalDeviceSurfaceCapabilities.minImageExtent.width,context.physicalDeviceSurfaceCapabilities.maxImageExtent.width);
            context.physicalDeviceSurfaceCapabilities.currentExtent.height = std.math.clamp(@as(u32,@intCast(imageSize[1])),context.physicalDeviceSurfaceCapabilities.minImageExtent.height,context.physicalDeviceSurfaceCapabilities.maxImageExtent.height);
            
            var swapchainMinimumImagesCount: u32 = context.physicalDeviceSurfaceCapabilities.minImageCount + 1;
            
            if (context.physicalDeviceSurfaceCapabilities.maxImageCount > 0 and swapchainMinimumImagesCount > context.physicalDeviceSurfaceCapabilities.maxImageCount) {
                swapchainMinimumImagesCount = context.physicalDeviceSurfaceCapabilities.maxImageCount;
            }
            
            const swapchainCreateInformation: vulkan.VkSwapchainCreateInfoKHR = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
                .surface = context.surface,
                .minImageCount = swapchainMinimumImagesCount,
                .imageFormat = context.physicalDeviceSurfaceFormat.format,
                .imageColorSpace = context.physicalDeviceSurfaceFormat.colorSpace,
                .imageExtent = context.physicalDeviceSurfaceCapabilities.currentExtent,
                .imageArrayLayers = 1,
                .imageUsage = vulkan.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
                .preTransform = context.physicalDeviceSurfaceCapabilities.currentTransform,
                .compositeAlpha = vulkan.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
                .presentMode = context.physicalDeviceSurfacePresentMode,
                .clipped = vulkan.VK_TRUE,
                .imageSharingMode = vulkan.VK_SHARING_MODE_EXCLUSIVE
            };
            
            if (vulkan.vkCreateSwapchainKHR(context.device,&swapchainCreateInformation,null,&context.graphicsPipelineSwapchain) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            
            var imageCount: u32 = undefined;
            
            if (vulkan.vkGetSwapchainImagesKHR(context.device,context.graphicsPipelineSwapchain,&imageCount,null) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            
            context.graphicsPipelineSwapchainImages = context.allocator.alloc(vulkan.VkImage,imageCount) catch unreachable;
            
            if (vulkan.vkGetSwapchainImagesKHR(context.device,context.graphicsPipelineSwapchain,&imageCount,@ptrCast(context.graphicsPipelineSwapchainImages.ptr)) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
        }
        
        // Create swapchain image views
        {
            context.graphicsPipelineSwapchainImageViews = context.allocator.alloc(vulkan.VkImageView,context.graphicsPipelineSwapchainImages.len) catch unreachable;
            
            for (0..context.graphicsPipelineSwapchainImages.len) |index| {
                const imageViewCreateInformation: vulkan.VkImageViewCreateInfo = .{
                    .sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                    .image = context.graphicsPipelineSwapchainImages[index],
                    .viewType = vulkan.VK_IMAGE_VIEW_TYPE_2D,
                    .format = context.physicalDeviceSurfaceFormat.format,
                    .components = .{
                        .r = vulkan.VK_COMPONENT_SWIZZLE_IDENTITY,
                        .g = vulkan.VK_COMPONENT_SWIZZLE_IDENTITY,
                        .b = vulkan.VK_COMPONENT_SWIZZLE_IDENTITY,
                        .a = vulkan.VK_COMPONENT_SWIZZLE_IDENTITY
                    },
                    .subresourceRange = .{
                        .aspectMask = vulkan.VK_IMAGE_ASPECT_COLOR_BIT,
                        .baseMipLevel = 0,
                        .levelCount = 1,
                        .baseArrayLayer = 0,
                        .layerCount = 1
                    }
                };
                
                if (vulkan.vkCreateImageView(context.device,&imageViewCreateInformation,null,&context.graphicsPipelineSwapchainImageViews[index]) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            }
        }
        
        // Create framebuffers
        {
            context.graphicsPipelineSwapchainFramebuffers = context.allocator.alloc(vulkan.VkFramebuffer,context.graphicsPipelineSwapchainImages.len) catch unreachable;
            
            for (0..context.graphicsPipelineSwapchainImages.len) |index| {
                const attachments: []const vulkan.VkImageView = &.{context.graphicsPipelineSwapchainImageViews[index]};
                
                const framebufferCreateInformation: vulkan.VkFramebufferCreateInfo = .{
                    .sType = vulkan.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                    .renderPass = context.graphicsPipelineRenderPass,
                    .attachmentCount = 1,
                    .pAttachments = @ptrCast(attachments.ptr),
                    .width = context.physicalDeviceSurfaceCapabilities.currentExtent.width,
                    .height = context.physicalDeviceSurfaceCapabilities.currentExtent.height,
                    .layers = 1
                };
                
                if (vulkan.vkCreateFramebuffer(context.device,&framebufferCreateInformation,null,&context.graphicsPipelineSwapchainFramebuffers[index]) != vulkan.VK_SUCCESS) return CreationError.ObjectRetrievalFailure;
            }
        }
        
        context.graphicsPipelineSwapchainCreated = true;
    }
    
    fn destroySwapchain(self: *@This()) void {
        const context: *Implementation = @ptrCast(@alignCast(self));
        
        vulkan.vkDestroySwapchainKHR(context.device,context.graphicsPipelineSwapchain,null);
        
        for (0..context.graphicsPipelineSwapchainImages.len) |index| {
            vulkan.vkDestroyImageView(context.device,context.graphicsPipelineSwapchainImageViews[index],null);
            vulkan.vkDestroyFramebuffer(context.device,context.graphicsPipelineSwapchainFramebuffers[index],null);
        }
        
        context.allocator.free(context.graphicsPipelineSwapchainImages);
        
        context.allocator.free(context.graphicsPipelineSwapchainImageViews);
        
        context.allocator.free(context.graphicsPipelineSwapchainFramebuffers);
    }
    
    pub fn getDeltaTime(self: *@This()) f32 {
        const context: *Implementation = @ptrCast(@alignCast(self));
        return context.graphicsPipelineDeltaTime;
    }
};
