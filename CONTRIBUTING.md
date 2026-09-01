# Contributing to Volumix

Thank you for helping improve Volumix. Contributions of code, documentation, testing, design, and
hardware compatibility reports are welcome.

## Before you start

- Read [AGENTS.md](AGENTS.md) for the repository's safety and coding rules.
- Read [ARCHITECTURE.md](ARCHITECTURE.md) before changing CoreAudio code.
- Check existing issues before beginning a large change.
- Open an issue first for new dependencies, architecture changes, deployment-target changes, or
  features that expand the v1 scope.

## Development setup

You need macOS 14.4+, Swift 6.1+, and Xcode Command Line Tools. Xcode itself is optional.

```sh
make app
swift run spike --test
```

System Audio Recording permission and real audio playback are required for end-to-end mixer tests.
See [Building](docs/BUILDING.md) for the full setup.

## Pull requests

Keep each pull request focused on one concern. Include:

- A clear description of the problem and solution.
- The commands and manual scenarios used for verification.
- Screenshots or a short recording for visible UI changes.
- Audio hardware and macOS version for device-specific changes.
- Known limitations or tests that could not be run.

Do not include generated `.build`, `Volumix.app`, graph analysis, or IDE state files.

## Coding expectations

- Keep all code, comments, diagnostics, UI copy, and documentation in English.
- Preserve real-time safety and tap cleanup guarantees.
- Prefer Apple frameworks and existing project patterns.
- Update relevant documentation when behavior or architecture changes.
- Add or extend synthetic checks when changing pure buffer, gain, or RMS logic.

## Commit messages

Use a concise imperative subject, for example:

```text
Fix output-device fallback after disconnect
Document aggregate-device recreation behavior
```

Explain non-obvious constraints or measured behavior in the commit body.

## Reporting bugs

Include reproduction steps, expected and actual behavior, macOS version, Mac model, output device,
affected application, and relevant output from `make debug`. Never attach recordings or logs that
contain private information without reviewing them first.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
