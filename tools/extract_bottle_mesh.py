"""Extract and normalize the Bottle mesh from the interior props FBX."""

from __future__ import annotations

import struct
import sys
import json
from pathlib import Path

import numpy as np
import ufbx


FBX_PATH = Path(
    "assets/materials/objects_interior/Models/Objects_Interior(Village)_Demo.fbx"
)
TEXTURE_PATH = Path("assets/materials/objects_interior/Textures/Bottle.png")
OUT_GLB = Path("assets/models/coca_bottle/bottle.glb")
TARGET_HEIGHT_M = 0.22


def _node_matrix(node: ufbx.Node) -> np.ndarray:
    t = node.local_transform
    # Column-major 4x4 from ufbx Transform (translation, rotation quat, scale).
    q = t.rotation
    x, y, z, w = q.x, q.y, q.z, q.w
    sx, sy, sz = t.scale.x, t.scale.y, t.scale.z
    tx, ty, tz = t.translation.x, t.translation.y, t.translation.z

    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    wx, wy, wz = w * x, w * y, w * z

    rot = np.array(
        [
            [1 - 2 * (yy + zz), 2 * (xy - wz), 2 * (xz + wy)],
            [2 * (xy + wz), 1 - 2 * (xx + zz), 2 * (yz - wx)],
            [2 * (xz - wy), 2 * (yz + wx), 1 - 2 * (xx + yy)],
        ],
        dtype=np.float64,
    )
    mat = np.eye(4, dtype=np.float64)
    mat[:3, :3] = rot @ np.diag([sx, sy, sz])
    mat[:3, 3] = [tx, ty, tz]
    return mat


def _world_matrix(node: ufbx.Node) -> np.ndarray:
    mats: list[np.ndarray] = []
    current: ufbx.Node | None = node
    while current is not None:
        mats.append(_node_matrix(current))
        current = current.parent
    result = np.eye(4, dtype=np.float64)
    for mat in reversed(mats):
        result = result @ mat
    return result


def _find_bottle_mesh_node(root: ufbx.Node) -> ufbx.Node | None:
    found: ufbx.Node | None = None

    def walk(node: ufbx.Node) -> None:
        nonlocal found
        for child in node.children:
            walk(child)
        if node.name == "Bottle" and node.mesh is not None:
            found = node

    walk(root)
    return found


def _extract_mesh(node: ufbx.Node) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    mesh = node.mesh
    world = _world_matrix(node)

    positions: list[list[float]] = []
    normals: list[list[float]] = []
    uvs: list[list[float]] = []
    indices: list[int] = []

    for face in mesh.faces:
        face_indices = []
        for corner_i in range(face.num_indices):
            corner = face.index_begin + corner_i
            vi = mesh.vertex_indices[corner]
            pos = mesh.vertices[vi]
            p = world @ np.array([pos.x, pos.y, pos.z, 1.0], dtype=np.float64)
            positions.append([float(p[0]), float(p[1]), float(p[2])])

            if mesh.vertex_normal.exists:
                ni = mesh.vertex_normal.indices[corner]
                n = mesh.vertex_normal.values[ni]
                nr = world[:3, :3] @ np.array([n.x, n.y, n.z], dtype=np.float64)
                length = np.linalg.norm(nr)
                if length > 1e-8:
                    nr /= length
                normals.append([float(nr[0]), float(nr[1]), float(nr[2])])
            else:
                normals.append([0.0, 1.0, 0.0])

            if mesh.vertex_uv.exists:
                ui = mesh.vertex_uv.indices[corner]
                uv = mesh.vertex_uv.values[ui]
                uvs.append([float(uv.x), float(1.0 - uv.y)])
            else:
                uvs.append([0.0, 0.0])

            face_indices.append(len(positions) - 1)

        # Triangulate n-gons via fan.
        for i in range(1, len(face_indices) - 1):
            indices.extend([face_indices[0], face_indices[i], face_indices[i + 1]])

    pos_arr = np.array(positions, dtype=np.float32)
    nor_arr = np.array(normals, dtype=np.float32)
    uv_arr = np.array(uvs, dtype=np.float32)
    idx_arr = np.array(indices, dtype=np.uint32)
    return pos_arr, nor_arr, uv_arr, idx_arr


def _normalize(pos: np.ndarray) -> np.ndarray:
    mn = pos.min(axis=0)
    mx = pos.max(axis=0)
    centered = pos - (mn + mx) * 0.5
    size = mx - mn
    height = float(np.max(size))
    if height < 1e-6:
        return centered
    scale = TARGET_HEIGHT_M / height
    return centered * scale


def _write_glb(
    path: Path,
    positions: np.ndarray,
    normals: np.ndarray,
    uvs: np.ndarray,
    indices: np.ndarray,
    texture_bytes: bytes,
) -> None:
    pos_bytes = positions.tobytes()
    nor_bytes = normals.tobytes()
    uv_bytes = uvs.tobytes()
    idx_bytes = indices.tobytes()
    tex_bytes = texture_bytes

    pos_offset = 0
    nor_offset = len(pos_bytes)
    uv_offset = nor_offset + len(nor_bytes)
    idx_offset = uv_offset + len(uv_bytes)
    tex_offset = idx_offset + len(idx_bytes)

    buffer_blob = pos_bytes + nor_bytes + uv_bytes + idx_bytes + tex_bytes

    pos_min = positions.min(axis=0).tolist()
    pos_max = positions.max(axis=0).tolist()

    gltf = {
        "asset": {"version": "2.0", "generator": "extract_bottle_mesh.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": "Bottle"}],
        "materials": [
            {
                "name": "Bottle",
                "pbrMetallicRoughness": {
                    "baseColorTexture": {"index": 0},
                    "metallicFactor": 0.0,
                    "roughnessFactor": 1.0,
                },
            }
        ],
        "meshes": [
            {
                "name": "Bottle",
                "primitives": [
                    {
                        "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                        "indices": 3,
                        "material": 0,
                        "mode": 4,
                    }
                ],
            }
        ],
        "textures": [{"source": 0, "sampler": 0}],
        "images": [{"mimeType": "image/png", "bufferView": 4}],
        "samplers": [{"magFilter": 9728, "minFilter": 9728}],
        "accessors": [
            {
                "bufferView": 0,
                "componentType": 5126,
                "count": int(len(positions)),
                "type": "VEC3",
                "min": pos_min,
                "max": pos_max,
            },
            {"bufferView": 1, "componentType": 5126, "count": int(len(normals)), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": int(len(uvs)), "type": "VEC2"},
            {"bufferView": 3, "componentType": 5125, "count": int(len(indices)), "type": "SCALAR"},
        ],
        "bufferViews": [
            {"buffer": 0, "byteOffset": pos_offset, "byteLength": len(pos_bytes), "target": 34962},
            {"buffer": 0, "byteOffset": nor_offset, "byteLength": len(nor_bytes), "target": 34962},
            {"buffer": 0, "byteOffset": uv_offset, "byteLength": len(uv_bytes), "target": 34962},
            {"buffer": 0, "byteOffset": idx_offset, "byteLength": len(idx_bytes), "target": 34963},
            {"buffer": 0, "byteOffset": tex_offset, "byteLength": len(tex_bytes)},
        ],
        "buffers": [{"byteLength": len(buffer_blob)}],
    }

    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_pad = (4 - (len(json_bytes) % 4)) % 4
    json_bytes += b" " * json_pad

    bin_pad = (4 - (len(buffer_blob) % 4)) % 4
    buffer_blob_padded = buffer_blob + b"\x00" * bin_pad

    total_length = 12 + 8 + len(json_bytes) + 8 + len(buffer_blob_padded)
    header = struct.pack("<4sII", b"glTF", 2, total_length)
    json_chunk = struct.pack("<I4s", len(json_bytes), b"JSON") + json_bytes
    bin_chunk = struct.pack("<I4s", len(buffer_blob_padded), b"BIN\x00") + buffer_blob_padded

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + json_chunk + bin_chunk)


def main() -> int:
    project_root = Path(__file__).resolve().parents[1]
    fbx_path = project_root / FBX_PATH
    out_path = project_root / OUT_GLB

    if not fbx_path.is_file():
        print(f"Missing FBX: {fbx_path}", file=sys.stderr)
        return 1

    scene = ufbx.load_file(str(fbx_path))
    bottle = _find_bottle_mesh_node(scene.root_node)
    if bottle is None:
        print("Could not find Bottle mesh node.", file=sys.stderr)
        return 1

    pos, nor, uv, idx = _extract_mesh(bottle)
    pos = _normalize(pos)

    tex_path = project_root / TEXTURE_PATH
    if not tex_path.is_file():
        print(f"Missing texture: {tex_path}", file=sys.stderr)
        return 1
    texture_bytes = tex_path.read_bytes()

    size = pos.max(axis=0) - pos.min(axis=0)
    print(
        f"Exported Bottle: {len(pos)} vertices, {len(idx)//3} triangles, "
        f"size={size.tolist()} m"
    )

    _write_glb(out_path, pos, nor, uv, idx, texture_bytes)
    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
