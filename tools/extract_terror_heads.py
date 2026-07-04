"""Extrae cabezas del DAE como OBJ (legacy) o vía Godot runner (recomendado).

Recomendado (meshes embebidos, sin dependencia OBJ):
  godot --headless --path . -s res://scripts/editor/extract_terror_heads_runner.gd

Alternativa editor: abrir scripts/editor/extract_terror_heads.gd → File > Run
"""
from __future__ import annotations

import math
import re
import struct
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DAE_PATH = ROOT / "assets/characters/Personajes_terror/Pesonajes 2.dae"
TEXTURE_DIR = ROOT / "assets/characters/Personajes_terror"
HEAD_MESH_DIR = ROOT / "assets/characters/Personajes_terror/extracted_heads"
OUT_SCENE_DIR = ROOT / "scenes/props/terror_heads"

NS = {"c": "http://www.collada.org/2005/11/COLLADASchema"}

HEADS: tuple[tuple[str, str, str], ...] = (
    ("terror_head_01", "Cube.015", "Cube_015"),
    ("terror_head_02", "Cube.016", "Cube_016"),
    ("terror_head_03", "Cube.034", "Cube_034"),
    ("terror_head_04", "Cube.035", "Cube_035"),
    ("terror_head_05", "Cube.036", "Cube_036"),
    ("terror_head_06", "Cube.037", "Cube_037"),
    ("terror_head_07", "Cube.038", "Cube_038"),
    ("terror_head_08", "Cube.039", "Cube_039"),
    ("terror_head_09", "Cube.041", "Cube_041"),
    ("terror_head_10", "Cube.044", "Cube_044"),
)


def _parse_floats(text: str | None) -> list[float]:
    if not text:
        return []
    return [float(v) for v in text.split()]


def _parse_matrix(text: str | None) -> list[list[float]]:
    vals = _parse_floats(text)
    if len(vals) != 16:
        return [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1],
        ]
    return [
        [vals[0], vals[1], vals[2], vals[3]],
        [vals[4], vals[5], vals[6], vals[7]],
        [vals[8], vals[9], vals[10], vals[11]],
        [vals[12], vals[13], vals[14], vals[15]],
    ]


def _mat4_mul(a: list[list[float]], b: list[list[float]]) -> list[list[float]]:
    out = [[0.0] * 4 for _ in range(4)]
    for r in range(4):
        for c in range(4):
            out[r][c] = sum(a[r][k] * b[k][c] for k in range(4))
    return out


def _transform_point(m: list[list[float]], x: float, y: float, z: float) -> tuple[float, float, float]:
    nx = m[0][0] * x + m[0][1] * y + m[0][2] * z + m[0][3]
    ny = m[1][0] * x + m[1][1] * y + m[1][2] * z + m[1][3]
    nz = m[2][0] * x + m[2][1] * y + m[2][2] * z + m[2][3]
    return nx, ny, nz


def _transform_normal(m: list[list[float]], x: float, y: float, z: float) -> tuple[float, float, float]:
    nx = m[0][0] * x + m[0][1] * y + m[0][2] * z
    ny = m[1][0] * x + m[1][1] * y + m[1][2] * z
    nz = m[2][0] * x + m[2][1] * y + m[2][2] * z
    length = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
    return nx / length, ny / length, nz / length


def _find_child(parent: ET.Element, tag: str) -> ET.Element | None:
    for child in parent:
        if child.tag.endswith(tag):
            return child
    return None


def _findall(parent: ET.Element, tag: str) -> list[ET.Element]:
    return [child for child in parent.iter() if child.tag.endswith(tag)]


def _load_collada() -> ET.ElementTree:
    return ET.parse(DAE_PATH)


def _build_effect_texture_map(root: ET.Element) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for effect in _findall(root, "effect"):
        effect_id = effect.get("id", "")
        image_id = ""
        for init_from in effect.iter():
            if init_from.tag.endswith("init_from") and init_from.text:
                image_id = init_from.text.strip()
                break
        if effect_id and image_id:
            mapping[effect_id] = image_id
    return mapping


def _build_material_map(root: ET.Element, effect_textures: dict[str, str]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for material in _findall(root, "material"):
        mat_id = material.get("id", "")
        inst = _find_child(material, "instance_effect")
        if inst is None:
            continue
        effect_url = inst.get("url", "").lstrip("#")
        tex_id = effect_textures.get(effect_url, "")
        if mat_id and tex_id:
            mapping[mat_id] = tex_id
    return mapping


def _resolve_image_path(image_id: str, root: ET.Element) -> str:
    for image in _findall(root, "image"):
        if image.get("id") != image_id:
            continue
        init_from = _find_child(image, "init_from")
        if init_from is not None and init_from.text:
            name = Path(init_from.text.strip()).name
            return name
    if image_id == "Pe10_001":
        return "Pe10.001.png"
    return f"{image_id}.png"


def _read_geometry(root: ET.Element, geom_url: str) -> dict:
    geom_id = geom_url.lstrip("#")
    geometry = None
    for geo in _findall(root, "geometry"):
        if geo.get("id") == geom_id:
            geometry = geo
            break
    if geometry is None:
        raise RuntimeError(f"Geometría no encontrada: {geom_id}")

    mesh = _find_child(geometry, "mesh")
    if mesh is None:
        raise RuntimeError(f"Sin mesh en {geom_id}")

    positions: list[float] = []
    normals: list[float] = []
    uvs: list[float] = []
    indices: list[int] = []

    sources: dict[str, dict] = {}
    for source in _findall(mesh, "source"):
        source_id = source.get("id", "")
        array_el = _find_child(source, "float_array")
        if array_el is None or array_el.text is None:
            continue
        values = _parse_floats(array_el.text)
        accessor = _find_child(_find_child(source, "technique_common"), "accessor")
        stride = int(accessor.get("stride", "1")) if accessor is not None else 1
        sources[source_id] = {"values": values, "stride": stride}

    vertices = _find_child(mesh, "vertices")
    vertex_source_ids: dict[str, str] = {}
    if vertices is not None:
        for inp in _findall(vertices, "input"):
            semantic = inp.get("semantic", "")
            src = inp.get("source", "").lstrip("#")
            vertex_source_ids[semantic] = src

    triangles = _find_child(mesh, "triangles")
    if triangles is None:
        raise RuntimeError(f"Sin triangles en {geom_id}")

    inputs: list[tuple[int, str, str]] = []
    for inp in _findall(triangles, "input"):
        offset = int(inp.get("offset", "0"))
        semantic = inp.get("semantic", "")
        src = inp.get("source", "").lstrip("#")
        if semantic == "VERTEX":
            src = vertex_source_ids.get("POSITION", src)
        inputs.append((offset, semantic, src))
    inputs.sort(key=lambda item: item[0])

    count = int(triangles.get("count", "0"))
    p_el = _find_child(triangles, "p")
    if p_el is None or p_el.text is None:
        raise RuntimeError(f"Sin índices en {geom_id}")
    raw = [int(v) for v in p_el.text.split()]
    stride = len(inputs)

    def _get_value(source_id: str, index: int) -> list[float]:
        source = sources[source_id]
        s = source["stride"]
        start = index * s
        return source["values"][start : start + s]

    for tri in range(count):
        tri_indices: dict[str, int] = {}
        for offset, semantic, source_id in inputs:
            tri_indices[semantic] = raw[tri * stride + offset]

        pos = _get_value(vertex_source_ids.get("POSITION", inputs[0][2]), tri_indices["VERTEX"])
        positions.extend(pos[:3])

        if "NORMAL" in tri_indices:
            n_src = next(s for off, sem, s in inputs if sem == "NORMAL")
            normal = _get_value(n_src, tri_indices["NORMAL"])
            normals.extend(normal[:3])
        else:
            normals.extend([0.0, 1.0, 0.0])

        if "TEXCOORD" in tri_indices:
            t_src = next(s for off, sem, s in inputs if sem == "TEXCOORD")
            uv = _get_value(t_src, tri_indices["TEXCOORD"])
            uvs.extend(uv[:2])
        else:
            uvs.extend([0.0, 0.0])

        base = tri * 3
        indices.extend([base, base + 1, base + 2])

    return {
        "positions": positions,
        "normals": normals,
        "uvs": uvs,
        "indices": indices,
    }


def _find_scene_node(root: ET.Element, node_id: str) -> ET.Element | None:
    for node in _findall(root, "node"):
        if node.get("id") == node_id:
            return node
    return None


def _extract_head(
    root: ET.Element,
    scene_name: str,
    dae_node_id: str,
    material_map: dict[str, str],
    effect_textures: dict[str, str],
) -> tuple[dict, str]:
    node = _find_scene_node(root, dae_node_id)
    if node is None:
        raise RuntimeError(f"Nodo no encontrado: {dae_node_id} ({scene_name})")

    matrix_el = _find_child(node, "matrix")
    matrix = _parse_matrix(matrix_el.text if matrix_el is not None else None)

    inst = _find_child(node, "instance_geometry")
    if inst is None:
        raise RuntimeError(f"Sin instance_geometry en {dae_node_id}")

    geom_url = inst.get("url", "")
    geo = _read_geometry(root, geom_url)

    mat_symbol = ""
    bind = _find_child(inst, "bind_material")
    if bind is not None:
        inst_mat = _find_child(_find_child(_find_child(bind, "technique_common"), "instance_material"), "instance_material")
        if inst_mat is None:
            for el in bind.iter():
                if el.tag.endswith("instance_material"):
                    inst_mat = el
                    break
        if inst_mat is not None:
            target = inst_mat.get("target", "").lstrip("#")
            mat_symbol = target

    texture_file = "Pe1.png"
    if mat_symbol and mat_symbol in material_map:
        image_id = material_map[mat_symbol]
        texture_file = _resolve_image_path(image_id, root)

    positions = geo["positions"]
    transformed: list[float] = []
    for i in range(0, len(positions), 3):
        tx, ty, tz = _transform_point(matrix, positions[i], positions[i + 1], positions[i + 2])
        transformed.extend([tx, ty, tz])

    normals = geo["normals"]
    transformed_normals: list[float] = []
    for i in range(0, len(normals), 3):
        nx, ny, nz = _transform_normal(matrix, normals[i], normals[i + 1], normals[i + 2])
        transformed_normals.extend([nx, ny, nz])

    xs = transformed[0::3]
    ys = transformed[1::3]
    zs = transformed[2::3]
    cx = (min(xs) + max(xs)) * 0.5
    cy = (min(ys) + max(ys)) * 0.5
    cz = (min(zs) + max(zs)) * 0.5

    centered: list[float] = []
    for i in range(0, len(transformed), 3):
        centered.extend([transformed[i] - cx, transformed[i + 1] - cy, transformed[i + 2] - cz])

    return {
        "positions": centered,
        "normals": transformed_normals,
        "uvs": geo["uvs"],
        "indices": geo["indices"],
        "source_name": dae_node_id,
        "dae_label": node.get("name", dae_node_id),
        "texture_file": texture_file,
    }, texture_file


def _write_obj(head_data: dict, obj_path: Path, mtl_name: str) -> None:
    positions = head_data["positions"]
    normals = head_data["normals"]
    uvs = head_data["uvs"]
    indices = head_data["indices"]

    lines = [f"mtllib {mtl_name}", f"g {head_data['source_name']}"]
    for i in range(0, len(positions), 3):
        lines.append(f"v {positions[i]:.6f} {positions[i + 1]:.6f} {positions[i + 2]:.6f}")
    for i in range(0, len(uvs), 2):
        lines.append(f"vt {uvs[i]:.6f} {uvs[i + 1]:.6f}")
    for i in range(0, len(normals), 3):
        lines.append(f"vn {normals[i]:.6f} {normals[i + 1]:.6f} {normals[i + 2]:.6f}")

    vert_count = len(positions) // 3
    lines.append("usemtl head_mat")
    for i in range(0, len(indices), 3):
        a, b, c = indices[i] + 1, indices[i + 1] + 1, indices[i + 2] + 1
        lines.append(f"f {a}/{a}/{a} {b}/{b}/{b} {c}/{c}/{c}")

    obj_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_mtl(mtl_path: Path, texture_file: str) -> None:
    tex_path = TEXTURE_DIR / texture_file
    content = (
        "newmtl head_mat\n"
        "Ka 1.000 1.000 1.000\n"
        "Kd 1.000 1.000 1.000\n"
        "Ks 0.000 0.000 0.000\n"
        "d 1.0\n"
        "illum 1\n"
        f"map_Kd ../{texture_file}\n"
    )
    mtl_path.write_text(content, encoding="utf-8")
    if not tex_path.exists():
        print(f"Warning: textura no encontrada {tex_path}")


def _write_tscn(scene_name: str, obj_path: Path, texture_file: str, dae_label: str) -> None:
    rel_mesh = obj_path.relative_to(ROOT).as_posix()
    rel_tex = (TEXTURE_DIR / texture_file).relative_to(ROOT).as_posix()
    scene_path = OUT_SCENE_DIR / f"{scene_name}.tscn"
    root_name = scene_name.replace("_", " ").title().replace(" ", "")
    content = f"""[gd_scene load_steps=4 format=3]

[ext_resource type="ArrayMesh" path="res://{rel_mesh}" id="1_mesh"]
[ext_resource type="Texture2D" path="res://{rel_tex}" id="2_tex"]

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_head"]
resource_name = "{dae_label}"
albedo_texture = ExtResource("2_tex")

[node name="{root_name}" type="Node3D"]

[node name="Model" type="MeshInstance3D" parent="."]
mesh = ExtResource("1_mesh")
surface_material_override/0 = SubResource("StandardMaterial3D_head")
"""
    scene_path.write_text(content, encoding="utf-8")


def main() -> None:
    if not DAE_PATH.exists():
        raise SystemExit(f"No existe {DAE_PATH}")

    HEAD_MESH_DIR.mkdir(parents=True, exist_ok=True)
    OUT_SCENE_DIR.mkdir(parents=True, exist_ok=True)

    tree = _load_collada()
    root = tree.getroot()
    effect_textures = _build_effect_texture_map(root)
    material_map = _build_material_map(root, effect_textures)

    print(f"Extrayendo desde {DAE_PATH.name}")
    for scene_name, dae_label, dae_node_id in HEADS:
        head_data, texture_file = _extract_head(
            root, scene_name, dae_node_id, material_map, effect_textures
        )
        obj_path = HEAD_MESH_DIR / f"{scene_name}.obj"
        mtl_path = HEAD_MESH_DIR / f"{scene_name}.mtl"
        _write_obj(head_data, obj_path, mtl_path.name)
        _write_mtl(mtl_path, texture_file)
        _write_tscn(scene_name, obj_path, texture_file, dae_label)
        vert_count = len(head_data["positions"]) // 3
        tri_count = len(head_data["indices"]) // 3
        print(
            f"  {scene_name} <- {dae_label} ({dae_node_id}) "
            f"| {vert_count} verts, {tri_count} tris | tex {texture_file}"
        )

    print(f"\nListo: {len(HEADS)} escenas en {OUT_SCENE_DIR}")


if __name__ == "__main__":
    main()
