# Pull Request

## Summary

<!-- Describe the change clearly and concisely. What problem does it solve or what feature does it add? -->

## Related Issue

<!-- Link to the GitHub issue this PR addresses. Use "Closes #123" to auto-close on merge. -->

Closes #

## Branch

- [ ] `develop` → `main` (phase completion merge — requires Boardroom sign-off)
- [ ] `fix/*` → `develop` (bug fix)
- [ ] `chore/*` → `develop` (tooling or maintenance)

## Type of Change

- [ ] `feat` — New feature
- [ ] `fix` — Bug fix
- [ ] `refactor` — Code restructure with no behaviour change
- [ ] `test` — New or updated tests only
- [ ] `docs` — Documentation only
- [ ] `chore` — Tooling, dependencies, configuration
- [ ] `perf` — Performance improvement

## Affected Package(s)

- [ ] `block_editor` (core)
- [ ] `block_editor_plugins` (companion)
- [ ] `example`
- [ ] Repository tooling / CI

---

## Pre-Merge Checklist

All items must be checked before this PR can be merged. Do not merge with unchecked boxes unless explicitly discussed with the project maintainer.

### Code Quality

- [ ] `melos run format` passes with no changes required
- [ ] `melos run analyze` passes with zero warnings and zero infos
- [ ] `melos run test` passes — all tests green, no skipped tests added without justification

### Public API

- [ ] Every new or changed public class, method, and field has a complete dartdoc comment
- [ ] No internal types are exposed through the public API
- [ ] `copyWith` is implemented on every new immutable model

### Tests

- [ ] Unit tests are added for every new model and controller method
- [ ] UI tests are added for every new block renderer widget
- [ ] No existing tests have been deleted or weakened to make the build pass

### Documentation & Changelog

- [ ] `CHANGELOG.md` for the affected package(s) is updated following Keep a Changelog format
- [ ] The repository-level `README.md` is updated if any public API surface has changed
- [ ] The package-level `README.md` reflects any new features or usage changes introduced in this PR

### Versioning

- [ ] `pubspec.yaml` version is bumped correctly per semantic versioning rules if this is a release PR
- [ ] No version bump is included if this is a non-release feature branch PR (Melos handles versioning)

### Example App

- [ ] The example app demonstrates every new block type, feature, or API introduced in this PR
- [ ] The example app builds without errors (`flutter build` verified locally on at least one platform)
- [ ] The example app has not had existing demonstrations removed or broken

### Phase Completion Gate (`develop` → `main` PRs only)

- [ ] Boardroom sign-off received for this phase
- [ ] All phase test count gates met and confirmed
- [ ] `melos run publish:dry-run` passes with no errors
- [ ] A GitHub release draft exists with the correct semver tag and the CHANGELOG entry as release notes
- [ ] The example app has been verified to build and run on at least one target platform end-to-end

---

## Screenshots / Screen Recordings

<!-- For UI changes, attach before/after screenshots or a short screen recording. Delete this section if not applicable. -->

## Notes for Reviewer

<!-- Anything the reviewer should pay special attention to, known limitations, or follow-up issues to file. -->