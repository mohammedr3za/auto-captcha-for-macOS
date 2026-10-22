#!/bin/bash
# Builds build/CaptchaFiller.app. With --install, also copies it to ~/Applications and opens it.
#
# macOS ties Accessibility and Screen Recording grants to the code signature. The default
# ad-hoc signature changes on every build, so you'd re-grant both after each rebuild; set
# CODESIGN_IDENTITY to a certificate from `security find-identity -v -p codesigning` to avoid that.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product CaptchaFiller
bin="$(swift build -c release --show-bin-path)/CaptchaFiller"

app=build/CaptchaFiller.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/CaptchaFiller"
cp Resources/Info.plist "$app/Contents/Info.plist"
codesign --force --sign "${CODESIGN_IDENTITY:--}" "$app"
echo "Built $app"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x CaptchaFiller || true
    # Opening while the old copy is still exiting fails with LaunchServices error -600.
    while pgrep -x CaptchaFiller >/dev/null; do sleep 0.2; done
    mkdir -p ~/Applications
    rm -rf ~/Applications/CaptchaFiller.app
    cp -R "$app" ~/Applications/
    open ~/Applications/CaptchaFiller.app
    echo "Installed ~/Applications/CaptchaFiller.app"
fi
