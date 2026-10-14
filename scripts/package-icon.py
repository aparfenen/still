from pathlib import Path
import struct
import sys
source, target = Path(sys.argv[1]), Path(sys.argv[2])
parts = []
for tag, name in [('icp4','icon_16x16.png'), ('icp5','icon_32x32.png'), ('icp6','icon_32x32@2x.png'), ('ic07','icon_128x128.png'), ('ic08','icon_256x256.png'), ('ic09','icon_512x512.png'), ('ic10','icon_512x512@2x.png')]:
    data = (source / name).read_bytes()
    parts.append(tag.encode() + struct.pack('>I', len(data) + 8) + data)
body = b''.join(parts)
target.write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
