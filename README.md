<h1 align="center">Captcha Filler</h1>
<p align="center">A macOS menu-bar app that fills text CAPTCHAs with one hotkey.</p>

<p align="center">
  <img alt="Swift" src="https://img.shields.io/badge/swift-6.0%2B-F05138">
  <img alt="macOS" src="https://img.shields.io/badge/platform-macOS-CC785C">
  <img alt="On-device" src="https://img.shields.io/badge/inference-on--device-879A77">
  <img alt="License MIT" src="https://img.shields.io/badge/license-MIT-CC785C">
</p>

Press **⌃⌥C** on a page with a CAPTCHA and it types the answer into the box.
Everything runs on your Mac: Apple Vision OCR plus a local `qwen3.5:4b` model in
[Ollama](https://ollama.com). Nothing is sent anywhere.

## What it handles

- **Distorted-text CAPTCHAs.** Apple's Vision OCR reads the image twice, once as captured and
  once with the strike lines removed, which takes well under a second. When the two readings
  agree, the answer is typed at once. That happened on 28 of 42 test CAPTCHAs, and was wrong
  only once. Otherwise it uses the model's reading, which was started at the same time and
  takes about 1.4 seconds.
- **Arithmetic questions** like "What is 7 + 3?", in page text or in an image.

It needs Ollama running with the model pulled (`ollama pull qwen3.5:4b`). The model is kept in
memory (about 5 GB) while Captcha Filler runs, because loading it takes about 3 seconds; quitting
Captcha Filler unloads it. To free that memory, turn off **Use Qwen Model** in the menu. With the
model off, or Ollama not running, only Apple's OCR is used. When the two
readings differ, a panel shows the CAPTCHA and both readings, and you press 1 or 2 to pick.

Settings, changed with `defaults write local.captchafiller <key> <value>`:

- `OllamaModel <name>`: use a different Ollama model.
- `AlwaysUseModel -bool true`: always wait for the model, skipping the OCR fast path.
- `KeepCase -bool true`: type the reading's own case. By default answers are typed in capitals,
  because the model reads upper and lower case poorly and most CAPTCHAs ignore case.

The toast shows how long each fill took. For a per-step breakdown, run
`log stream --predicate 'subsystem == "local.captchafiller"'`.

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

## License

MIT. See [LICENSE](LICENSE).
