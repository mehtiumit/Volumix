# Release process

This project is not yet shipping notarized binaries. The following checklist defines the intended
release process.

## Prepare

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Update `PLAN.md`, `README.md`, and release notes.
3. Confirm all source and documentation text is in English.
4. Run the complete verification sequence in `docs/BUILDING.md`.
5. Perform manual tests on each supported macOS major release and representative output hardware.

## Sign

Build with a Developer ID Application certificate:

```sh
make app SIGN_ID="Developer ID Application: Your Name (TEAMID)"
codesign --verify --deep --strict --verbose=2 Volumix.app
```

Do not use `--deep` as a substitute for signing nested code correctly if nested helpers are added in
the future.

## Notarize and staple

Package the signed application as a ZIP or DMG, submit it with Apple's `notarytool`, wait for
acceptance, and staple the ticket to the distributed artifact. Validate Gatekeeper behavior on a
clean machine or user account before publishing.

## Publish

- Create a signed version tag.
- Publish release notes with changes, known limitations, and minimum macOS version.
- Attach only notarized artifacts and checksums.
- Verify installation and first-run permission flow from the downloaded artifact.

Never publish private signing credentials, notarization profiles, or exported certificates.
