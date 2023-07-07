inline fn blur(dstp: anytype, _dst_step: usize, srcp: anytype, _src_step: usize, len: usize, radius: usize, shift: u6) void {
    var src_step: usize = (_src_step >> shift);
    var dst_step: usize = (_dst_step >> shift);
    const ksize: f32 = @floatFromInt(radius * 2 + 1);
    const inv: f32 = 1.0 / ksize;
    var sum: f32 = srcp[radius * src_step];

    var x: usize = 0;
    while (x < radius) : (x += 1) {
        var srcv: f32 = srcp[x * src_step];
        sum += srcv * 2;
    }

    sum = sum * inv;

    x = 0;
    while (x <= radius) : (x += 1) {
        var src1: f32 = srcp[(radius + x) * src_step];
        var src2: f32 = srcp[(radius - x) * src_step];
        sum += (src1 - src2) * inv;
        dstp[x * dst_step] = sum;
    }

    while (x < len - radius) : (x += 1) {
        var src1: f32 = srcp[(radius + x) * src_step];
        var src2: f32 = srcp[(x - radius - 1) * src_step];
        sum += (src1 - src2) * inv;
        dstp[x * dst_step] = sum;
    }

    while (x < len) : (x += 1) {
        var src1: f32 = srcp[(2 * len - radius - x - 1) * src_step];
        var src2: f32 = srcp[(x - radius - 1) * src_step];
        sum += (src1 - src2) * inv;
        dstp[x * dst_step] = sum;
    }
}

inline fn blur_passes(comptime T: type, _dstp: [*]u8, dst_step: usize, _srcp: [*]const u8, src_step: usize, len: usize, radius: usize, _passes: i32, _tmp1: anytype, _tmp2: anytype, _psize: u6) void {
    var srcp: [*]const T = @as([*]const T, @ptrCast(@alignCast(_srcp)));
    var dstp: [*]T = @as([*]T, @ptrCast(@alignCast(_dstp)));
    var tmp1 = _tmp1;
    var tmp2 = _tmp2;

    const shift: u6 = _psize >> 1;
    const psize: usize = _psize;
    var passes: i32 = _passes;

    blur(tmp1, psize, srcp, src_step, len, radius, shift);
    while (passes > 2) : (passes -= 1) {
        blur(tmp2, psize, tmp1, psize, len, radius, shift);
        var tmp3 = tmp1;
        tmp1 = tmp2;
        tmp2 = tmp3;
    }

    if (passes > 1) {
        blur(dstp, dst_step, tmp1, psize, len, radius, shift);
    } else {
        var x: usize = 0;
        while (x < len) : (x += 1) {
            dstp[x * (dst_step >> shift)] = tmp1[x];
        }
    }
}

pub fn hblur(comptime T: type, dstp: [*]u8, dst_linesize: usize, srcp: [*]const u8, src_linesize: usize, w: usize, h: usize, radius: usize, passes: i32, temp1: anytype, temp2: anytype, psize: u6) void {
    var y: usize = 0;
    while (y < h) : (y += 1) {
        blur_passes(T, dstp + y * dst_linesize, psize, srcp + y * src_linesize, psize, w, radius, passes, temp1, temp2, psize);
    }
}

pub fn vblur(comptime T: type, dstp: [*]u8, dst_linesize: usize, srcp: [*]const u8, src_linesize: usize, w: usize, h: usize, radius: usize, passes: i32, temp1: anytype, temp2: anytype, psize: u6) void {
    var x: usize = 0;
    while (x < w) : (x += 1) {
        blur_passes(T, dstp + x * psize, dst_linesize, srcp + x * psize, src_linesize, h, radius, passes, temp1, temp2, psize);
    }
}
