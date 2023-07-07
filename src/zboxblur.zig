const c = @cImport({
    @cInclude("vapoursynth/VapourSynth4.h");
});

const std = @import("std");
const float_process = @import("float_process.zig");
const int_process = @import("int_process.zig");
const allocator = std.heap.c_allocator;

const ZboxblurData = struct {
    node: ?*c.VSNode,
    radius: usize,
    passes: i32,
    psize: u6,
};

export fn zboxblurGetFrame(n: c_int, activationReason: c_int, instanceData: ?*anyopaque, frameData: ?*?*anyopaque, frameCtx: ?*c.VSFrameContext, core: ?*c.VSCore, vsapi: ?*const c.VSAPI) callconv(.C) ?*const c.VSFrame {
    _ = frameData;
    var d: *ZboxblurData = @ptrCast(@alignCast(instanceData));

    if (activationReason == c.arInitial) {
        vsapi.?.requestFrameFilter.?(n, d.node, frameCtx);
    } else if (activationReason == c.arAllFramesReady) {
        const src = vsapi.?.getFrameFilter.?(n, d.node, frameCtx);
        defer vsapi.?.freeFrame.?(src);

        const fi = vsapi.?.getVideoFrameFormat.?(src);
        const width = vsapi.?.getFrameWidth.?(src, 0);
        const height = vsapi.?.getFrameHeight.?(src, 0);
        var dst = vsapi.?.newVideoFrame.?(fi, width, height, src, core);
        const npixel: usize = @intCast(@max(width, height));
        const psize: u6 = d.psize;

        if (psize == 1) {
            var tmp1 = allocator.alloc(u8, npixel) catch unreachable;
            var tmp2 = allocator.alloc(u8, npixel) catch unreachable;
            defer allocator.free(tmp1);
            defer allocator.free(tmp2);

            var plane: c_int = 0;
            while (plane < fi.*.numPlanes) : (plane += 1) {
                var srcp: [*]const u8 = vsapi.?.getReadPtr.?(src, plane);
                var dstp: [*]u8 = vsapi.?.getWritePtr.?(dst, plane);
                const stride: usize = @intCast(vsapi.?.getStride.?(src, plane));
                const h: usize = @intCast(vsapi.?.getFrameHeight.?(src, plane));
                const w: usize = @intCast(vsapi.?.getFrameWidth.?(src, plane));

                int_process.hblur(u8, dstp, stride, srcp, stride, w, h, d.radius, d.passes, tmp1.ptr, tmp2.ptr, psize);
                int_process.vblur(u8, dstp, stride, dstp, stride, w, h, d.radius, d.passes, tmp1.ptr, tmp2.ptr, psize);
            }
        } else if (psize == 2) {
            var tmp1 = allocator.alloc(u16, npixel) catch unreachable;
            var tmp2 = allocator.alloc(u16, npixel) catch unreachable;
            defer allocator.free(tmp1);
            defer allocator.free(tmp2);

            var plane: c_int = 0;
            while (plane < fi.*.numPlanes) : (plane += 1) {
                var srcp: [*]const u8 = vsapi.?.getReadPtr.?(src, plane);
                var dstp: [*]u8 = vsapi.?.getWritePtr.?(dst, plane);
                const stride: usize = @intCast(vsapi.?.getStride.?(src, plane));
                const h: usize = @intCast(vsapi.?.getFrameHeight.?(src, plane));
                const w: usize = @intCast(vsapi.?.getFrameWidth.?(src, plane));

                int_process.hblur(u16, dstp, stride, srcp, stride, w, h, d.radius, d.passes, tmp1.ptr, tmp2.ptr, psize);
                int_process.vblur(u16, dstp, stride, dstp, stride, w, h, d.radius, d.passes, tmp1.ptr, tmp2.ptr, psize);
            }
        } else {
            var tmp1 = allocator.alloc(f32, npixel) catch unreachable;
            var tmp2 = allocator.alloc(f32, npixel) catch unreachable;
            defer allocator.free(tmp1);
            defer allocator.free(tmp2);

            var plane: c_int = 0;
            while (plane < fi.*.numPlanes) : (plane += 1) {
                var srcp: [*]const u8 = vsapi.?.getReadPtr.?(src, plane);
                var dstp: [*]u8 = vsapi.?.getWritePtr.?(dst, plane);
                const stride: usize = @intCast(vsapi.?.getStride.?(src, plane));
                const h: usize = @intCast(vsapi.?.getFrameHeight.?(src, plane));
                const w: usize = @intCast(vsapi.?.getFrameWidth.?(src, plane));

                float_process.hblur(f32, dstp, stride, srcp, stride, w, h, d.radius, d.passes, tmp1.ptr, tmp2.ptr, psize);
                float_process.vblur(f32, dstp, stride, dstp, stride, w, h, d.radius, d.passes, tmp1.ptr, tmp2.ptr, psize);
            }
        }

        return dst;
    }
    return null;
}

export fn zboxblurFree(instanceData: ?*anyopaque, core: ?*c.VSCore, vsapi: ?*const c.VSAPI) callconv(.C) void {
    _ = core;
    var d: *ZboxblurData = @ptrCast(@alignCast(instanceData));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn zboxblurCreate(in: ?*const c.VSMap, out: ?*c.VSMap, userData: ?*anyopaque, core: ?*c.VSCore, vsapi: ?*const c.VSAPI) callconv(.C) void {
    _ = userData;
    var d: ZboxblurData = undefined;
    var err: c_int = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, 0).?;
    var vi: *const c.VSVideoInfo = vsapi.?.getVideoInfo.?(d.node);

    d.psize = @as(u6, @intCast(vi.format.bytesPerSample));
    d.radius = @as(usize, @intCast(vsapi.?.mapGetInt.?(in, "radius", 0, &err)));
    if (err != 0) {
        d.radius = 2;
    }

    d.passes = @truncate(vsapi.?.mapGetInt.?(in, "passes", 0, &err));
    if (err != 0) {
        d.passes = 1;
    }

    if ((d.radius < 1) or (d.passes < 1)) {
        vsapi.?.mapSetError.?(out, "zboxblur: nothing to be performed");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    var data: *ZboxblurData = allocator.create(ZboxblurData) catch unreachable;
    data.* = d;

    var deps = [_]c.VSFilterDependency{
        c.VSFilterDependency{
            .source = d.node,
            .requestPattern = c.rpStrictSpatial,
        },
    };
    vsapi.?.createVideoFilter.?(out, "zboxblur", vi, zboxblurGetFrame, zboxblurFree, c.fmParallel, &deps, 1, data, core);
}

export fn VapourSynthPluginInit2(plugin: *c.VSPlugin, vspapi: *const c.VSPLUGINAPI) void {
    _ = vspapi.configPlugin.?("com.julek.zboxblur", "zboxblur", "VapourSynth BoxBlur with ziglang", c.VS_MAKE_VERSION(1, 0), c.VAPOURSYNTH_API_VERSION, 0, plugin);
    _ = vspapi.registerFunction.?("Blur", "clip:vnode;radius:int:opt;passes:int:opt;", "clip:vnode;", zboxblurCreate, null, plugin);
}
