# Release 1 alpha checklist

## Before each build

- `swift test` passes.
- A real scan finishes and responds to a filesystem change within one minute.
- Monitored-folder totals are labeled separately from whole-disk free space.
- Inaccessible folders are disclosed.
- Hard links are counted once; APFS clone limitations remain disclosed.
- No recommendation includes a protected path or file type.
- No file appears in more than one recommendation.

## Cleanup trust checks

- Review shows every affected file, expected potential space, safety reason, and undo path.
- Move to Trash records zero recovered bytes until Trash is emptied and **Check results** is used.
- A partial or failed action remains visibly partial or failed.
- iCloud eviction never claims the cloud original was deleted.
- Action history distinguishes potential space from observed free-space change.

## Alpha operations

- Run the household protocol in `docs/alpha-usability-study.md` with 5–8 non-developers.
- Review recommendation feedback reasons after every session.
- Export diagnostics for bugs; leave paths disabled unless the participant explicitly opts in.
- Test a nearly-full Mac or constrained APFS test volume.
- Force-quit during a scan, reopen, and confirm a safe reconciliation.

## Signed beta

1. Store notarization credentials in a notarytool keychain profile.
2. Set `HEADROOM_CODESIGN_IDENTITY` to the Developer ID Application certificate name.
3. Set `HEADROOM_NOTARY_PROFILE` to the keychain profile name.
4. Run `scripts/notarize-release.sh`.
5. Verify the stapled DMG on a clean Mac before sharing it.

Automatic updating is intentionally not enabled until a signed update feed, hosting location, and rollback policy are chosen. Alpha builds should be replaced manually so Headroom never installs an unauthenticated update.
