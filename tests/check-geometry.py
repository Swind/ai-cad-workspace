"""Verify exported geometry independently of the producing script."""
import math
from pathlib import Path
import build123d as bd
from PIL import Image, ImageStat

shape = bd.import_step("plate.step")
assert shape.is_valid
assert len(shape.solids()) == 1
box = shape.bounding_box()
for actual, expected in zip(box.size, (80, 50, 5)):
    assert abs(actual - expected) < 1e-5, (actual, expected)
assert abs(shape.volume - (80 * 50 * 5 - math.pi * 3**2 * 5)) < 1e-4
for z in (-2.4, 0, 2.4):
    assert not shape.is_inside((0, 0, z))
    assert not shape.is_inside((2.9, 0, z))
    assert shape.is_inside((3.1, 0, z))
assert Path("plate.stl").stat().st_size > 100
for name in ("top.png", "iso.png"):
    with Image.open(name) as image:
        image.load()
        assert image.width >= 256 and image.height >= 256
        assert max(ImageStat.Stat(image.convert("RGB")).stddev) > 5, "blank render"
print("PASS: valid solid, bounds, volume, central through-hole, exports, nonblank snapshots")
