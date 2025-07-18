# Phind CodeLlama 34B v2 - Mirror Model Installer

## ⚠️ Important Disclaimer
This repository and the tools within are provided as a workaround for users who are unable to download Ollama models directly due to restrictive corporate network policies.
**You are solely responsible for ensuring that using this model and the methods in this repository complies with your organization's IT, data security, and fair use policies.**
If you have any reason to believe that downloading, storing, or using this model on your corporate-managed device is against policy, **DO NOT PROCEED**. By using the contents of this repository, you acknowledge that you are doing so at your own risk and are responsible for any potential policy violations.

---

## About This Repository

Want to code on your SOE while trapped in a metal tube at 35,000 feet? Or perhaps during your sardine-can commute experience? Maybe in your off-grid man-cave where even carrier pigeons can't find you? Use your favorite AI IDE coding agent like [Cline](https://cline.bot/), [Roo](https://github.com/RooCodeInc/Roo-Code/blob/main/README.md), [Kilo](https://kilocode.ai/), or [Kiro](https://aws.amazon.com/blogs/devops/amazon-q-developer-agentic-coding-experience/) to leverage [codellama](https://www.promptingguide.ai/models/code-llama) - a "where-have-you-been-all-my-life" coding companion that works without the internet's blessing! 🧙‍♂️✈️🚇

This repository provides a robust, resumable installer for the `phind-codellama-34b-v2` Ollama model, designed for users on networks where direct downloads from `ollama.ai` and/or `cloudflarestorage.com/ollama/` are blocked. The model is split into 50MB chunks for reliable downloading, with a script to reassemble, verify, and install the model for Ollama.



### Target Audience

- Developers and engineers on **macOS** or **Windows** laptops who are blocked from downloading Ollama models directly.
- This model requires at least **24GB of RAM** to run effectively.

## Prerequisites

- **Ollama** installed and run at least once (to create the models directory).
- At least **40GB** of free disk space.
- At least **24GB of RAM** to run the model.

## Installation

### macOS (Recommended: One-Line Install)

Open your terminal and run:

```sh
curl -sSL https://raw.githubusercontent.com/enelass/phind-codellama-34b-v2/main/install.sh | bash
```

![alt text](<Download the model-medium.gif>)


#### What the Installer Does

- Checks for macOS and the presence of the Ollama models directory.
- Verifies at least 40GB of free disk space.
- Downloads the model's SHA256 file.
- Downloads all model chunk parts with a real progress bar and resumable downloads.
- Reassembles the model from chunks with a spinner and verifies the SHA256 checksum (with a spinner).
- Moves the model file to the correct Ollama models directory.
- **Downloads all required manifest and metadata files (including all sha256-* files) from GitHub, not the Ollama registry.**
- Prints a final message with the run command.


## Using the Model

Once installation is complete, you can run the model with:

```sh
ollama run phind-codellama:34b-v2
```

The model will appear in Ollama automatically if the steps complete successfully.

![alt text](<Running the model-small.gif>)


### Windows (Manual Steps)

There is no automated script for Windows, but you can install the model manually:

1. **Download All Chunks**

   Use a download manager or PowerShell to download all `part_*` files from the `model-chunks` directory in this repository.

   Example PowerShell (from the repo root):

   ```powershell
   $baseUrl = "https://github.com/enelass/phind-codellama-34b-v2/raw/main/model-chunks"
   $parts = @()
   foreach ($first in 'a'..'n') {
     foreach ($second in 'a'..'z') {
       $suffix = "$first$second"
       $parts += $suffix
       if ($suffix -eq "nz") { break }
     }
     if ($suffix -eq "nz") { break }
   }
   foreach ($suffix in $parts) {
     $url = "$baseUrl/part_$suffix"
     Invoke-WebRequest -Uri $url -OutFile "part_$suffix"
   }
   ```

2. **Concatenate Chunks**

   In Command Prompt (CMD):

   ```cmd
   copy /b part_aa+part_ab+part_ac+...+part_nz sha256-45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2
   ```

   *(Replace `...` with all chunk names in order. You can generate this command with a script or by using PowerShell's `Get-ChildItem`.)*

3. **Download Manifest and Metadata Files**

   Download the following files from GitHub and place them in your Ollama manifests directory (usually `%USERPROFILE%\.ollama\models\manifests\registry.ollama.ai\library\phind-codellama\`):

   - [34b-v2](https://raw.githubusercontent.com/Enelass/phind-codellama-34b-v2/refs/heads/main/34b-v2)
   - [sha256-41774062cd349c744e8ee986c1aaf5784b7e42fbe306619536fa7386d421da78](https://raw.githubusercontent.com/Enelass/phind-codellama-34b-v2/refs/heads/main/sha256-41774062cd349c744e8ee986c1aaf5784b7e42fbe306619536fa7386d421da78)
   - [sha256-62ab78abadd613cb882be1e63a1a0d843685858f5f9456e7c4e3350284245d04](https://raw.githubusercontent.com/Enelass/phind-codellama-34b-v2/refs/heads/main/sha256-62ab78abadd613cb882be1e63a1a0d843685858f5f9456e7c4e3350284245d04)
   - [sha256-ee041eb771eb86734e51c251e840d15b6933121777e2ca290a6dece875f3ecd1](https://raw.githubusercontent.com/Enelass/phind-codellama-34b-v2/refs/heads/main/sha256-ee041eb771eb86734e51c251e840d15b6933121777e2ca290a6dece875f3ecd1)
   - [sha256-fb9390528638173921c5100c17dbba3d549a651a83caf1d00ecc6ab437052a13](https://raw.githubusercontent.com/Enelass/phind-codellama-34b-v2/refs/heads/main/sha256-fb9390528638173921c5100c17dbba3d549a651a83caf1d00ecc6ab437052a13)

4. **Verify SHA256 Checksum**

   In Command Prompt:

   ```cmd
   certutil -hashfile sha256-45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2 SHA256
   ```

   The output should match:

   ```
   45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2
   ```

5. **Move the Model File**

   Move the reassembled file to your Ollama models directory (usually):

   ```
   %USERPROFILE%\.ollama\models\blobs\
   ```

   The final path should be:

   ```
   %USERPROFILE%\.ollama\models\blobs\sha256-45488384ce7a0a42ed3afa01b759df504b9d994f896aacbea64e5b1414d38ba2
   ```


## Troubleshooting

- Ensure you have run Ollama at least once before installing (to create the models directory).
- If you encounter disk space or permission errors, free up space or check your user permissions.
- If the install is interrupted, simply re-run the install command (macOS) or repeat the manual steps (Windows) to resume.
- The installer will always download the latest manifest and metadata files from GitHub to ensure compatibility.

## License

See [LICENSE](LICENSE) for details.
