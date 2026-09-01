# Security policy

## Supported versions

Until the first stable release, security fixes are applied to the latest version on the default
branch. Volumix supports macOS 14.4 and later.

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could expose user data, interfere with system
audio, bypass permissions, or leave application audio muted after Volumix exits.

Use GitHub's private vulnerability reporting feature for this repository. Include:

- Affected revision or release.
- Reproduction steps and required conditions.
- Expected impact.
- Any proof-of-concept code or logs needed to confirm the issue.

If private vulnerability reporting is unavailable, contact the repository owner through the private
contact method listed on their GitHub profile.

You should receive an acknowledgement within seven days. Please allow time to reproduce, fix, and
coordinate disclosure before publishing details.

## Privacy model

Volumix processes audio samples in memory to apply gain and calculate RMS levels. It does not
record, persist, upload, or otherwise transmit audio. Changes that introduce recording, telemetry,
analytics, or network access require explicit maintainer approval and clear user documentation.
