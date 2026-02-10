# Changelog

## [Unreleased] - 2026-02-10

### Breaking Changes
- **Minimum FreeBSD version raised to 15.0+** (pfSense 2.8.1+). The script now exits with an error on older systems.
- **OpenJDK 8 replaced with OpenJDK 17**. UniFi 7.5+ requires JDK 17.
- **MongoDB 4.2 replaced with MongoDB 7.0**. Users upgrading from MongoDB 4.2 must step through intermediate versions (4.2 -> 4.4 -> 5.0 -> 6.0 -> 7.0) or perform a fresh install with backup restore.
- Removed `snappyjava` package and snappy-java replacement logic (not needed with JDK 17 + modern UniFi).
- Removed `python37` and `mpdecimal` packages (no longer dependencies).
- Removed `--smallfiles` MongoDB option (deprecated in 4.2+, removed in 5.0+).

### Added
- **External MongoDB support** via environment variables (`MONGO_EXTERNAL`, `MONGO_URI`, `MONGO_STAT_URI`, `MONGO_DB_NAME`). Allows using a remote MongoDB instance instead of local.
- FreeBSD version gate — script validates FreeBSD 15.0+ before proceeding.
- New OpenJDK 17 dependencies: `harfbuzz`, `lcms2`, `jpeg-turbo`, `libXrandr`, `gcc14`.
- Expanded old MongoDB cleanup — removes versions 3.6 through 6.0.
- Cleanup of old Java versions (`openjdk8`, `openjdk11`) during installation.
- MongoDB repair now conditional — only runs for local MongoDB when data directory exists.
- MongoDB package installation conditional — skipped when using external MongoDB.

### Changed
- UniFi Controller updated from 7.2.97 to **10.1.84**.
- MongoDB updated from `mongodb42` to `mongodb70`.
- Java updated from `openjdk8` to `openjdk17`.
- Fixed bashism: `==` comparison changed to `=` for POSIX sh compliance.
- Updated README with new version references, external MongoDB documentation, and migration warnings.
- Updated Usage section with direct raw GitHub URL (replaced tinyurl).
- Updated troubleshooting section for OpenJDK 17.

### Removed
- Support for FreeBSD < 15.0 / pfSense < 2.8.1.
- `snappyjava` package and snappy-java JAR replacement logic.
- `python37` and `mpdecimal` packages.
- `--smallfiles` MongoDB configuration for small partitions.
- Old MongoDB 3.6 to 4.2 upgrade instructions from README (replaced with 4.2 to 7.0 migration warning).
