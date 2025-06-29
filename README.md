# OpenTune

**OpenTune** is a modern, open-source digital audio workstation (DAW) designed for Linux, with a focus on the GNOME desktop environment.  
Inspired by the workflows and aesthetics of Ableton Live and Logic Pro X, OpenTune provides a powerful, intuitive, and visually appealing audio production experience natively on Linux.

---

## ✨ Features

- 🎚️ **Professional UI**: Arrangement and session views inspired by Ableton Live and Logic Pro X, using GTK4 and Libadwaita for seamless GNOME integration
- 🎛️ **Multi-track Audio and MIDI Editing**
- 🧩 **Native Plugin Support**: VST, CLAP, LV2, and more via high-performance Rust crates
- 🎹 **Piano Roll, Step Sequencer, Mixer, Automation**
- 🔗 **Deep System Integration**: Native file dialogs, drag-and-drop, and theming on GNOME
- 🏃‍♂️ **Efficient and Safe**: Built in Rust for reliability and performance

---

## 🚀 Getting Started

### **Prerequisites**

- [Rust](https://www.rust-lang.org/tools/install) (latest stable)
- [GNOME Builder](https://apps.gnome.org/app/org.gnome.Builder/) or your favorite Rust IDE
- GTK4 and Libadwaita development libraries (install via your distro's package manager)
- (Optional) Plugin SDKs: VST, CLAP, LV2 headers for development

### **Build Instructions**

```sh
git clone https://github.com/Georgecane/opentune.git
cd opentune
cargo build --release
```

### **Run OpenTune**

```sh
cargo run
```

---

## 🛠️ Tech Stack

- **Language:** [Rust](https://www.rust-lang.org/)
- **UI:** [GTK4](https://www.gtk.org/) + [Libadwaita](https://gnome.pages.gitlab.gnome.org/libadwaita/)
- **Audio Engine:** Native Rust DSP, [nih-plug](https://github.com/robbert-vdh/nih-plug), [clap](https://github.com/free-audio/clap), [vst-rs](https://github.com/RustAudio/vst-rs), [lv2](https://github.com/RustAudio/rust-lv2)
- **MIDI:** [midir](https://github.com/Boddlnagg/midir)
- **Plugin Support:** VST2/3, CLAP, LV2 (and more planned)
- **Build System:** Cargo

---

## 🧩 Plugin Development

- Write plugins in Rust or C/C++ using supported SDKs (VST, CLAP, LV2)
- See [docs/plugin-dev.md](docs/plugin-dev.md) for details

---

## 🖥️ Screenshots

> _Coming soon: Screenshots of OpenTune’s GNOME-native UI!_

---

## 🤝 Contributing

- Contributions, issues, and feature requests are welcome!
- See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines

---

## 📄 License

Apache 2.0

---

OpenTune is built by [@Georgecane](https://github.com/Georgecane) and contributors.
