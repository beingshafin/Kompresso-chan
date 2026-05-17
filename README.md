# 🎬 Kompresso-chan

<img src="dependencies/Assets/kompresso-chan.png" alt="Kompresso-chan Banner" width="200" align="left" style="margin-right: 15px; margin-bottom: 10px;">

**Kompresso-chan** is a professional, high-performance video compression utility for Windows. Designed to streamline your media workflow, it acts as a robust wrapper around the industry-standard **HandBrakeCLI**, offering seamless context-menu integration, smart batch processing, and detailed analytics.

<br clear="left">

---

## ✨ Features at a Glance

- **🚀 Explorer Integration**: Right-click any video file or folder to start compressing instantly.
- **📂 Bulk Processing**: Queue dozens of files or entire directory trees with one click.
- **🛠️ Intelligent Workflow Modes**:
  - **Replace**: Direct in-place replacement of original files.
  - **Cascade**: Creates a compressed version alongside the original (e.g., `video_kompressochan.mp4`).
  - **Mirror**: Recreates an entire folder structure, copying non-video assets and compressing all media.
- **📊 Professional Logging**: Automatic generation of session logs showing compression ratios, time taken, and total disk space saved.
- **⚡ Performance Presets**: 24 curated HandBrake presets ranging from 4K AV1/HEVC to mobile-friendly 480p, optimized for speed and quality.
- **😴 Post-Task Automation**: Optional system shutdown after long compression queues.
- **💻 Native CLI**: Full terminal support via the `komchan` command.

---

## 📥 Installation Guide

Kompresso-chan is designed to be portable and easy to set up. Follow these steps to install it on your Windows machine:

### Method 1: The Easy Way (Recommended)
1. **Download/Clone** this repository to a folder where you want it to live (e.g., `C:\Tools\Kompresso-chan`).
2. Locate `install.exe` in the root folder.
3. **Right-click `install.exe`** and select **Run as Administrator**.
4. Follow the on-screen instructions. The installer will automatically:
   - Deploy HandBrakeCLI.
   - Configure the `komchan` system command.
   - Add the context menu entries.
   - Create a desktop shortcut.

### Method 2: PowerShell (Manual)
1. Open PowerShell as an **Administrator**.
2. Navigate to the `dependencies` folder.
3. Run the installation script:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force; .\install.ps1
   ```

> [!NOTE]
> You may need to restart your terminal or Windows Explorer for the `komchan` command and context menu to appear globally.

---

## 🚀 How to Use

### 1. Using the Context Menu
This is the fastest way to compress videos:
- **Single Item**: Right-click an `.mp4` file or a folder and select **Compress with Kompresso-chan**.
- **Multiple Items**: Select multiple files/folders, right-click, and choose the menu option. They will be added to a single processing session.
<p>
  <img src="dependencies/Assets/presets.png" alt="Preset Selection Screen" width="700">
</p>

### 2. Using the Command Line (CLI)
Open any terminal (CMD, PowerShell, or Windows Terminal) and use the `komchan` command:
```powershell
# Compress a specific file
komchan "D:\Movies\MyVideo.mp4"

# Compress an entire folder
komchan "D:\Recordings"

# Show help and usage guide
komchan --help
```

### 3. Using a Path List (.txt)
For advanced batching, create a `.txt` file containing absolute paths to files or folders (one per line). Drag and drop this text file onto the Kompresso-chan shortcut or pass it to the CLI:
```powershell
komchan "C:\Users\You\Desktop\batch_list.txt"
```

### 🖥️ Live Processing Output
Watch real-time dynamic statistics, queue progress, and HandBrake CLI output as Kompresso-chan runs:
<p>
  <img src="dependencies/Assets/live-update.png" alt="Live Output Screen" width="700">
</p>

---

## 🛠️ Processing Modes Explained

When you start a session, you will be prompted to choose a mode:

| Mode | Behavior | Best For... |
| :--- | :--- | :--- |
| **1. Replace** | Overwrites the original file with the compressed version. | Saving space when you don't need the original high-bitrate files. |
| **2. Cascade** | Saves a new file with the `_kompressochan` suffix in the same folder. | Comparing quality or keeping a backup of the original. |
| **3. Mirror** | Recreates the selected folder's structure in a new directory named `Folder_kompressochan`. | Bulk processing an entire library while preserving organization and non-video files (subtitles, images, etc.). |

---

## 📊 Logging & Analytics

Kompresso-chan doesn't just compress; it tracks your efficiency. It generates two kinds of logs depending on how it was run:
- **Folder Log (`compression_log.txt`)**: A static log generated in the target directory (or mirror folder).
- **Session Log (`session_compression_log_YYYY-M-D-HH.mm.ss.txt`)**: A timestamped log generated next to the input list file whenever you process a batch via a `.txt` list.

**The logs include:**
- Selected Preset and Mode.
- Per-file status (Success/Fail) and time taken.
- **Final Summary**: Total space saved (MB) and compression percentage.
- **Last Undone Job** (Session Log only): If a session is interrupted, it logs the last file that wasn't completed.

### 📈 Console Session Summary
At the end of a compression batch, a clean, detailed overview of the saved disk space is displayed:
<p>
  <img src="dependencies/Assets/summary.png" alt="Console Summary Output" width="400">
</p>

---

## 📤 Uninstallation Guide

To completely remove Kompresso-chan from your system:

1. **Run Uninstaller**:
   - Right-click `uninstall.exe` in the root directory and select **Run as Administrator**.
   - *Alternatively*, run `uninstall.ps1` from the `dependencies` folder with PowerShell (Admin).
2. **Cleanup**: The uninstaller will safely remove the context menu entries, system PATH variables, and program files.

---

## ⚠️ Requirements & Disclaimer

- **OS**: Windows 10 or 11 (64-bit).
- **Powershell**: 5.1 or higher.
- **Dependencies**: HandBrakeCLI (Included in the `dependencies` folder and handled by the installer).

*Kompresso-chan is provided "as-is". While it is designed for reliability, always ensure you have backups of critical data before using "Replace" mode. This tool is independent and not affiliated with the HandBrake team.*
