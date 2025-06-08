# MCServerManagaer
PowerShell toolkit for managing Minecraft servers with auto-updates, rollback, and remote syncing.

## Features
- 🔄 Auto-restart and crash recovery
- 🧪 Java argument tuning (G1GC, ZGC support)
- 🧼 Session lock cleanup
- 🧾 Logging with timestamps
- 🌐 Remote version checking and updates via manifest
- 🛡️ Script integrity verification (hash + digital signature)
- ♻️ Rollback support with history

## Getting Started
1. Clone or download the repo.
2. Place your server `.jar` in the root folder.
3. Edit `config.xml` to match your server path, RAM, and update preferences.
4. Run `startserver.ps1` to launch and begin management.

## Configuration
Open `MCServerManagaer/config.xml` and review these critical options:

### Java Settings:
- `<InitialRam>` and `<MaxRam>`: Set memory allocation for Java.
- `<UseZGC>`: Use Z Garbage Collector (true/false).

### Online Update Settings:
- `<Enable>`: Set to `true` to enable automatic script updates.
- `<ManifestUrl>`: Point this to your hosted `functions_remote.xml` file.

### Example:
```xml
<OnlineUpdate>
  <Enable>true</Enable>
  <ManifestUrl>https://example.com/functions_remote.xml</ManifestUrl>
</OnlineUpdate>
```

## Updating the Manifest
If you're hosting updates remotely:
1. Edit script versions via `$ScriptVersion = 'x.x.x'` in each `.ps1`.
2. Run `Generate-RemoteManifest.ps1` to create `functions_remote.xml`.
   - If `private.pem` doesn't exist, it's generated automatically.
3. Upload the `functions_remote.xml` and any updated zipped scripts to your web host.

## Rollback
- Every script update is tracked in `F_META/rollback_history.json`.
- Use `Rollback-PreviousVersions.ps1` to interactively roll back any script.

## Security
- Scripts are verified using SHA256 + digital signatures from your `private.pem`.
- Public key is stored as `public.pem` for verification.

## Recommended Workflow
1. Modify or add `.ps1` scripts.
2. Run `Update-FunctionsManifest.ps1` to hash + version them.
3. (Optional) Run `Generate-RemoteManifest.ps1` to publish updates online.
4. Enable online updates in `config.xml`.
5. Use `Update-OnlineResources.ps1` to auto-sync new versions from your manifest.

---
**Licensor:** Donovan M. H. Galloway  
**License:** Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)
