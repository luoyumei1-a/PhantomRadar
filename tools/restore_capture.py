"""Restore the published numeric capture before running its IQ analysis."""
import hashlib
import json
from pathlib import Path
import tempfile

def restore():
    data = Path(__file__).resolve().parents[1] / "data"
    parts = data / "native_parts"
    manifest = json.loads((parts / "parts.json").read_text())
    destination = data / manifest["output"]
    if destination.exists():
        if hashlib.sha256(destination.read_bytes()).hexdigest() == manifest["sha256"]:
            return destination
        raise FileExistsError(f"An existing capture has a different hash: {destination}")
    combined = hashlib.sha256()
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=data, delete=False) as target:
            temporary = Path(target.name)
            for entry in manifest["parts"]:
                content = (parts / entry["name"]).read_bytes()
                if len(content) != entry["bytes"] or hashlib.sha256(content).hexdigest() != entry["sha256"]:
                    raise ValueError(f"Capture part failed verification: {entry['name']}")
                target.write(content)
                combined.update(content)
        if temporary.stat().st_size != manifest["bytes"] or combined.hexdigest() != manifest["sha256"]:
            raise ValueError("Assembled capture failed verification")
        temporary.replace(destination)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return destination

if __name__ == "__main__":
    print(restore())
