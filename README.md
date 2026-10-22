# Captcha Filler

A macOS menu bar app that fills in text CAPTCHAs. Press **⌃⌥C** on a page with a
CAPTCHA and it types the answer into the CAPTCHA box. It never presses Enter.

Everything runs on your Mac and nothing is sent anywhere. A vision-language model,
`qwen3.5:4b` running in [Ollama](https://ollama.com), reads the CAPTCHA. It read 40 of 42 test
CAPTCHAs, including real ones that Apple's OCR got wrong.

## What it handles

- **Distorted-text CAPTCHAs.** The model's reading is typed straight in.
- **Arithmetic questions** like "What is 7 + 3?", in page text or in an image.

It needs Ollama running with the model pulled (`ollama pull qwen3.5:4b`). To use a different
model: `defaults write local.captchafiller OllamaModel <name>`. Answers are typed in capitals,
because the model reads upper and lower case poorly and most CAPTCHAs ignore case. For a site
that checks case: `defaults write local.captchafiller KeepCase -bool true`. When Ollama isn't running, it
falls back to Apple's Vision OCR, which is less accurate. That reads the image twice, once as
captured and once with the strike lines removed. When the two readings differ, a panel shows
the CAPTCHA and both readings, and you press 1 or 2 to pick.

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
