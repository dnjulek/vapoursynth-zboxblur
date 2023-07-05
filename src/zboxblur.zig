const c = @cImport({
    @cInclude("vapoursynth/VapourSynth4.h");
});

const std = @import("std");
const allocator = std.heap.c_allocator;

const ZboxblurData = struct {
    node: ?*c.VSNode,
    pixsize: usize,
    radius: usize,
    passes: i32,
};

inline fn blur(comptime T: type, dstp: anytype, _dst_step: usize, srcp: anytype, _src_step: usize, len: usize, radius: usize, pixsize: usize) void {
    var src_step = if (pixsize == 1) _src_step else (_src_step >> 1);
    var dst_step = if (pixsize == 1) _dst_step else (_dst_step >> 1);
    const iradius: i32 = @intCast(radius);
    const ksize: i32 = iradius * 2 + 1;
    const inv: i32 = @divTrunc(((1 << 16) + iradius), ksize);
    var sum: i32 = @as(i32, srcp[radius * src_step]);

    var x: usize = 0;
    while (x < radius) : (x += 1) {
        var srcv: i32 = @as(i32, srcp[x * src_step]);
        sum += srcv << 1;
    }

    sum = sum * inv + (1 << 15);

    x = 0;
    while (x <= radius) : (x += 1) {
        var src1: i32 = @as(i32, srcp[(radius + x) * src_step]);
        var src2: i32 = @as(i32, srcp[(radius - x) * src_step]);
        sum += (src1 - src2) * inv;
        dstp[x * dst_step] = @as(T, @intCast(sum >> 16));
    }

    while (x < len - radius) : (x += 1) {
        var src1: i32 = @as(i32, srcp[(radius + x) * src_step]);
        var src2: i32 = @as(i32, srcp[(x - radius - 1) * src_step]);
        sum += (src1 - src2) * inv;
        dstp[x * dst_step] = @as(T, @intCast(sum >> 16));
    }

    while (x < len) : (x += 1) {
        var src1: i32 = @as(i32, srcp[(2 * len - radius - x - 1) * src_step]);
        var src2: i32 = @as(i32, srcp[(x - radius - 1) * src_step]);
        sum += (src1 - src2) * inv;
        dstp[x * dst_step] = @as(T, @intCast(sum >> 16));
    }
}

inline fn blur_passes(comptime T: type, _dstp: [*]u8, dst_step: usize, _srcp: [*]const u8, src_step: usize, len: usize, radius: usize, _passes: i32, _tmp1: anytype, _tmp2: anytype, pixsize: usize) void {
    var srcp: [*]const T = @as([*]const T, @ptrCast(@alignCast(_srcp)));
    var dstp: [*]T = @as([*]T, @ptrCast(@alignCast(_dstp)));
    var tmp1: [*]T = @as([*]T, _tmp1);
    var tmp2: [*]T = @as([*]T, _tmp2);

    var passes: i32 = _passes;

    blur(T, tmp1, pixsize, srcp, src_step, len, radius, pixsize);
    while (passes > 2) : (passes -= 1) {
        blur(T, tmp2, pixsize, tmp1, pixsize, len, radius, pixsize);
        var tmp3 = tmp1;
        tmp1 = tmp2;
        tmp2 = tmp3;
    }

    if (passes > 1) {
        blur(T, dstp, dst_step, tmp1, pixsize, len, radius, pixsize);
    } else {
        var x: usize = 0;
        while (x < len) : (x += 1) {
            dstp[x * (if (pixsize == 1) dst_step else (dst_step >> 1))] = tmp1[x];
        }
    }
}

fn hblur(comptime T: type, dstp: [*]u8, dst_linesize: usize, srcp: [*]const u8, src_linesize: usize, w: usize, h: usize, radius: usize, passes: i32, temp1: anytype, temp2: anytype, pixsize: usize) void {
    var y: usize = 0;
    while (y < h) : (y += 1) {
        blur_passes(T, dstp + y * dst_linesize, pixsize, srcp + y * src_linesize, pixsize, w, radius, passes, temp1, temp2, pixsize);
    }
}

fn vblur(comptime T: type, dstp: [*]u8, dst_linesize: usize, srcp: [*]const u8, src_linesize: usize, w: usize, h: usize, radius: usize, passes: i32, temp1: anytype, temp2: anytype, pixsize: usize) void {
    var x: usize = 0;
    while (x < w) : (x += 1) {
        blur_passes(T, dstp + x * pixsize, dst_linesize, srcp + x * pixsize, src_linesize, h, radius, passes, temp1, temp2, pixsize);
    }
}

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
        var psize = d.pixsize;

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

                hblur(u8, dstp, stride, srcp, stride, w, h, d.radius, d.passes, tmp1.ptr, tmp2.ptr, psize);
                vblur(u8, dstp, stride, dstp, stride, w, h, d.radius, d.passes, tmp1.ptr, tmp2.ptr, psize);
            }
        } else {
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

                hblur(u16, dstp, stride, srcp, stride, w, h, d.radius, d.passes, tmp1.ptr, tmp2.ptr, psize);
                vblur(u16, dstp, stride, dstp, stride, w, h, d.radius, d.passes, tmp1.ptr, tmp2.ptr, psize);
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

    d.pixsize = @as(usize, @intCast(vi.format.bytesPerSample));
    d.radius = @as(usize, @intCast(vsapi.?.mapGetInt.?(in, "radius", 0, &err)));
    if (err != 0) {
        d.radius = 2;
    }

    d.passes = @truncate(vsapi.?.mapGetInt.?(in, "passes", 0, &err));
    if (err != 0) {
        d.passes = 1;
    }

    if (vi.format.sampleType != c.stInteger) {
        vsapi.?.mapSetError.?(out, "zboxblur: only integer format is supported");
        vsapi.?.freeNode.?(d.node);
        return;
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
