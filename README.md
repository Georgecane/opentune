# OpenTune

**OpenTune** is a modern, cross-platform digital audio workstation (DAW) built with [TypeScript](https://www.typescriptlang.org/), [React](https://react.dev/), [Electron](https://www.electronjs.org/), and [Bun](https://bun.sh/).
Inspired by the elegance of Apple's Logic Pro and GarageBand, OpenTune features a beautiful macOS-style interface powered by [@codedgar/Puppertino](https://github.com/codedgar/Puppertino).

---

## ✨ Features

- 🎹 **Apple-inspired UI/UX** – Modern, clean, and intuitive, powered by [@codedgar/Puppertino](https://github.com/codedgar/Puppertino)
- 🎛️ **Multi-track Audio & MIDI Editing**
- 🧩 **Plugin Support** – WebAudio, WASM, and (planned) native VST/CLAP plugins via modern native bridges
- 🖥️ **Native Features** – Deep OS integration for audio, MIDI, file system, and more, using Electron and Bun-compatible native packages
- 🎼 **Piano Roll, Step Sequencer, Mixer, Automation**
- 🔄 **Cross-platform**: macOS, Windows, Linux
- 🏃‍♂️ **Fast, Extensible**: Bun runtime, hot reload, modular codebase, robust plugin API
- ☁️ **Project Save/Load, Export, and More**

---

## 🚀 Getting Started

1. **Clone the repo:**
    ```sh
    git clone https://github.com/Georgecane/opentune.git
    cd opentune
    ```

2. **Install dependencies (with Bun):**
    ```sh
    bun install
    ```

3. **Start in development mode:**
    ```sh
    bun run dev
    ```

4. **Build for production:**
    ```sh
    bun run build
    # To package the desktop app:
    bun run dist
    ```

---

## 🖥️ Screenshots

> ![Screenshot](docs/screenshot2.png)
> _A Mac-inspired interface with multi-track editing and plugin support_

---

## 🧩 Plugins

- OpenTune supports **WebAudio plugins** and will support native VST/CLAP plugins via modern native bridges.
- Want to build a plugin? See [docs/plugin-dev.md](docs/plugin-dev.md)

---

## 🛠️ Tech Stack

- [TypeScript](https://www.typescriptlang.org/)
- [React](https://react.dev/)
- [@codedgar/Puppertino](https://github.com/codedgar/Puppertino)
- [Electron](https://www.electronjs.org/)
- [Bun](https://bun.sh/)
- [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [Web MIDI API](https://developer.mozilla.org/en-US/docs/Web/API/Web_MIDI_API)
- [Node/Bun Native Packages](https://bun.sh/docs/ecosystem/native)
- [Sass](https://sass-lang.com/) / [styled-components](https://styled-components.com/)
- [Prettier](https://prettier.io/) + [ESLint](https://eslint.org/)

---

## 🤝 Contributing

- PRs and feedback are welcome!
- See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## 📄 License

Apache 2.0

---

**OpenTune** is built by [@Georgecane](https://github.com/Georgecane) and contributors.
