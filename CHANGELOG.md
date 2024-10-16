# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

---

## [0.7.0] - 2024-09-18

### Changed

- **Breaking change**: encoder will fail with a match error if the input is not
  serializable in Avro format.

---

## [0.6.6] - 2024-08-11

### Added

- `find_avsc_files!` function to find all `.avsc` files in a directory.
- `combined_schema` function to return a list of schemas sorted in topological
  order.

### Fixed

- Reintroduced guard in uuid logical type.

---

## [0.6.5] - 2024-07-05

### Added

- Support for additional logical types:
  - `Date` (`int`).
  - `TimeMillis` (`int`).
  - `TimeMicros` (`long`).
  - `TimestampMicros` (`long`).
  - `LocalTimestampMillis` (`long`).
  - `LocalTimestampMicros` (`long`).

[Unreleased]: https://github.com/primait/avrogen/compare/0.7.0...HEAD
[0.7.0]: https://github.com/primait/avrogen/compare/0.6.6...0.7.0
[0.6.6]: https://github.com/primait/avrogen/compare/0.6.5...0.6.6
[0.6.5]: https://github.com/primait/avrogen/compare/0.6.4...0.6.5
