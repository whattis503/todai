#!/bin/bash
# Post-build script to disable service worker in Flutter web build

BUILD_DIR="/home/user/flutter_app/build/web"

echo "Post-build: Disabling service worker..."

# 1. Modify flutter_bootstrap.js to remove serviceWorkerSettings using Python
if [ -f "$BUILD_DIR/flutter_bootstrap.js" ]; then
  python3 << EOF
import re

with open('$BUILD_DIR/flutter_bootstrap.js', 'r') as f:
    content = f.read()

# Remove serviceWorkerSettings from the load call
content = re.sub(
    r'_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{[^}]*\}\s*\}\);',
    '_flutter.loader.load({});',
    content
)

with open('$BUILD_DIR/flutter_bootstrap.js', 'w') as f:
    f.write(content)

print("  - Modified flutter_bootstrap.js")
EOF
fi

# 2. Delete the service worker file to prevent any registration
if [ -f "$BUILD_DIR/flutter_service_worker.js" ]; then
  rm -f "$BUILD_DIR/flutter_service_worker.js"
  echo "  - Removed flutter_service_worker.js"
fi

# 3. Update manifest.json to remove service worker reference (if any)
if [ -f "$BUILD_DIR/manifest.json" ]; then
  sed -i '/"serviceworker"/d' "$BUILD_DIR/manifest.json"
  echo "  - Cleaned manifest.json"
fi

echo "Post-build: Service worker disabled successfully!"
