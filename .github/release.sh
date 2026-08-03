#!/bin/bash
set -e

if [ ! -f "$HOME/mihomo-ipk/BUILD_INFO" ]; then
  echo "BUILD_INFO not found"; exit 1
fi
. "$HOME/mihomo-ipk/BUILD_INFO"

TAG="mihomo-${MIHOMO_BRANCH}-${MIHOMO_VERSION}"
TITLE="Mihomo IPK ${MIHOMO_DISPLAY_VERSION} (${MIHOMO_BRANCH})"
NOTES="Built from: ${MIHOMO_SOURCE}
Branch: ${MIHOMO_BRANCH}
Version: ${MIHOMO_DISPLAY_VERSION}
Commit: ${MIHOMO_COMMIT}
Architectures: aarch64-3.10, mipsel-3.4 (Entware / Keenetic)"

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Release $TAG already exists, skipping creation."
else
  gh release create "$TAG" "$HOME"/mihomo-ipk/*.ipk --title "$TITLE" --notes "$NOTES"
  echo "Release created: $TAG"
fi
