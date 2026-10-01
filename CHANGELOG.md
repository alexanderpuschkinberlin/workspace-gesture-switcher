# Changelog

All notable changes to Workspace Gesture Switcher are documented in this file.

## 1.0.2 — 2026-10-01

### Security

- Harden Hyprland configuration access against symbolic links, FIFOs, oversized
  files, and path replacement races.
- Write configuration changes, backups, and rollbacks atomically while
  preserving the original file permissions.
- Detect concurrent changes and refuse to overwrite a configuration that has
  changed since it was read.

### Tests

- Add regression coverage for setup, every supported setting, validation and
  reload rollbacks, symbolic links, FIFOs, oversized files, backups, and file
  permissions.

## 1.0.1 — 2026-09-20

- Add guided first-run Hyprland setup and a one-time configuration backup.
- Document installation, removal, requirements, and all available controls.
- Add marketplace preview artwork and gesture documentation.

## 1.0.0 — 2026-09-20

- Initial release of the Workspace Gesture Switcher bar widget.
