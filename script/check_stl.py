#!/usr/bin/env python3
"""STL が水密かどうかを trimesh で検査する。

使い方: python3 script/check_stl.py tmp/stl/*.stl
必要なもの: pip install trimesh numpy scipy networkx
"""
import sys

import trimesh


def check(path):
    mesh = trimesh.load(path, force="mesh")
    parts = mesh.split(only_watertight=False)
    problems = []
    if not mesh.is_watertight:
        problems.append("全体が水密でない")
    if not mesh.is_winding_consistent:
        problems.append("面の向きがそろっていない")
    for i, part in enumerate(parts):
        if not part.is_watertight:
            problems.append(f"シェル{i}が水密でない")
        elif part.volume <= 0:
            problems.append(f"シェル{i}の法線が内向き")
    size = mesh.bounds[1] - mesh.bounds[0]
    status = "OK" if not problems else "NG: " + ", ".join(problems)
    print(f"{path}: {len(mesh.faces)} 三角形, シェル {len(parts)} 個, "
          f"{size[0]:.1f} x {size[1]:.1f} x {size[2]:.1f} mm, 底 z={mesh.bounds[0][2]:.3f} -> {status}")
    return not problems


if __name__ == "__main__":
    results = [check(path) for path in sys.argv[1:]]
    sys.exit(0 if results and all(results) else 1)
