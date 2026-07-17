# Headroom

Headroom is a local-first macOS storage advisor. It monitors selected folders, preserves a history of storage snapshots, explains meaningful changes, and ranks reversible cleanup opportunities.

[Visit the Headroom website](https://jacobmoncur.github.io/headroom/)

## Run

Requires macOS 14 or later and Xcode 15 or later.

```sh
swift run Headroom
```

Or open `Package.swift` in Xcode and run the `Headroom` executable scheme.

To create a signed local app bundle:

```sh
chmod +x scripts/package-app.sh
scripts/package-app.sh
open dist/Headroom.app
```

## What is implemented

- Progressive scanning of common high-growth folders, with user-selected folders
- Physical and logical file-size tracking
- Persistent local snapshots and storage-growth deltas
- Configurable protected reserve, spendable headroom, and runway
- Forecasting that waits for a trustworthy time baseline before extrapolating growth
- Dashboard, Action Center, What Changed, Explore, History, and Permissions views
- Target-based low-risk recovery plans such as “safely recover 30 GB”
- Ranked playbooks for Xcode Derived Data, app caches, Node dependencies, old installers, large recent files, cloud copies, and exact duplicates
- Recommendation snoozing, suppression, and protected folders or file categories
- Time-range storage statements with application, file-type, and folder breakdowns
- Preview, Finder reveal, local opening, Move to Trash, and confirmation
- Post-action free-space measurement and durable action history
- Menu-bar health companion
- Privacy-first onboarding and contextual permission explanation
- No network dependencies or metadata uploads

The release-plan items intentionally deferred from Release 1—cloud archiving, hosted storage, automatic cleanup rules, cross-device sync, and near-duplicate analysis—remain out of scope.
