"""Exercise native ray casting, connected components and 3MF skill dependencies."""
from io import BytesIO
import numpy as np
import trimesh

mesh = trimesh.creation.box(extents=[10, 20, 30])
assert len(mesh.split()) == 1
assert mesh.ray.intersects_any([[0, 0, 40]], [[0, 0, -1]]).tolist() == [True]
data = trimesh.exchange.threemf.export_3MF(trimesh.Scene(mesh))
scene = trimesh.load(BytesIO(data), file_type='3mf')
assert np.isclose(sum(part.volume for part in scene.geometry.values()), 6000)
print('PASS: mesh split, native R-tree ray casting, 3MF round trip')
