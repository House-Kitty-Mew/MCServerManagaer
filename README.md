# MCServerManagaer
PowerShell toolkit for managing Minecraft servers with auto-updates, rollback, and remote syncing.

## 📁 Folder Structure
```
MCServerManagaer/
├── MinecraftServerFiles/           # Your actual Minecraft server jar, world, logs, etc
│   └── server.jar                 # Required server jar
├── config.xml                    # Main configuration for memory, updates, etc
├── man.db                        # Manual documentation
├── F_META/                       # Rollback history and changelogs
├── ONLINE_RESOURCES/            # Remote script update handling
├── custom_starter_scripts/      # All PowerShell tools and automation scripts
└── startserver.ps1               # Entry point to launch and manage the server
```

## 🚀 Getting Started
1. Place your Minecraft `server.jar` inside the `MinecraftServerFiles/` folder.
2. Edit `config.xml` in the root to update memory settings and enable online features.
3. Accept the EULA by editing `MinecraftServerFiles/eula.txt` and setting it to `true`.
4. Run `startserver.ps1` to launch the server.

## ⚙️ Configuration Tips (`config.xml`)
- `<InitialRam>` and `<MaxRam>`: Java memory settings.
- `<UseZGC>`: Enable/disable Z Garbage Collector.
- `<ServerJar>`: Leave as `.\MinecraftServerFiles\server.jar` unless customized.

### 🔄 Online Update
```xml
<OnlineUpdate>
  <Enable>true</Enable>
  <ManifestUrl>https://example.com/functions_remote.xml</ManifestUrl>
</OnlineUpdate>
```
- Host `functions_remote.xml` and zipped `.ps1` updates online to keep scripts in sync.
- Run `Update-OnlineResources.ps1` to auto-apply script updates.

## 🔧 Script Maintenance
- Use `Update-FunctionsManifest.ps1` after editing or adding scripts to refresh the database.
- Use `Generate-RemoteManifest.ps1` to export a signed remote XML for deployment.
   - Automatically creates `private.pem` and `public.pem` if missing.

## ♻️ Rollback
- Every script update is logged to `F_META/rollback_history.json`.
- Run `Rollback-PreviousVersions.ps1` to choose and revert any script by version/hash.

## 🔐 Security
- Each script is hash-verified and signed with your private key before being used.
- Public key verification occurs in `Setup-Environment.ps1`.

---
**Licensor:** Donovan M. H. Galloway  
**License:** Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)
