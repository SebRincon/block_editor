# Changelog

All notable changes to this repository's tooling, CI, and workspace configuration are documented here.
Package-level changes are tracked in each package's own `CHANGELOG.md`.

- [`packages/block_editor/CHANGELOG.md`](packages/block_editor/CHANGELOG.md)
- [`packages/block_editor_plugins/CHANGELOG.md`](packages/block_editor_plugins/CHANGELOG.md)

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This repository adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Mono-repo scaffold with Melos workspace configuration
- GitHub Actions CI pipeline (`ci.yml`) with analyze, format, test, and platform build jobs
- GitHub Actions release pipeline (`release.yml`) — coming soon
- Pull request template with full release checklist
- Issue templates for bug reports and feature requests — coming soon
- Root-level `README.md`, `LICENSE`, and `CHANGELOG.md`
- Placeholder `block_editor_plugins` package structure
- Example app scaffold generated via `flutter create`