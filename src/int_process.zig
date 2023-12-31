inline fn blur(comptime T: type, dstp: anytype, _dst_step: usize, srcp: anytype, _src_step: usize, len: usize, radius: usize, shift: u6) void {
    const src_step = _src_step >> shift;
    const dst_step = _dst_step >> shift;
    const iradius: i32 = @intCast(radius);
    const ksize: i32 = iradius * 2 + 1;
    const inv: i32 = @divTrunc(((1 << 16) + iradius), ksize);
    var sum: i32 = @as(i32, srcp[radius * src_step]);

    var x: usize = 0;
    while (x < radius) : (x += 1) {
        const srcv: i32 = @as(i32, srcp[x * src_step]);
        sum += srcv << 1;
    }

    sum = sum * inv + (1 << 15);

    x = 0;
    while (x <= radius) : (x += 1) {
        const src1: i32 = @as(i32, srcp[(radius + x) * src_step]);
        const src2: i32 = @as(i32, srcp[(radius - x) * src_step]);
        sum += (src1 - src2) * inv;
        dstp[x * dst_step] = @as(T, @intCast(sum >> 16));
    }

    while (x < len - radius) : (x += 1) {
        const src1: i32 = @as(i32, srcp[(radius + x) * src_step]);
        const src2: i32 = @as(i32, srcp[(x - radius - 1) * src_step]);
        sum += (src1 - src2) * inv;
        dstp[x * dst_step] = @as(T, @intCast(sum >> 16));
    }

    while (x < len) : (x += 1) {
        const src1: i32 = @as(i32, srcp[(2 * len - radius - x - 1) * src_step]);
        const src2: i32 = @as(i32, srcp[(x - radius - 1) * src_step]);
        sum += (src1 - src2) * inv;
        dstp[x * dst_step] = @as(T, @intCast(sum >> 16));
    }
}

inline fn blur_passes(comptime T: type, _dstp: [*]u8, dst_step: usize, _srcp: [*]const u8, src_step: usize, len: usize, radius: usize, _passes: i32, _tmp1: anytype, _tmp2: anytype, _psize: u6) void {
    const srcp: [*]const T = @as([*]const T, @ptrCast(@alignCast(_srcp)));
    var dstp: [*]T = @as([*]T, @ptrCast(@alignCast(_dstp)));
    var tmp1 = _tmp1;
    var tmp2 = _tmp2;

    const shift: u6 = _psize >> 1;
    const psize: usize = _psize;
    var passes: i32 = _passes;

    blur(T, tmp1, psize, srcp, src_step, len, radius, shift);
    while (passes > 2) : (passes -= 1) {
        blur(T, tmp2, psize, tmp1, psize, len, radius, shift);
        const tmp3 = tmp1;
        tmp1 = tmp2;
        tmp2 = tmp3;
    }

    if (passes > 1) {
        blur(T, dstp, dst_step, tmp1, psize, len, radius, shift);
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
