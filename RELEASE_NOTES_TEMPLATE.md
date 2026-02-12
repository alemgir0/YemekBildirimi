# Release Notes Template

**Version**: vX.Y.Z  
**Release Date**: YYYY-MM-DD  
**Repository**: [alemgir0/YemekBildirimi](https://github.com/alemgir0/YemekBildirimi)

---

## 📦 Release Summary

[1-2 sentence summary of this release - e.g., "This release adds HTTPS support via Nginx and fixes critical encoding issues in Turkish characters."]

---

## ✨ New Features

- **[Feature Name]**: Brief description of the feature and its benefits
  - Example: _Added Nginx reverse proxy support with optional SSL/TLS configuration_
  - Relevant PRs: #123, #456

[Add more features as bullet points]

---

## 🐛 Bug Fixes

- **[Bug Description]**: What was wrong and how it was fixed
  - Example: _Fixed UTF-8 BOM encoding issue causing Turkish characters to display incorrectly in PowerShell 5.1_
  - Closes: #789

[Add more fixes as bullet points]

---

## 🚨 Breaking Changes

> [!WARNING]
> This section lists changes that may require action before upgrading.

- **[Breaking Change Description]**: What changed, why it changed, and migration steps
  - Example: _Environment variable `AUTH_USER` renamed to `PANEL_USER` for clarity_
  - **Migration**: Edit [server/.env](file:///c:/Full/Half/YemekBildirim/server/.env) and rename the variable, then restart container
  - Affected users: All deployments using custom panel usernames

[Add more breaking changes as bullet points. If none, write "**None** - This is a backward-compatible release."]

---

## 📥 Installation

### New Installation

**Server (Ubuntu/Debian):**
```bash
REF=vX.Y.Z curl -fsSL https://raw.githubusercontent.com/alemgir0/YemekBildirimi/main/install.sh | sudo bash
```

**Windows Client:**
```powershell
irm http://<SERVER_IP>:8787/download/install.ps1 | iex
```

### Upgrade from Previous Version

**Server:**
```bash
REF=vX.Y.Z curl -fsSL https://raw.githubusercontent.com/alemgir0/YemekBildirimi/main/install.sh | sudo bash
```

**Windows Client:**
```powershell
irm http://<SERVER_IP>:8787/download/install.ps1 | iex
```

⚠️ **Note**: Existing `.env` credentials are preserved during server upgrades.

---

## 📝 Additional Notes

### Deprecation Warnings
[List any features/APIs that are deprecated but still work in this release]
- Example: _`AUTH_USER` and `AUTH_PASS` environment variables are deprecated in favor of `PANEL_USER` and `PANEL_PASS`. Support will be removed in v1.0.0._

### Known Issues
[List any known bugs or limitations in this release]
- Example: _Windows Server 2016 may require manual Scheduled Task creation due to PowerShell cmdlet compatibility. See troubleshooting guide._

### Performance Improvements
[Optional section for performance-related changes]
- Example: _Reduced Docker image size by 30% (from 200MB to 140MB) by optimizing layer caching_

### Security Updates
[Optional section for security-related changes that aren't breaking or features]
- Example: _Updated Python dependencies to patch CVE-2024-XXXXX (low severity)_

---

## 🔗 Useful Links

- **Full Documentation**: [README.md](https://github.com/alemgir0/YemekBildirimi/blob/main/README.md)
- **Upgrade Guide**: [README.md#update-procedure](https://github.com/alemgir0/YemekBildirimi/blob/main/README.md#-update-procedure)
- **Troubleshooting**: [README.md#troubleshooting](https://github.com/alemgir0/YemekBildirimi/blob/main/README.md#-troubleshooting)
- **Issue Tracker**: [GitHub Issues](https://github.com/alemgir0/YemekBildirimi/issues)

---

## 🙏 Contributors

Special thanks to everyone who contributed to this release:

- [@username1](https://github.com/username1) - Feature X implementation
- [@username2](https://github.com/username2) - Bug fix Y
- [All contributors](https://github.com/alemgir0/YemekBildirimi/graphs/contributors)

---

## 📊 Release Statistics

| Metric | Value |
|--------|-------|
| Commits since last release | XX |
| Files changed | XX |
| Lines added | +XXX |
| Lines removed | -XXX |
| Issues closed | XX |
| Pull requests merged | XX |

---

## 🎯 Semantic Versioning

This project follows [Semantic Versioning (SemVer)](https://semver.org/):

- **MAJOR** (X.0.0): Breaking changes - incompatible API/config changes
- **MINOR** (0.X.0): New features - backward-compatible functionality
- **PATCH** (0.0.X): Bug fixes - backward-compatible fixes

**Version X.Y.Z Breakdown:**
- **X** = [Major version number]
- **Y** = [Minor version number]  
- **Z** = [Patch version number]

[Briefly explain what type of changes this release represents based on SemVer - e.g., "This is a MINOR release adding new features while maintaining full backward compatibility."]

---

## 📅 Release Timeline

| Milestone | Date |
|-----------|------|
| Development started | YYYY-MM-DD |
| Feature freeze | YYYY-MM-DD |
| Release candidate (vX.Y.Z-rc.1) | YYYY-MM-DD |
| Final release (vX.Y.Z) | YYYY-MM-DD |

---

## 🔮 What's Next?

Planned for next release (vX.Y+1.Z):
- [Planned feature 1]
- [Planned feature 2]
- [Planned improvement 3]

See our [project roadmap](https://github.com/alemgir0/YemekBildirimi/projects) for more details.

---

**Thank you for using YemekBildirimi! 🎉**

If you encounter any issues, please [report them on GitHub](https://github.com/alemgir0/YemekBildirimi/issues/new).
