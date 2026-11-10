# Changelog

All notable changes to ScanPrint are documented in this file.

## [0.5.3] - 2026-11-10

### Fixed
- App no longer exits silently right after the precheck (restart loop) when
  `lpstat -a` fails against the CUPS server. bashio enables `errexit` and
  `pipefail`, so the informational queue listing added in 0.5.2 terminated the
  whole script. The error is now logged as a warning.
- A single failed print job (e.g. empty or unstable PDF) no longer terminates
  the file watcher, the startup scan or the MQTT listener.

### Changed
- The shutdown log line now includes the exit code.

## [0.5.2] - 2026-08-22

### Added
- `binary_sensor.scanprint_ready`.
- `sensor.scanprint_multicopy_pending`.
- `sensor.scanprint_multicopy_next`.
- `sensor.scanprint_failed_count`.
- `sensor.scanprint_last_job`.
- Live monitoring of the `multicopy` and `failed` directories.
- Startup listing of available CUPS queues.
- Basic configuration validation.
- App architecture in startup/version information.
- Expanded HAOS installation and operating notes.
- Troubleshooting section in README.
- Updated `DOCS.md`.

### Changed
- Multicopy status now reflects the number of waiting documents.
- Runtime state is rebuilt from the actual filesystem state after restart.
- Queue-precheck logging is more informative.
- Duplex capability detection remains a warning rather than a fatal startup error.
- Documentation now describes repository-based installation as the recommended deployment path.

### Fixed
- Reduced ambiguity when configured CUPS queue names do not exist.
- Improved visibility of failed print files and waiting multicopy jobs.

## [0.5.1] - 2026-08-22

### Added
- Initial public project documentation.
- README.
- CHANGELOG.
- MIT license.
- Git ignore configuration.
- Home Assistant repository metadata.
- Author and maintainer information.
- Installation and configuration documentation.
- Beta project status.

### Changed
- Prepared ScanPrint for publication as a Home Assistant app repository.
- Replaced installation-specific defaults with generic repository defaults.
- Added project homepage metadata.
- Version advanced to 0.5.1.

### Fixed
- No runtime functional changes.

## [0.5.0] - 2026-08-22

### Added
- App configuration for CUPS host/port, queue names, default copy count, default mode, and collation.
- Startup dependency and configuration prechecks.
- CUPS reachability and queue checks.
- MQTT reachability check.
- Writable `/share/scanprint` check.

### Changed
- Removed hard-coded CUPS connection and queue configuration from runtime logic.

## [0.4.0] - 2026-08-22

### Added
- MQTT Select entity for multicopy print mode.
- Simplex/Duplex selection for multicopy jobs.
- Copy count range from 1 to 20.
- Persistent runtime state.
- Collated multicopy output.
- Oldest-waiting-PDF processing.
- Automatic app-version reporting.

## [0.3.2] - 2026-08-22

### Fixed
- Replaced GNU `find -printf` usage with BusyBox-compatible file handling.
- Fixed multicopy jobs failing in the Home Assistant base image.

## [0.3.1] - 2026-08-22

### Fixed
- Changed runtime script interpreter to `/usr/bin/with-contenv bashio`.
- Fixed `bashio::services` availability.
- Fixed MQTT service discovery.

## [0.3.0] - 2026-08-22

### Added
- MQTT integration via Supervisor service.
- MQTT Discovery.
- Copy-count entity.
- Multicopy print button.
- Status sensor.
- `multicopy` folder.

## [0.2.0] - 2026-08-22

### Added
- Continuous directory monitoring with `inotify`.
- Automatic Simplex/Duplex printing.
- File stability checking.
- Automatic deletion after successful CUPS submission.
- Failed-job directory.
- Existing-file processing after restart.

## [0.1.1] - 2026-08-22

### Added
- Duplex diagnostics.
- Explicit long-edge duplex settings.

## [0.1.0] - 2026-08-22

### Added
- Initial Home Assistant OS local app.
- CUPS client support.
- Initial PDF print test.
