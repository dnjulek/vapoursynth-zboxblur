> [!CAUTION] 
> DEPRECATED! Use https://github.com/dnjulek/vapoursynth-zip



# vapoursynth-zboxblur
[![Linux](https://github.com/dnjulek/vapoursynth-zboxblur/actions/workflows/linux-build.yml/badge.svg)](https://github.com/dnjulek/vapoursynth-zboxblur/actions/workflows/linux-build.yml)
[![Windows](https://github.com/dnjulek/vapoursynth-zboxblur/actions/workflows/windows-build.yml/badge.svg)](https://github.com/dnjulek/vapoursynth-zboxblur/actions/workflows/windows-build.yml)

BoxBlur filter for vapoursynth written in ziglang.

## Usage
```python
zboxblur.Blur(vnode clip[, int hradius=1, int hpasses=1, int vradius=1, int vpasses=1])
```

## Speed
BlankClip only:
```python
def conv_blur(src, r, p):
    for _ in range(p):
        src = src.std.Convolution([1] * (r * 2 + 1), mode='hv')
    return src

src = core.std.BlankClip(None, 1920, 1080, vs.GRAYS, 5000, keep=True)
zr2p1 = src.zboxblur.Blur(vradius=2, hradius=2, vpasses=1, hpasses=1)
cr2p1 = conv_blur(src, 2, 1)
br2p1 = src.std.BoxBlur(vradius=2, hradius=2, vpasses=1, hpasses=1)

zr2p1.set_output(1) # Output 5000 frames in 5.76 seconds (868.30 fps)
cr2p1.set_output(2) # Output 5000 frames in 2.64 seconds (1897.24 fps)
br2p1.set_output(3) # Output 5000 frames in 14.50 seconds (344.78 fps)
```
Faster than BoxBlur and slower than Convolution.

What if we use it together with another filter?
```python
src = core.std.BlankClip(None, 1920, 1080, vs.GRAYS, 5000, keep=True)
zr2p1resz = src.zboxblur.Blur(vradius=2, hradius=2, vpasses=1, hpasses=1).resize.Bicubic(format=vs.RGB24)
cr2p1resz = conv_blur(src, 2, 1).resize.Bicubic(format=vs.RGB24)
br2p1resz = src.std.BoxBlur(vradius=2, hradius=2, vpasses=1, hpasses=1).resize.Bicubic(format=vs.RGB24)

zr2p1resz.set_output(1) # Output 5000 frames in 8.52 seconds (586.87 fps)
cr2p1resz.set_output(2) # Output 5000 frames in 5.92 seconds (844.09 fps)
br2p1resz.set_output(3) # Output 5000 frames in 17.45 seconds (286.61 fps)
```
The difference drops a bit, but Convolution is still faster.

What if we use more passes?
```python
src = core.std.BlankClip(None, 1920, 1080, vs.GRAYS, 5000, keep=True)
zr2p2resz = src.zboxblur.Blur(vradius=2, hradius=2, vpasses=2, hpasses=2).resize.Bicubic(format=vs.RGB24)
zr2p4resz = src.zboxblur.Blur(vradius=2, hradius=2, vpasses=4, hpasses=4).resize.Bicubic(format=vs.RGB24)
zr6p20resz = src.zboxblur.Blur(vradius=6, hradius=6, vpasses=20, hpasses=20).resize.Bicubic(format=vs.RGB24)

cr2p2resz = conv_blur(src, 2, 2).resize.Bicubic(format=vs.RGB24)
cr2p4resz = conv_blur(src, 2, 4).resize.Bicubic(format=vs.RGB24)
cr6p20resz = conv_blur(src, 6, 20).resize.Bicubic(format=vs.RGB24)


zr2p2resz.set_output(1) # Output 5000 frames in 8.56 seconds (583.83 fps)
zr2p4resz.set_output(2) # Output 5000 frames in 9.01 seconds (554.97 fps)
zr6p20resz.set_output(3) # Output 5000 frames in 26.81 seconds (186.50 fps)

cr2p2resz.set_output(4) # Output 5000 frames in 9.68 seconds (516.51 fps)
cr2p4resz.set_output(5) # Output 5000 frames in 16.92 seconds (295.45 fps)
cr6p20resz.set_output(6) # Output 5000 frames in 72.87 seconds (68.61 fps)
```
In this case Convolution seems slower.\
Conclusion: for ``radius < 13`` Convolution is still the fastest, unless you use passes.
## Building
Zig ver >= 0.11.0-dev.4333

``zig build -Doptimize=ReleaseFast``

If you don't have vapoursynth installed you must provide the include path with ``-Dvsinclude=...``.
