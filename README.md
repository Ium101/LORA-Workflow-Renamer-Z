# LoRA Workflow Renamer Z

![Python](https://img.shields.io/badge/Python-3-blue?logo=python&logoColor=white)
![Platform](https://img.shields.io/badge/Windows%20%7C%20Linux-lightgrey)
![License](https://img.shields.io/badge/License-BSD--2--Clause-green)

**Rename your ComfyUI workflow `.json` files by the LoRAs they use, instantly.**

Tired of a folder full of `workflow (12).json`, `test_final_v3.json` and `new_new.json`? This tool reads your Comfy workflows and renames each file after the LoRA names it contains, separated by commas, so you can tell what's inside without opening anything.

## Example

```text
Before:  workflow (12).json
After:   detail_tweaker, film_grain, my_character_v2.json
```

*(Illustrative example. Names come from the LoRAs found in each workflow.)*

## Features

- Batch-renames all workflow JSON files in one go
- Uses the LoRA names found inside each workflow
- Names are separated by commas, easy to read and search
- Works on Windows and Linux

## Getting started

### Windows (ready to use)

Download `LoRA_Workflow_Renamer_Z.exe` from this repository and run it. No installation needed.

### Run from source (Windows / Linux)

```bash
git clone https://github.com/Ium101/LORA-Workflow-Renamer-Z.git
cd LORA-Workflow-Renamer-Z
python lora_workflow_renamer_z.py
```

### Build your own executable

```bash
# Windows
build.bat

# Linux
./build.sh
```

> **Tip:** keep a backup of your workflows before running any batch rename.

## Want more?

This repository is the **simple, free version**. I also maintain a **more complete version of this program that is for my personal use but may be sold**. If you're interested, feel free to reach out through my [GitHub profile](https://github.com/Ium101) for dealing it.

## License

Released under the [BSD 2-Clause License](LICENSE).

---

Made by [Ium101](https://github.com/Ium101)
