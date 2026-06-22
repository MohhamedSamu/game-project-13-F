#!/usr/bin/env python3
"""Extract electric_pole_03.002 (+ lamp head) from Tacos.glb into a minimal GLB."""

from __future__ import annotations

import json
import struct
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Original Tacos.glb is no longer bundled in the repo (see assets/models/streetlamp/).
# To re-run extraction, restore Tacos.glb at this path temporarily.
SRC = ROOT / "assets/models/tacos/Models/Tacos.glb"
DST_DIR = ROOT / "assets/models/streetlamp"
DST = DST_DIR / "streetlamp.glb"

POLE_NODE_INDEX = 272
LAMP_NODE_INDEX = 271
POLE_MESH_INDEX = 272
LAMP_MESH_INDEX = 271
MATERIAL_INDICES = [90, 82, 89]  # metal_bare, Metal_02, Light
TEXTURE_INDICES = [92, 83, 90, 91]  # metal_bare, Metal_02, Light_Emissor, Light
IMAGE_INDICES = [91, 82, 89, 90]
BASE_Y_OFFSET = 0.15009212493896484  # move pole base to Y=0


def load_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    chunk_len = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20 : 20 + chunk_len])
    bin_offset = 20 + chunk_len + 8
    bin_len = struct.unpack_from("<I", data, 20 + chunk_len)[0]
    bin_chunk = data[bin_offset : bin_offset + bin_len]
    return gltf, bin_chunk


def accessor_slice(gltf: dict, bin_chunk: bytes, accessor_index: int) -> bytes:
    acc = gltf["accessors"][accessor_index]
    bv = gltf["bufferViews"][acc["bufferView"]]
    comp_type = acc["componentType"]
    type_name = acc["type"]
    count = acc["count"]

    type_components = {
        "SCALAR": 1,
        "VEC2": 2,
        "VEC3": 3,
        "VEC4": 4,
        "MAT4": 16,
    }
    comp_sizes = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
    elem_size = comp_sizes[comp_type] * type_components[type_name]
    byte_length = count * elem_size

    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = bv.get("byteStride", elem_size)
    if stride == elem_size:
        return bin_chunk[start : start + byte_length]

    out = bytearray()
    for i in range(count):
        out.extend(bin_chunk[start + i * stride : start + i * stride + elem_size])
    return bytes(out)


def remap_material_index(old_index: int | None, material_map: dict[int, int]) -> int | None:
    if old_index is None:
        return None
    return material_map[old_index]


def main() -> None:
    if not SRC.exists():
        raise FileNotFoundError(
            f"Source not found: {SRC}\n"
            "The Tacos asset was removed from the project after extraction.\n"
            "Restore Tacos.glb at that path to re-run, or use the existing streetlamp.glb."
        )
    gltf, bin_chunk = load_glb(SRC)
    meshes = gltf["meshes"]
    nodes = gltf["nodes"]
    materials = gltf["materials"]
    textures = gltf["textures"]
    images = gltf["images"]
    samplers = gltf.get("samplers", [{"magFilter": 9729, "minFilter": 9987}])

    pole_node = nodes[POLE_NODE_INDEX]
    lamp_node = nodes[LAMP_NODE_INDEX]

    material_map = {old: new for new, old in enumerate(MATERIAL_INDICES)}
    texture_map = {old: new for new, old in enumerate(TEXTURE_INDICES)}
    image_map = {old: new for new, old in enumerate(IMAGE_INDICES)}

    new_bin = bytearray()
    new_buffer_views: list[dict] = []
    new_accessors: list[dict] = []
    new_images: list[dict] = []
    new_textures: list[dict] = []
    new_materials: list[dict] = []
    new_meshes: list[dict] = []

    def append_bytes(raw: bytes, target: int = 34962) -> int:
        offset = (len(new_bin) + 3) & ~3
        if offset > len(new_bin):
            new_bin.extend(b"\x00" * (offset - len(new_bin)))
        start = len(new_bin)
        new_bin.extend(raw)
        bv_index = len(new_buffer_views)
        new_buffer_views.append(
            {
                "buffer": 0,
                "byteOffset": start,
                "byteLength": len(raw),
                "target": target,
            }
        )
        return bv_index

    def copy_accessor(old_index: int, accessor_type: str | None = None) -> int:
        old_acc = gltf["accessors"][old_index]
        raw = accessor_slice(gltf, bin_chunk, old_index)
        bv_index = append_bytes(raw, target=34963 if old_acc["type"] == "SCALAR" else 34962)
        new_acc = {
            "bufferView": bv_index,
            "componentType": old_acc["componentType"],
            "count": old_acc["count"],
            "type": old_acc["type"],
        }
        if "min" in old_acc:
            new_acc["min"] = deepcopy(old_acc["min"])
        if "max" in old_acc:
            new_acc["max"] = deepcopy(old_acc["max"])
        if accessor_type:
            new_acc["type"] = accessor_type
        new_accessors.append(new_acc)
        return len(new_accessors) - 1

    def remap_texture_refs(obj):
        if isinstance(obj, dict):
            out = {}
            for key, value in obj.items():
                if key == "index" and isinstance(value, int) and value in texture_map:
                    out[key] = texture_map[value]
                else:
                    out[key] = remap_texture_refs(value)
            return out
        if isinstance(obj, list):
            return [remap_texture_refs(v) for v in obj]
        return obj

    for image_index in IMAGE_INDICES:
        image = images[image_index]
        if "bufferView" in image:
            bv = gltf["bufferViews"][image["bufferView"]]
            start = bv.get("byteOffset", 0)
            end = start + bv["byteLength"]
            raw = bin_chunk[start:end]
            bv_index = append_bytes(raw, target=None)
            new_images.append(
                {
                    "bufferView": bv_index,
                    "mimeType": image["mimeType"],
                    "name": image.get("name", ""),
                }
            )
        else:
            new_images.append(deepcopy(image))

    for texture_index in TEXTURE_INDICES:
        tex = deepcopy(textures[texture_index])
        tex["source"] = image_map[tex["source"]]
        new_textures.append(tex)

    for material_index in MATERIAL_INDICES:
        mat = remap_texture_refs(deepcopy(materials[material_index]))
        new_materials.append(mat)

    def offset_positions(accessor_index: int, y_offset: float) -> None:
        import array

        acc = new_accessors[accessor_index]
        acc["min"][1] += y_offset
        acc["max"][1] += y_offset
        bv = new_buffer_views[acc["bufferView"]]
        start = bv["byteOffset"]
        count = acc["count"]
        floats = array.array("f")
        floats.frombytes(bytes(new_bin[start : start + count * 12]))
        for i in range(1, len(floats), 3):
            floats[i] += y_offset
        new_bin[start : start + count * 12] = floats.tobytes()

    def copy_mesh(mesh_index: int, y_offset: float = 0.0) -> int:
        mesh = meshes[mesh_index]
        new_primitives = []
        for prim in mesh["primitives"]:
            attrs = {}
            for attr_name, accessor_index in prim["attributes"].items():
                attrs[attr_name] = copy_accessor(accessor_index)
                if attr_name == "POSITION" and y_offset:
                    offset_positions(attrs[attr_name], y_offset)
            new_prim = {"attributes": attrs}
            if "indices" in prim:
                new_prim["indices"] = copy_accessor(prim["indices"])
            new_prim["material"] = remap_material_index(prim.get("material"), material_map)
            new_primitives.append(new_prim)

        new_meshes.append({"name": mesh.get("name", ""), "primitives": new_primitives})
        return len(new_meshes) - 1

    pole_mesh = copy_mesh(POLE_MESH_INDEX, BASE_Y_OFFSET)
    lamp_mesh = copy_mesh(LAMP_MESH_INDEX, BASE_Y_OFFSET)

    lamp_translation = lamp_node.get("translation", [0.0, 0.0, 0.0])
    lamp_translation = [
        lamp_translation[0],
        lamp_translation[1] + BASE_Y_OFFSET,
        lamp_translation[2],
    ]

    new_nodes = [
        {
            "name": "StreetLampModel",
            "children": [1],
        },
        {
            "name": "electric_pole_03",
            "children": [2],
            "mesh": pole_mesh,
        },
        {
            "name": "LampHead",
            "mesh": lamp_mesh,
            "translation": lamp_translation,
        },
    ]

    out_gltf = {
        "asset": {"version": "2.0", "generator": "extract_streetlamp_glb.py"},
        "scene": 0,
        "scenes": [{"name": "StreetLamp", "nodes": [0]}],
        "nodes": new_nodes,
        "meshes": new_meshes,
        "materials": new_materials,
        "textures": new_textures,
        "images": new_images,
        "samplers": samplers[:2] if len(samplers) >= 2 else samplers,
        "buffers": [{"byteLength": len(new_bin)}],
        "bufferViews": new_buffer_views,
        "accessors": new_accessors,
    }

    DST_DIR.mkdir(parents=True, exist_ok=True)
    json_bytes = json.dumps(out_gltf, separators=(",", ":")).encode("utf-8")
    json_pad = (4 - (len(json_bytes) % 4)) % 4
    json_bytes += b" " * json_pad
    bin_pad = (4 - (len(new_bin) % 4)) % 4
    new_bin.extend(b"\x00" * bin_pad)

    total_length = 12 + 8 + len(json_bytes) + 8 + len(new_bin)
    header = struct.pack("<4sII", b"glTF", 2, total_length)
    json_chunk = struct.pack("<I4s", len(json_bytes), b"JSON") + json_bytes
    bin_chunk_out = struct.pack("<I4s", len(new_bin), b"BIN\x00") + bytes(new_bin)
    DST.write_bytes(header + json_chunk + bin_chunk_out)
    print(f"Wrote {DST} ({DST.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
