# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

---

## [0.8.4] - 2025-05-06

### Fixed

- In-line the old version of `String.jaro_distance/2`, since the one introduced in Elixir 1.17.1 changes the behaviour

---

## [0.8.3] - 2025-04-11

### Fixed

- Using `Date.utc_today` instead of `Date.utc_now` which doesn't exist

---

## [0.8.2] - 2025-03-27

### Fixed

- Removed Noether dependency to avoid conflicts.

---

## [0.8.1] - 2025-02-25

### Fixed

- New `time/0` function as part of the `Random` module which was previously
  undefined after codegen

---

## [0.8.0] - 2025-01-22

### Changed

- Replaced `elixir_uuid` with `uniq`

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


[Unreleased]: https://github.com/primait/avrogen/compare/0.8.4...HEAD
[0.8.3]: https://github.com/primait/avrogen/compare/0.8.3...0.8.4
[0.8.3]: https://github.com/primait/avrogen/compare/0.8.2...0.8.3
[0.8.2]: https://github.com/primait/avrogen/compare/0.8.1...0.8.2
[0.8.1]: https://github.com/primait/avrogen/compare/0.8.0...0.8.1
[0.8.0]: https://github.com/primait/avrogen/compare/0.7.0...0.8.0
[0.7.0]: https://github.com/primait/avrogen/compare/0.6.6...0.7.0
[0.6.6]: https://github.com/primait/avrogen/compare/0.6.5...0.6.6
[0.6.5]: https://github.com/primait/avrogen/compare/0.6.4...0.6.5
