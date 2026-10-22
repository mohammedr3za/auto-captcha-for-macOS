#!/bin/bash
# Builds build/CaptchaFiller.app. With --install, also copies it to ~/Applications and opens it.
#
# macOS ties Accessibility and Screen Recording grants to the code signature. An ad-hoc
# signature changes on every build, so you'd re-grant both after each rebuild. To avoid that,
# put a certificate name from `security find-identity -v -p codesigning` in .codesign-identity
# (git-ignored) or CODESIGN_IDENTITY; without either, the app is signed ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product CaptchaFiller
bin="$(swift build -c release --show-bin-path)/CaptchaFiller"

app=build/CaptchaFiller.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/CaptchaFiller"
cp Resources/Info.plist "$app/Contents/Info.plist"
identity="${CODESIGN_IDENTITY:-$(cat .codesign-identity 2>/dev/null || true)}"
codesign --force --sign "${identity:--}" "$app"
echo "Built $app"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x CaptchaFiller || true
    # Opening while the old copy is still exiting fails with LaunchServices error -600.
    while pgrep -x CaptchaFiller >/dev/null; do sleep 0.2; done
    if [[ "${identity:--}" == "-" ]]; then
        # Grants made for the previous ad-hoc build no longer match: System Settings would show
        # them as on while macOS refuses the app. Clear them so the app can ask again.
        tccutil reset Accessibility local.captchafiller
        tccutil reset ScreenCapture local.captchafiller
    fi
    mkdir -p ~/Applications
    rm -rf ~/Applications/CaptchaFiller.app
    cp -R "$app" ~/Applications/
    open ~/Applications/CaptchaFiller.app
    echo "Installed ~/Applications/CaptchaFiller.app"
fi
