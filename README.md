# Captcha Filler

A macOS menu bar app that fills in text CAPTCHAs. Press **⌃⌥C** on a page with a
CAPTCHA and it types the answer into the CAPTCHA box. It never presses Enter.

Everything runs on your Mac: Apple's Vision framework reads the text, and nothing is sent anywhere.

## What it handles

- **Distorted-text CAPTCHAs.** It reads the image twice, once as captured and once after
  stripping thin strike lines and speckles. If the two readings agree, it types the answer.
  If they don't, a small panel shows the CAPTCHA and both readings; press 1 or 2 to pick.
- **Arithmetic questions** like "What is 7 + 3?", in page text or in an image.

It finds the CAPTCHA automatically in **Safari**. In other apps, or when it can't find one,
a crosshair appears: drag a box around the CAPTCHA and it types into whichever box you have
selected. If no text box is selected, it copies the answer to the clipboard instead.

## Install

```sh
scripts/build-app.sh --install     # builds, copies to ~/Applications, launches
```

On first use, grant **Accessibility** and **Screen Recording** from the menu bar icon, then
choose **Relaunch to Apply Permissions**. With the default ad-hoc signature, the grants don't
carry over to a rebuilt app, so `--install` clears them and you grant both again; see the note in
`scripts/build-app.sh` to sign with a certificate instead.

## Try it

Open `testpage/index.html` (an image CAPTCHA) and `testpage/math.html` (a question) in Safari,
then press ⌃⌥C.

## When it misreads

**Show Last Capture** in the menu opens the last captured CAPTCHA and its cleaned-up version.
Look-alike characters (`O`/`0`, `I`/`l`/`1`, `6`/`G`) cause most of the misses.

## Development

```sh
swift test      # logic tests, plus OCR on 20 sample CAPTCHAs in Tests/CaptchaCoreTests/Fixtures
```

With only the Command Line Tools installed (no Xcode), point SwiftPM at Swift Testing:

```sh
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
swift test -Xswiftc -F -Xswiftc $F -Xlinker -F -Xlinker $F -Xlinker -rpath -Xlinker $F \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib
```

- `Sources/CaptchaCore` is the logic: OCR (`TextReader`), cleanup (`ImageCleaner`), deciding
  between readings (`AnswerPicker`), arithmetic (`MathSolver`), and finding the CAPTCHA on a
  page (`CaptchaLocator`).
- `Sources/CaptchaFiller` is the app: the hotkey, reading Safari's accessibility tree
  (`SafariSnapshot`), typing (`Typist`), and the overlay and panels.
