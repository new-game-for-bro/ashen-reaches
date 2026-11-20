import glob, json, os, struct

for path in sorted(glob.glob("models/**/*.glb", recursive=True)):
    try:
        with open(path, "rb") as f:
            header = f.read(12)
            magic, version, total = struct.unpack("<4sII", header)
            if magic != b"glTF" or version != 2:
                raise ValueError("not a GLB 2.0 file (possibly an LFS pointer)")
            length, kind = struct.unpack("<I4s", f.read(8))
            if kind != b"JSON":
                raise ValueError("missing JSON chunk")
            data = json.loads(f.read(length))
        meshes = data.get("meshes", [])
        accessors = data.get("accessors", [])
        triangles = 0
        verts = 0
        for mesh in meshes:
            for primitive in mesh.get("primitives", []):
                position = primitive.get("attributes", {}).get("POSITION")
                if position is not None:
                    verts += accessors[position].get("count", 0)
                index = primitive.get("indices", position)
                if index is not None and primitive.get("mode", 4) == 4:
                    triangles += accessors[index].get("count", 0) // 3
        print(f"{path} | bytes={total} | meshes={len(meshes)} | vertices={verts} | triangles={triangles} | images={len(data.get('images', []))} | skins={len(data.get('skins', []))} | animations={len(data.get('animations', []))}")
    except Exception as exc:
        print(f"{path} | ERROR: {exc}")
        raise
