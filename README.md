# vapoursynth-zboxblur
BoxBlur filter for vapoursynth written in ziglang.

### Usage
```python
zboxblur.Blur(vnode clip[, int radius=2, int passes=1])
```

### Speed
```python
src = core.std.BlankClip(None, 1920, 1080, vs.GRAY16, 5000, keep=True)
r = 6
p = 6
b1 = src.zboxblur.Blur(r, p)
b2 = src.std.BoxBlur(vradius=r, hradius=r, vpasses=p, hpasses=p)
b3 = vsrgtools.box_blur(src, r, p) # (std.Convolution)

b1.set_output(1) # Output 5000 frames in 10.65 seconds (469.59 fps)
b2.set_output(2) # Output 5000 frames in 51.64 seconds (96.82 fps)
b3.set_output(3) # Output 5000 frames in 10.17 seconds (491.79 fps)
```
Looks a bit slower than std.Convolution (but without radius limit) when used in BlankClip, and faster than std.Convolution when used together with other filters:
```python
src = core.std.BlankClip(None, 1920, 1080, vs.GRAY16, 5000, keep=True)
r = 6
p = 6
b1 = src.zboxblur.Blur(r, p).resize.Bicubic(format=vs.RGB24)
b2 = vsrgtools.box_blur(src, r, p).resize.Bicubic(format=vs.RGB24) # (std.Convolution)

b1.set_output(1) # Output 5000 frames in 11.04 seconds (452.79 fps)
b2.set_output(2) # Output 5000 frames in 12.50 seconds (399.98 fps)
```

### Building
Zig ver >= 0.11.0-dev.3886

``zig build -Doptimize=ReleaseFast``

### TODO
1. Float support (which will be less fast because it cannot divide with bitshift).
2. hradius and vradius.