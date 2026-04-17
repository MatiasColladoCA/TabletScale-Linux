# TabletScale-Linux 🖊️

**TabletScale-Linux** is a lightweight script designed to fix hypersensitivity and aspect ratio distortions in generic graphic tablets (Gadnic, Huion, Ugee, XP-Pen) when used on Linux (X11).

---

## Technical Context: Why `xsetwacom` fails

Generic tablets (often identified as `SZ PING-IT INC.` or using `Gotop` chipsets) are managed in Linux by the core kernel driver `hid-generic`. 
* **The Limitation:** Industry-standard tools like `xsetwacom` or `OpenTabletDriver` require specific drivers (like `wacom`) or dedicated report parsers. When using `hid-generic`, the tablet remains "invisible" to these specialized tools.
* **The Solution:** This script interacts directly with the X11 server via `xinput`, modifying the **Coordinate Transformation Matrix**, bypassing the need for proprietary drivers.

### Hardware Fragmentation
When connected, the operating system doesn't recognize the tablet as a single entity; instead, it fragments it into multiple virtual interfaces. You can verify this by running `xinput list`.

* **The Pen (Stylus):** Controls the cursor, pressure, and scaling. (**Target of this script**).
* **The Buttons (Pad):** Registered as an independent **Keyboard** device (e.g., `T505 Graphic Tablet Keyboard`).

### Practical Example: Analyzing `xinput` Output

Let's look at a real-world case using a Gadnic T505. Running `xinput list` yields:

```bash
⎡ Virtual core pointer                     id=2    [master pointer  (3)]
⎜   ↳ SZ PING-IT INC. T505 Graphic Tablet Mouse           id=16   [slave  pointer  (2)]
⎜   ↳ SZ PING-IT INC. T505 Graphic Tablet Keyboard        id=18   [slave  pointer  (2)]
⎜   ↳ SZ PING-IT INC. T505 Graphic Tablet Pen (0)         id=21   [slave  pointer  (2)]
⎜   ↳ input-remapper SZ PING-IT INC... forwarded          id=22   [slave  pointer  (2)]
⎣ Virtual core keyboard                    id=3    [master keyboard (2)]
    ↳ SZ PING-IT INC. T505 Graphic Tablet                 id=17   [slave  keyboard (3)]
    ↳ SZ PING-IT INC. T505 Graphic Tablet Keyboard        id=19   [slave  keyboard (3)]
    ↳ SZ PING-IT INC. T505 Graphic Tablet                 id=20   [slave  keyboard (3)]
    ↳ input-remapper SZ PING-IT INC... forwarded          id=23   [slave  keyboard (3)]
```

Although you have a single physical device, X11 splits it into two main categories:

1. **The Drawing Area (Pointer):** Look under the `Virtual core pointer` section. The device we need for scaling and rotation is the one containing the word **"Pen"** (in this case, `id=21`). Ignore "Mouse" or "Keyboard" entries in this section.
   * *This is the device configured by TabletScale-Linux.*

2. **The Physical Buttons (Keyboard):** Look under the `Virtual core keyboard` section. The side buttons don't send mouse clicks; they send keycodes (e.g., F13 or the letter 'B'). Here, the device processing those strokes is `id=19` (Tablet Keyboard).
   * *This is the device you should select in software like `input-remapper` to configure your shortcuts.*

**Note on input-remapper:** Entries marked as `forwarded` (IDs 22 and 23) are virtual devices created by the remapping software to inject your shortcuts. **Never** use these IDs to configure the tablet directly; always use the original hardware devices.

---

## The Problem
By default, Linux maps the entire surface of your tablet to the entire surface of your monitor. If your monitor is significantly larger than your tablet, a **1 cm** physical stroke becomes **3 cm** on screen. This destroys precision and muscle memory, forcing you to draw or write in a "microscopic" scale.

## The Solution: 1:1 Physical Scaling
This script automatically calculates the **Coordinate Transformation Matrix** based on the real-world dimensions (in centimeters) of your devices. If you draw a 5 cm circle on your tablet, you get a 5 cm circle on your screen, positioned exactly where you choose (center or corners).

---

## Installation & Requirements

Ensure you have the necessary dependencies installed:
```bash
sudo apt update
sudo apt install xinput bc libnotify-bin
```

Clone the repository:
```bash
git clone https://github.com/your-username/TabletScale-Linux.git
cd TabletScale-Linux
chmod +x tablet-transformer.sh
```

---

## 🛠️ Usage

1. **Identify your device:**
   Run `xinput list` and find the name of your Stylus/Pen. 
   > *Example: "SZ PING-IT INC. T505 Graphic Tablet Pen (0)"*

2. **Run the configurator:**
   ```bash
   ./tablet-transformer.sh
   ```

3. **Input your data:**
   * **Tablet Dimensions:** The active area (measure it with a ruler).
   * **Monitor Dimensions:** The visible area of your screen.
   * **Position:** Choose if you want the active area centered or anchored to a corner (useful for reaching software toolbars in Krita, GIMP, or Xournal++).
   * **Orientation:** Apply rotation (e.g., 90° for vertical use/left-handed mode).

---

## ⚙️ Automation (Create a Launcher)

To avoid running the script manually every time, create a `.desktop` file in `~/.local/share/applications/tablet.desktop`. Use the full path instead of `~`:

```ini
[Desktop Entry]
Type=Application
Name=Tablet Config 1:1
Exec=/full/path/to/your/script/tablet-transformer.sh
Icon=preferences-desktop-display
Terminal=true
Categories=Utility;
```

---

## 📈 How the Magic Works

The script uses linear algebra to inject values into the X11 transformation matrix. The core formula is:

$$Scale = \frac{Tablet_{cm}}{Monitor_{cm}}$$

The resulting matrix is applied via:
`xinput set-prop <ID> "Coordinate Transformation Matrix" <matrix>`

---

## 🎛️ Configuring Side Buttons (Shortcuts)

While `TabletScale-Linux` handles pen scaling, configuring physical buttons requires a different approach due to hardware fragmentation.

* **(1) Observed Symptom:** Commands like `xinput set-button-map` fail or have no effect on physical side buttons.
* **(2) Probable Diagnosis:** Side buttons emit **keycodes** (keyboard events) rather than mouse button events.
* **(3) Diagnostic Tests:**
  1. Identify the Tablet "Keyboard" ID using `xinput list`.
  2. Run `xinput test <ID>` (e.g., `xinput test 18`).
  3. Press a physical button. The output will show `key press 64`.
* **(4) Suggested Solution:** Use `input-remapper` to intercept these keycodes and assign them to shortcuts.
  ```bash
  sudo apt install input-remapper input-remapper-gtk
  ```

---

## Implementation History & Known Limitations

For developers looking to extend compatibility, these are the approaches that **do not work** with `Gotop / PING-IT` hardware under the `hid-generic` driver:

| Attempted Method | Result | Technical Reason |
| :--- | :--- | :--- |
| **Digimend-dkms** | Compilation Error | Source code lacks support for modern kernel timing functions (e.g., `del_timer_sync` error). |
| **OpenTabletDriver** | Device Ignored | Missing specific report parser for this chipset. `hid-generic` does not release the device for user-level capture. |
| **10moons/WinTab Driver** | Inoperable | Linux doesn't allow forcing `usbhid` unbinding without breaking the device. No native support for adapted Windows drivers. |
| **udev Rules (`ENV{ID_IGNORE}="1"`)** | No Effect | Manipulating `hidraw` directly requires writing a custom data parser from scratch. |

---

## Contributing
If you have a tablet that isn't automatically detected or want to improve the offset logic, feel free to open a Pull Request!

**Developed by Matías Collado**

---
