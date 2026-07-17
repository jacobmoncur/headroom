# Headroom
## Product Strategy, Experience Principles, and Release Plan

**Status:** Working draft  
**Version:** 0.1  
**Date:** July 16, 2026  
**Platform:** macOS first  
**Working product name:** Headroom

---

## 1. Executive Summary

Headroom is a proactive storage-management application for Mac. It helps people avoid unexpectedly running out of local storage by continuously explaining where space is going, forecasting when capacity will become a problem, and recommending safe, reversible actions to recover space.

The product is not intended to be another disk visualizer or generic Mac-cleaning utility. Existing products are good at showing a snapshot of file and folder sizes, but they often leave the user to interpret the results, decide what is safe, move or delete files manually, and repeat the process the next time the drive fills up.

Headroom should instead operate like a financial planning app for storage:

- **Free space** is the current balance.
- **Protected headroom** is the emergency reserve.
- **Storage growth** is cash flow.
- **Time until the reserve is reached** is runway.
- **Files created, downloaded, deleted, and archived** are transactions.
- **Category limits and retention policies** are budgets.
- **Offloading to cloud or external storage** is a transfer.
- **Approved recurring cleanup rules** are automation.

The product promise is simple:

> **Never be surprised by a full disk again.**

Headroom’s core differentiation should come from five capabilities working together:

1. A longitudinal understanding of how storage changes over time.
2. A recoverability model that distinguishes unique data from replaceable, generated, duplicated, or cloud-backed data.
3. Ranked and explainable action recommendations.
4. Transactional offloading that verifies a remote copy before removing a local copy.
5. Personalized, local-first intelligence that learns the user’s preferences and workflows.

The first release should prove that this new decision-oriented model is more valuable than a faster treemap. Later releases can add cloud offloading, natural-language storage policies, project understanding, and carefully constrained automation.

---

## 2. Product Charter

### 2.1 Vision

Create the trusted operating layer for personal storage: a system that understands what occupies a user’s devices, predicts capacity problems, and helps place each item in the right location without losing important data.

### 2.2 Mission

Help Mac users maintain healthy storage headroom with less effort, less uncertainty, and fewer emergency cleanup sessions.

### 2.3 Core Promise

> Headroom tells users what changed, identifies the safest actions, completes those actions, and verifies the result.

### 2.4 Initial Positioning

**For** Mac users who routinely approach their storage limit,  
**who** spend too much time scanning folders and deciding what is safe to delete,  
**Headroom is** a proactive storage planner and action center  
**that** forecasts problems, explains storage growth, and completes safe cleanup or offloading actions.  
**Unlike** disk visualizers and broad “Mac cleaner” suites,  
**Headroom** understands storage over time, models recoverability, and prioritizes reversible actions.

### 2.5 Product Category

The clearest category description is:

> **Proactive storage management for Mac**

Supporting descriptions include:

- Storage planner
- Storage advisor
- Personal storage operating system
- Storage budgeting and automation app

The product should avoid leading with “memory manager,” because users commonly use “memory” to mean storage, while macOS and technical audiences use “memory” to mean RAM. Product copy should prefer **storage**, **disk space**, **free space**, and **headroom**.

---

## 3. Problem Definition

### 3.1 Current User Experience

The typical storage-management cycle is reactive:

1. The user notices a low-storage warning or degraded performance.
2. The user opens macOS Storage Settings or a disk visualization tool.
3. A full scan takes time.
4. The user navigates a complicated folder hierarchy.
5. Large files and directories are shown, but their importance is unclear.
6. The user manually investigates whether each item is safe to delete.
7. The user deletes, moves, or uploads a few items.
8. The user repeats the entire process weeks or months later.

This process fails because the user is not primarily asking, “Which folders are large?” The deeper questions are:

- Why did my available space drop?
- What changed recently?
- How soon will I run out?
- What can I safely remove?
- What can be restored later?
- What is already stored somewhere else?
- Which files are part of active work?
- Can the application complete the cleanup for me?

### 3.2 Root Causes

Storage problems generally come from a mix of recurring patterns:

- Downloads accumulate without a retention policy.
- Applications create caches, builds, renders, recordings, and temporary assets.
- Projects finish but remain fully local.
- Cloud-synced files remain downloaded unnecessarily.
- Duplicate or near-duplicate media accumulates.
- Large updates, games, local AI models, and development environments grow quickly.
- Users cannot easily distinguish generated files from irreplaceable source material.
- Existing tools provide point-in-time snapshots rather than history and forecasts.

### 3.3 Opportunity

The opportunity is to shift storage management from **forensic cleanup** to **continuous planning**.

The desired user experience is:

1. Headroom monitors storage changes.
2. It warns the user before the safe reserve is threatened.
3. It explains the causes in plain language.
4. It presents a short list of high-impact, low-risk actions.
5. The user approves one or more actions.
6. Headroom executes and verifies the result.
7. Headroom learns from the user’s decisions.

---

## 4. Goals and Non-Goals

### 4.1 Product Goals

Headroom should:

- Keep users above a configurable safe-space reserve.
- Explain meaningful changes in available storage.
- Reduce the time required to recover healthy headroom.
- Recommend actions according to impact, urgency, confidence, effort, and risk.
- Distinguish unique data from recoverable or replaceable data.
- Make deletion and offloading understandable and reversible whenever possible.
- Support cloud and external-storage placement without requiring users to manually manage every transfer.
- Learn user preferences while preserving privacy.
- Become increasingly useful as it observes storage history.

### 4.2 Initial Non-Goals

The first versions should not attempt to become:

- A RAM optimizer.
- A malware scanner.
- A battery or CPU optimization suite.
- A general-purpose Mac maintenance utility.
- A fully autonomous file-deletion agent.
- A cross-platform storage product.
- A new cloud-storage provider at launch.
- A prettier treemap with an AI chatbot attached.

Focus is a strategic advantage. The product should own one promise before expanding:

> **The user will not unexpectedly run out of local storage.**

---

## 5. Target Users and Initial Market Wedge

### 5.1 Primary Audience

The strongest initial audience is Mac power users with large amounts of transient, generated, or project-based data:

- Software developers
- Video editors and filmmakers
- Designers and photographers
- Audio producers
- Researchers and data professionals
- Gamers
- People running local AI models
- Knowledge workers who record meetings or screens

These users are attractive because:

- They encounter the problem frequently.
- Storage growth often has identifiable causes.
- A single recommendation can recover tens or hundreds of gigabytes.
- Domain-specific cleanup recipes can provide obvious value.
- They are more likely to pay for a trustworthy professional utility.

### 5.2 Secondary Audience

After the recommendation and trust systems are proven, the product can expand to:

- General consumers with large photo and video libraries
- Families sharing cloud storage
- Students with limited-capacity laptops
- Small teams managing shared creative assets
- Multi-Mac households

### 5.3 Example Personas

#### The Developer

Uses Xcode, Docker, simulators, package managers, local databases, and AI models. Storage can drop rapidly because generated data is scattered across hidden or application-specific locations.

**Desired outcome:** Recover large amounts of generated data without damaging active projects or development environments.

#### The Creative Professional

Works with source media, project files, renders, caches, proxies, exports, and delivery packages.

**Desired outcome:** Keep active work local, archive completed work, and confidently remove replaceable render data.

#### The Digital Generalist

Downloads files, records meetings, uses multiple cloud providers, and rarely knows which items are safely backed up.

**Desired outcome:** Receive simple, trustworthy recommendations without understanding the filesystem.

---

## 6. Jobs to Be Done

### 6.1 Functional Jobs

- When my disk is filling up, help me recover space quickly without deleting something important.
- When storage changes unexpectedly, tell me what caused it.
- When I finish a project, help me archive it and keep it recoverable.
- When a file already exists in the cloud, help me remove only the local copy.
- When an application creates a large amount of generated data, tell me what it is and whether it can be regenerated.
- When I need a specific amount of free space, create the safest plan to reach that target.
- When I have recurring storage habits, help me turn them into policies.

### 6.2 Emotional Jobs

- Reduce anxiety about accidentally deleting important files.
- Eliminate the feeling of being ambushed by low-storage warnings.
- Replace an overwhelming cleanup session with a small number of clear decisions.
- Build confidence that archived items can be restored.

### 6.3 Social Jobs

- Help professionals appear organized and reliable when working with client files.
- Help users maintain a clean machine without becoming filesystem experts.
- Help teams or families communicate what is local, archived, or safe to remove.

---

## 7. The Banking and Budgeting Model

The banking metaphor should shape the information architecture without becoming a novelty theme.

| Banking concept | Storage equivalent | Product behavior |
|---|---|---|
| Accounts | Mac, external drive, iCloud, Google Drive, OneDrive, NAS | One view of every storage location |
| Available balance | Free local space | “You have 72 GB available” |
| Emergency fund | Safe-space reserve | Protect 50 GB or a percentage of the drive |
| Cash flow | Net storage growth | “You are adding 2.3 GB per day” |
| Transactions | Files created, downloaded, deleted, or offloaded | “What changed since Monday?” |
| Recurring charges | Apps and workflows that continually create data | Screen recordings, Docker, Messages, downloads |
| Budgets | Limits for categories, apps, folders, or projects | Downloads: 20 GB; active projects: 150 GB |
| Transfers | Moving data to cloud or external storage | Archive without losing access |
| Runway | Time until the reserve is breached | “At this rate, you have 12 days” |
| Autopay | User-approved storage rules | Offload completed projects after 90 days |

### 7.1 Protected Headroom

The primary health metric should be **protected headroom**, not percentage full.

Example:

- **Free now:** 72 GB
- **Safe reserve:** 50 GB
- **Spendable headroom:** 22 GB
- **Current growth:** 1.8 GB per day
- **Reserve reached in:** approximately 12 days

A percentage-full indicator is still useful, but it does not tell the user whether immediate action is needed.

### 7.2 Storage Statement

A weekly or monthly statement should summarize:

- Opening free-space balance
- Closing free-space balance
- Net change
- Largest growth sources
- Space recovered
- Files archived
- Local copies removed
- Rules executed
- Forecasted runway
- Recommended next actions

### 7.3 Budgets and Policies

Users may set limits such as:

- Keep Downloads below 20 GB.
- Keep at least 75 GB free.
- Keep active projects local.
- Review screen recordings after 30 days.
- Notify me when any application adds more than 10 GB in a week.
- Offer to archive completed projects after 90 days.

The product should avoid guilt-oriented language. Storage use is not inherently wasteful, and a photo library is not “debt.” The metaphor is about planning capacity and placement.

---

## 8. Core Product Loop

Headroom should follow a repeating loop:

> **Observe → Explain → Recommend → Act → Verify → Learn**

### 8.1 Observe

Maintain a persistent local index rather than running a full scan every time.

The system should track:

- File and folder size
- Physically allocated size
- Creation and modification times
- Recent growth
- File type
- Application or process association where practical
- Duplicate relationships
- Cloud state
- Archive state
- Project relationships
- User-protection policies
- Action history

The initial scan should be progressive. The interface should become useful quickly and continue improving as deeper indexing completes.

### 8.2 Explain

The product should answer:

> **Why did I lose space?**

Example explanation:

- 16.4 GB of screen recordings
- 9.7 GB downloaded by a game
- 6.1 GB of Docker images
- 3.8 GB of video exports
- 2.0 GB of miscellaneous downloads

Explanations should be based on structured evidence. AI may summarize that evidence, but it should not invent causal claims.

### 8.3 Recommend

The recommendation engine should produce a short, ranked action queue rather than an endless list of large files.

Example actions:

- Recover 24.8 GB by removing local copies already stored in iCloud.
- Archive two inactive projects and recover 37.4 GB.
- Delete 11.3 GB of exact duplicates.
- Remove 6.2 GB of installers for applications that are already installed.
- Review 18 GB of screen recordings older than 60 days.

Every recommendation should explain:

- Estimated physical space recovered
- Why it is being recommended
- Whether the data is unique, replaceable, duplicated, generated, or cloud-backed
- Last-used or last-modified information
- What the action will do
- Whether the action is reversible
- How the item can be restored
- Confidence level
- Risk level

### 8.4 Act

Headroom should complete the action when possible rather than sending the user to Finder to finish the task.

Supported actions may include:

- Move to Trash
- Remove a cloud-backed local copy
- Archive to a configured provider
- Remove application-generated data through a supported recipe
- Compress or package a completed project
- Move to an external drive
- Reveal in Finder for actions that cannot safely be automated

### 8.5 Verify

The application should never claim that space has been recovered until the result is confirmed.

For offloading, verification should include:

- Upload completion
- Remote item existence
- Size verification
- Checksum verification where supported
- Archive receipt creation
- Local removal or eviction
- Confirmation of actual recovered physical space

### 8.6 Learn

The product should learn from decisions such as:

- Accepted recommendations
- Rejected recommendations
- Protected folders or file types
- Preferred archive provider
- Frequently restored items
- Folders the user never wants suggested
- Categories treated as temporary or permanent

Personalization should be explainable and reversible. Users should be able to view and reset learned preferences.

---

## 9. Primary Product Experiences

### 9.1 Home Dashboard

The home screen should be a decision dashboard, not primarily a treemap.

Example:

```text
HEADROOM

68 GB free
Safe reserve: 50 GB

At your current rate, you will reach your reserve in 9 days.

WHAT CHANGED
Since Monday                              +21.6 GB

Screen recordings                         +9.2 GB
Downloads                                 +6.8 GB
Docker                                    +4.1 GB
Everything else                           +1.5 GB

BEST NEXT ACTIONS

Remove local copies already in iCloud     24.8 GB
Reversible · High confidence

Archive 2 inactive projects               37.4 GB
Verified cloud copy · Last opened 104 days ago

Delete exact duplicate videos             11.3 GB
9 files · Originals protected
```

### 9.2 Action Center

The Action Center is the heart of the product. It should:

- Rank actions by value and safety.
- Group related items into understandable tasks.
- Preview the exact files affected.
- Show a recovery estimate.
- Explain risk and reversibility.
- Let users approve one action, several actions, or a target amount of recovered space.
- Preserve an action history.

A useful user command is:

> “Safely recover 50 GB.”

The application can then construct a plan that reaches the target with the lowest practical risk.

### 9.3 What Changed

This view should show storage history by:

- Day, week, month, and custom period
- Application
- Folder
- File type
- Project
- Storage account
- Device

The key question is causal: **what consumed or released space during this period?**

### 9.4 Explore

A treemap, sunburst, file browser, or hierarchical size explorer remains useful as a secondary view for power users.

Explore should include:

- Fast navigation
- Search and filters
- Physical versus logical size
- Duplicate state
- Cloud state
- Project state
- Quick Look
- Finder reveal
- Contextual actions

### 9.5 Archive

The Archive view should provide a unified catalog of offloaded items, including:

- Original location
- Current provider
- Archive date
- Size
- Verification state
- Restore status
- Project association
- Searchable metadata

### 9.6 Policies

The Policies view should show both natural-language and structured rules.

Example:

> Keep current client projects local. After a project has been inactive for 90 days, recommend archiving it to Google Drive. Never remove RAW photo files automatically.

The interface should translate this into visible, deterministic conditions and actions.

### 9.7 Menu-Bar Companion

A small menu-bar component can display:

- Current free space
- Safe reserve status
- Runway
- New high-priority action count
- Active upload or archive status

It should not become a constant source of alarming notifications.

---

## 10. Recommendation System

### 10.1 Recommendation Objective

The system should maximize recovered headroom while minimizing user effort, uncertainty, and risk.

A conceptual ranking model is:

> **Priority = impact × urgency × confidence ÷ effort and risk**

The production implementation may use a more detailed scoring system, but the principle should remain understandable.

### 10.2 Action Risk Levels

#### Low Risk

- Remove a verified local copy of a cloud-backed file.
- Delete an exact duplicate while preserving a canonical copy.
- Remove a cache that an application can regenerate.
- Move an item to Trash with a clear recovery path.

#### Medium Risk

- Archive an inactive project to remote storage.
- Remove old installers or compressed archives.
- Delete application-generated data that may require rebuilding.
- Remove large downloads that appear replaceable.

#### High Risk

- Permanently delete unique media.
- Remove files from an active project.
- Delete items with unclear ownership or recoverability.
- Empty Trash or perform irreversible secure deletion.

High-risk actions should not be automated in early releases.

### 10.3 Recommendation Card Requirements

Every card should include:

- Plain-language title
- Space-recovery estimate
- Evidence and rationale
- Affected item count
- Preview
- Risk level
- Confidence level
- Reversibility description
- Primary action
- Secondary options such as Ignore, Protect, or Remind Later

### 10.4 Feedback and Suppression

When a user rejects a recommendation, Headroom should offer lightweight reasons such as:

- This is still active.
- This is important.
- Never suggest this folder.
- The estimate is wrong.
- I will handle it elsewhere.

The product should use this feedback to improve ranking and reduce repetitive suggestions.

---

## 11. Domain-Specific Storage Playbooks

A library of tested storage recipes can become a major product asset.

### 11.1 Developer Playbooks

Potential recipes:

- Xcode Derived Data
- Xcode archives
- Unused simulators and runtimes
- Swift Package Manager caches
- Homebrew download caches
- Docker images, layers, build cache, and stopped containers
- Node package caches
- Python environments and package caches
- Local databases and snapshots
- Local AI model weights

The application must distinguish generated data from source code and active project state.

### 11.2 Creative Playbooks

Potential recipes:

- Final Cut render files and proxies
- Adobe Premiere media cache
- After Effects disk cache
- DaVinci Resolve render cache
- Logic and audio bounce files
- Lightroom previews
- Camera import duplicates
- Completed exports and delivery packages

### 11.3 General Productivity Playbooks

Potential recipes:

- Screen recordings
- Meeting recordings
- Downloaded installers
- Large ZIP and DMG files
- Messages and email attachments
- Offline media downloads
- Old device backups
- Application update leftovers

### 11.4 Recipe Quality Requirements

Each recipe should be:

- Version-aware
- Tested against supported application versions
- Explicit about what is deleted or moved
- Clear about regeneration or restoration behavior
- Signed or otherwise integrity-protected
- Disabled when confidence is low

---

## 12. Cloud Offloading Strategy

Cloud offloading can become a signature capability, but it must be more trustworthy than a simple upload button.

### 12.1 Strategic Sequence

Recommended sequence:

1. Use storage accounts the user already has.
2. Add a unified archive experience.
3. Consider a hosted storage product only after demand is demonstrated.

### 12.2 Bring-Your-Own-Cloud

Start with:

- iCloud Drive
- Google Drive
- OneDrive
- Dropbox in a later phase
- External drives and network storage where practical

Provider selection can consider:

- Available capacity
- File size
- Expected retrieval frequency
- Existing folder organization
- Collaboration needs
- Privacy preference
- Whether the provider is already configured on the Mac

### 12.3 iCloud Drive

Where the operating system supports it, Headroom should identify items that are safely stored in iCloud and help remove the downloaded local copy while keeping the remote item available on demand.

The interface must clearly distinguish:

- Delete everywhere
- Move to iCloud Drive
- Keep in iCloud and remove only the local copy

These are materially different actions and should never be conflated.

### 12.4 Google Drive and OneDrive

Large transfers should use resumable upload mechanisms when available. The product should be able to recover from interrupted connectivity without restarting a large archive.

For each archive operation, Headroom should:

1. Prepare the item.
2. Upload or move it.
3. Resume after interruptions when necessary.
4. Verify size and checksum where possible.
5. Record a durable archive receipt.
6. Confirm that the remote item can be found.
7. Remove or evict the local item only after verification.
8. Confirm recovered physical space.

### 12.5 Archive Receipt

Each archived item should have a receipt containing:

- Original path
- Provider
- Remote identifier
- Remote path
- Size
- Checksum or verification method
- Archive timestamp
- Application version
- Project association
- Restore instructions
- Encryption information where relevant

### 12.6 Unified Finder Archive

A later release could use macOS File Provider architecture to expose a Headroom Archive in Finder. This could provide:

- Placeholders for remote files
- Download-on-demand
- Eviction controls
- Searchable metadata
- Provider abstraction
- A consistent restore experience

This would be differentiating but technically complex. It should follow validated demand for offloading.

### 12.7 Hosted Headroom Vault

A possible future hosted tier could offer:

- Client-side encryption
- Automatic deduplication
- Cold-storage economics
- Finder integration
- One-click restore
- Project-based retention policies

This creates recurring revenue but also introduces major obligations in security, durability, billing, bandwidth, support, and disaster recovery.

**Recommendation:** Do not launch a proprietary storage service in the first releases. Prove the offloading workflow with users’ existing providers first.

---

## 13. AI-Native Product Design

AI should improve interpretation, planning, and personalization. It should not become an unbounded filesystem operator.

### 13.1 Product Principle

> **AI recommends; deterministic systems execute.**

The source of truth should be a structured local storage graph. A model may explain or classify that graph, but file operations must be implemented as typed, validated, permission-scoped actions.

### 13.2 Storage Graph

A conceptual graph may include:

```text
Files → folders → applications → projects → devices → cloud accounts
     ↘ duplicate groups
     ↘ generated assets
     ↘ archive receipts
     ↘ action history
     ↘ user policies
```

### 13.3 Natural-Language Storage Search

Users should be able to ask:

- What caused my storage to drop this week?
- Find things I can remove without touching my photos.
- Show completed client projects larger than 20 GB.
- Which files are both on this Mac and in the cloud?
- Find videos I exported but probably no longer need locally.
- What is the safest way to recover 50 GB?

Answers should return structured, selectable results rather than only conversational prose.

### 13.4 Project Understanding

AI can associate files into project groups using:

- Folder relationships
- Names
- Timestamps
- File metadata
- Applications used
- Common source and output patterns
- User corrections

A creative project may include:

- Source media
- Project files
- Render cache
- Proxies
- Exports
- Delivery packages
- Supporting documents

This enables recommendations such as:

> The final export was created and this project has been inactive for four months. Archive the source and project files, then remove the replaceable render cache.

### 13.5 Lifecycle Classification

Items may be classified as:

- Active
- Reference
- Archive
- Replaceable
- Generated
- Exact duplicate
- Near duplicate
- Cloud-backed
- Sensitive
- Unknown

The most important distinction is not large versus small. It is:

> **Unique and valuable versus recoverable and replaceable.**

### 13.6 Personalized Risk Modeling

The product can learn preferences such as:

- Always keep original camera media.
- Delete installers quickly.
- Archive completed client work.
- Treat Downloads as temporary.
- Never touch family folders.
- Prefer iCloud for personal files and Google Drive for work files.

Preferences should remain visible and editable.

### 13.7 Duplicate and Similarity Intelligence

Use deterministic methods for exact duplicates:

- File-size prefiltering
- Cryptographic hashes
- Canonical-copy protection

Use machine learning only for ambiguous similarity:

- Resized or recompressed images
- Nearly identical videos
- Multiple exports of the same document
- Screenshots containing the same information

The interface must never describe a semantic near-match as an exact duplicate.

### 13.8 Anomaly Detection and Explanation

The system should detect unusual growth and explain it:

> Storage increased unusually quickly this week because Zoom saved seven local recordings and a game downloaded a 14 GB update.

The statistical system detects the anomaly. The language layer explains the evidence.

### 13.9 Natural-Language Policies

Users may express policies such as:

- Always keep at least 75 GB free.
- Keep current client projects local.
- Offer to archive completed projects after 90 days.
- Never recommend deleting RAW images.
- Remove local copies of verified iCloud files after 60 days without use.

The model should translate these into visible deterministic rules. The rule engine, not the language model, should execute them.

### 13.10 Constrained Agentic Plans

The assistant may create a proposed plan:

> To recover 60 GB with low risk, remove 24 GB of verified cloud-backed local copies, remove 12 GB of generated developer data, and archive one 31 GB inactive project.

The execution layer should accept only defined operations such as:

- `move_to_trash(item_ids)`
- `evict_verified_local_copy(item_ids)`
- `archive_to_provider(item_ids, provider_id)`
- `run_signed_recipe(recipe_id, scope)`

The model should never receive an unrestricted delete command with an arbitrary path.

### 13.11 AI Privacy

Recommended defaults:

- Metadata-only analysis by default
- Content indexing only with explicit opt-in
- On-device embeddings and inference where practical
- No filenames or document contents sent to cloud models by default
- Clear disclosure whenever a cloud model is used
- Local storage of user preference models
- User controls to inspect and delete learned data

---

## 14. Differentiation and Defensibility

Software features are increasingly easy to reproduce. Headroom needs a product system that becomes stronger over time.

### 14.1 Longitudinal Understanding

Most utilities show a snapshot. Headroom should know:

- What changed
- How quickly storage is growing
- Which sources recur
- Which projects are active
- Which recommendations the user trusts
- When intervention will be needed

A new competitor will not immediately possess the user’s history.

### 14.2 Recoverability Graph

Headroom should know whether each item is:

- Unique
- Duplicated
- Generated
- Downloadable again
- Verified in a cloud account
- Part of an active workflow
- Protected by a user policy

This makes recommendations materially safer and more useful.

### 14.3 Closed-Loop Actions

It is easy to display advice. It is harder to reliably:

- Upload
- Resume
- Verify
- Catalog
- Evict
- Restore
- Measure physical space recovered

Operational reliability can become a meaningful moat.

### 14.4 Domain Playbook Library

A growing collection of version-aware storage recipes for developer, creative, and productivity workflows can become proprietary product knowledge.

### 14.5 Trust and Reversibility

Every action is a trust event. A single harmful deletion can outweigh many successful recommendations.

The brand promise should be:

> **No surprises. No scare tactics. No permanent action without a clear explanation and recovery path.**

### 14.6 Focused Category Ownership

Avoid expanding too early into generic Mac optimization. Own proactive storage management first.

---

## 15. Trust, Safety, and Automation

### 15.1 Progressive Trust Modes

#### Observer

- Read-only analysis
- Storage history
- Forecasts
- No file changes

#### Advisor

- Recommendations
- Previews
- User approval required
- Reversible actions preferred

#### Autopilot

- Only explicitly approved rules
- Limited to low-risk actions
- Full logs and notifications
- Easy pause and rollback where available

Autopilot should be earned through successful Advisor usage, not presented as the default during onboarding.

### 15.2 Safety Rules

- Never permanently delete unique files by default.
- Never remove a local file based only on an unverified assumption that it exists remotely.
- Never claim recovered space before checking actual disk allocation.
- Never run an application-specific recipe outside its supported versions without warning.
- Preserve a durable action log.
- Provide preview and item-level exclusions.
- Make protected paths and categories easy to define.
- Treat conflicting signals as uncertainty, not confidence.

### 15.3 Action History

The history should record:

- Time
- Action
- Items affected
- Estimated versus actual space recovered
- User or policy that initiated it
- Verification results
- Restore path
- Errors and partial completion

---

## 16. Technical Architecture

### 16.1 High-Level Architecture

```text
Progressive filesystem scanner
            ↓
Persistent local storage index
            ↓
Storage graph and history ledger
            ↓
Deterministic rules + AI interpretation
            ↓
Ranked action planner
            ↓
Transactional action executor
            ↓
Local filesystem and cloud connectors
```

### 16.2 Native Mac Application

A likely implementation stack:

- Swift
- SwiftUI, with AppKit where deeper macOS integration is needed
- A background indexing service
- SQLite or another embedded local database
- Filesystem event monitoring
- Quick Look integration
- Finder reveal and contextual actions
- Menu-bar companion
- Core ML or Apple on-device model frameworks where appropriate

### 16.3 Scanner and Indexer

The scanner should:

- Produce partial results quickly.
- Prioritize the user’s home directory and high-probability growth areas.
- Avoid hashing every file during the initial scan.
- Hash only likely duplicate candidates.
- Track logical and physically allocated size separately.
- Understand hard links, clones, sparse files, and local snapshots where feasible.
- Treat cloud placeholders differently from downloaded files.
- Reconcile periodically in case filesystem events are missed.
- Degrade gracefully when permissions are limited.

### 16.4 Incremental Monitoring

Use filesystem-change events to update the index after the initial scan. A periodic reconciliation pass should correct missed or ambiguous events.

The historical ledger should store summarized deltas so the product can answer “what changed” without retaining excessive sensitive metadata.

### 16.5 Suggested Data Entities

- Device
- Volume
- Storage account
- File item
- Folder item
- Application
- Project
- Duplicate group
- Archive receipt
- Recommendation
- Action
- Policy
- User preference
- Storage event
- Recipe

### 16.6 Permissions

macOS permissions will materially affect product design.

The product should support:

- A limited mode that works with accessible and user-selected folders
- A clearly explained whole-disk mode requiring broader access
- Contextual permission requests only when the benefit is clear
- A permissions health screen showing what is and is not currently visible

A directly distributed and notarized build may be appropriate for a serious system utility, but distribution strategy should be validated against sandbox and store constraints.

### 16.7 Performance Targets

Initial performance targets should include:

- Useful partial results within seconds
- Initial high-level home-folder summary quickly enough to feel interactive
- Background indexing that does not noticeably affect normal work
- Incremental updates without recurring full scans
- On-demand deep duplicate analysis
- Resumable cloud transfers
- Reliable operation on low-free-space systems

Exact targets should be finalized after prototyping on a representative range of drive sizes and file counts.

---

## 17. Privacy and Security

### 17.1 Privacy Principles

- Local-first by default
- Collect the minimum metadata necessary
- Explain why each permission is needed
- Avoid uploading filenames or contents without explicit consent
- Encrypt sensitive local databases where appropriate
- Allow users to exclude paths and categories
- Provide a clear “delete my Headroom data” control

### 17.2 Cloud Credentials

- Use provider-supported authentication flows.
- Store tokens using secure system facilities.
- Request the smallest practical scopes.
- Make connected accounts and permissions visible.
- Allow immediate disconnection.

### 17.3 Hosted Storage Considerations

A future hosted storage product would require:

- Strong encryption design
- Documented durability and redundancy
- Incident response
- Account recovery
- Data-deletion guarantees
- Regional and regulatory considerations
- Bandwidth and egress policies
- Backup and disaster-recovery procedures

These obligations are a major reason to delay a proprietary vault until the product has validated demand.

---

## 18. Release Strategy

The release sequence should prove the product thesis in increasing levels of complexity and trust.

---

## 19. Phase 0 — Discovery and Technical Validation

### 19.1 Objective

Validate that Headroom can create a fast, accurate storage history and produce recommendations users trust more than traditional disk explorers.

### 19.2 Key Questions

- Can a persistent index stay accurate without frequent full scans?
- Can the product explain storage growth in a way users immediately understand?
- Which recommendations produce the most value for the first target audience?
- What permissions are required for a useful initial experience?
- Which physical-size edge cases create misleading estimates?
- How willing are users to grant whole-disk access?
- Which cloud provider should be integrated first?

### 19.3 Prototype Scope

- Progressive home-folder scanner
- Basic storage ledger
- “What changed?” view
- Safe reserve and runway
- Large recent files
- Initial exact-duplicate analysis
- One developer or creative playbook
- Recommendation-card prototype

### 19.4 User Research

Conduct interviews and observed cleanup sessions with approximately:

- 8–12 developers
- 8–12 creative professionals
- 5–8 general power users

Observe:

- How they discover a storage problem
- Which tools they currently use
- How they decide whether a file is safe
- Which folders they avoid
- Whether they prefer deleting, archiving, or moving
- How they currently use cloud storage
- What evidence they need before trusting an action

### 19.5 Exit Criteria

Proceed to Release 1 when:

- The scanner provides useful results quickly on representative machines.
- Historical deltas remain acceptably accurate.
- Test users understand protected headroom and runway.
- At least several recommendation types are consistently judged useful and safe.
- The product can identify actual reclaimed physical space with acceptable accuracy.

---

## 20. Release 1 — Storage Advisor

### 20.1 Product Goal

Prove that Headroom can keep users informed and help them recover space faster than a traditional disk inventory tool.

### 20.2 Core Promise

> Tell me what changed, show me the safest actions, and help me recover healthy headroom.

### 20.3 Must-Have Features

#### Monitoring and Health

- Progressive initial scan
- Persistent local storage index
- Free-space balance
- Configurable safe reserve
- Storage growth rate
- Runway forecast
- Menu-bar health indicator

#### Explanation

- “What changed?” by day and week
- Largest recent growth sources
- Application, folder, and file-type breakdowns
- Basic anomaly detection
- Weekly storage statement

#### Recommendations

- Ranked Action Center
- Large recent files
- Old installers and archives
- Exact duplicate detection on demand
- Cloud-backed local-copy identification where reliably available
- Initial app-specific generated-data recipes
- Preview, exclusions, and confidence indicators

#### Actions

- Reveal in Finder
- Quick Look
- Move to Trash
- Supported low-risk recipe execution
- Action history
- Actual-space-recovered verification

#### Safety and Privacy

- Observer and Advisor trust modes
- Protected folders and categories
- Local-first processing
- Clear permissions health view

### 20.4 Should-Have Features

- Natural-language questions over structured metadata
- Storage target plans such as “recover 30 GB”
- Recommendation feedback reasons
- Saved filters
- Multiple volume support
- External-drive visibility

### 20.5 Explicitly Deferred

- Full cloud archiving
- Proprietary hosted storage
- Automatic cleanup rules
- Cross-device dashboard
- Near-duplicate media analysis
- Finder-based unified archive

### 20.6 Release 1 Success Criteria

- Users can identify the main cause of recent storage growth without browsing the full directory tree.
- Median time to recover a healthy reserve is materially lower than the user’s previous workflow.
- A meaningful percentage of recommendation cards are accepted.
- Incorrect or unsafe recommendation reports are rare.
- Users return before reaching an emergency low-storage state.

---

## 21. Release 1.1 — Recommendation Quality and Playbooks

### 21.1 Objective

Improve trust, relevance, and value per recommendation before adding major cloud complexity.

### 21.2 Features

- More developer playbooks
- More creative playbooks
- Better application attribution
- Improved inactivity and project-state heuristics
- Recommendation suppression and learning
- Better low-space operation
- More accurate physical-size accounting
- Enhanced weekly statements
- Recommendation explanation improvements

### 21.3 Exit Criteria

- Recommendation acceptance rises over time.
- Repeated irrelevant recommendations decline.
- At least one target persona consistently recovers substantial space through domain playbooks.
- Trust incidents remain below a defined critical threshold.

---

## 22. Release 2 — Verified Offloader

### 22.1 Product Goal

Move Headroom from cleanup advisor to storage-placement system.

### 22.2 Core Promise

> Move inactive data out of local storage without losing access or confidence.

### 22.3 Must-Have Features

- iCloud Drive local-copy removal workflows
- Google Drive connector
- OneDrive connector
- Resumable large uploads
- Remote verification
- Archive receipts
- Unified Archive catalog
- Searchable archived items
- One-click restoration
- Transfer status and error recovery
- Provider capacity visibility where available
- Original-path preservation

### 22.4 Recommendation Examples

- Remove a verified local copy already available in iCloud.
- Archive an inactive project to Google Drive.
- Move old source media to an external drive.
- Place personal files in iCloud and work projects in Google Drive according to user policy.

### 22.5 Safety Requirements

- No local removal before remote verification.
- Clear distinction between cloud deletion and local eviction.
- Durable archive receipts.
- Recovery testing across supported providers.
- Graceful interruption and resume behavior.
- Clear partial-failure states.

### 22.6 Deferred

- Headroom-hosted storage
- Full File Provider virtual drive
- Broad automatic offloading

### 22.7 Release 2 Success Criteria

- Very high verified-upload success rate.
- Low restore failure rate.
- Users recover substantial local capacity through offloading.
- Users can find and restore archived files without remembering the provider location.
- Support burden from transfer ambiguity remains manageable.

---

## 23. Release 2.1 — Project-Aware Archiving

### 23.1 Objective

Make Headroom understand collections of files as projects rather than isolated items.

### 23.2 Features

- Project clustering
- Active versus inactive project signals
- Source, cache, export, and delivery-role classification
- Project-level archive plans
- Project-level restore
- User correction tools
- Archive-provider recommendations

### 23.3 Success Criteria

- Project groupings are judged accurate enough to save meaningful review time.
- Users accept project-level recommendations.
- Corrections improve future grouping behavior.

---

## 24. Release 3 — Storage Autopilot

### 24.1 Product Goal

Allow users to delegate recurring low-risk storage management through explicit policies.

### 24.2 Core Promise

> Maintain my storage reserve according to rules I understand and control.

### 24.3 Must-Have Features

- Natural-language policy creation
- Structured rule preview
- Advisor-to-Autopilot promotion flow
- Low-risk automatic actions
- Policy simulation before activation
- Notification and action log
- Easy pause and undo where available
- Personalized recommendation ranking
- Anomaly-response policies

### 24.4 Example Policies

- Keep at least 75 GB free.
- Remove local copies of verified iCloud files after 60 inactive days.
- Ask before archiving inactive client projects.
- Automatically clear supported regenerable caches when free space drops below 50 GB.
- Never take automatic action inside family photos or current client folders.

### 24.5 Automation Boundaries

Automatic actions should initially be limited to:

- Verified cloud-backed local-copy eviction
- Clearly regenerable caches through supported recipes
- User-designated temporary folders
- Explicitly approved retention rules

Unique-file deletion should remain manually approved.

### 24.6 Success Criteria

- Users remain above their reserve more consistently.
- Automated actions have an extremely low incident rate.
- Policy simulations accurately describe expected effects.
- Users understand why each automatic action occurred.
- Autopilot reduces emergency cleanup sessions without increasing anxiety.

---

## 25. Release 4 — Unified Personal Storage Layer

This phase should remain conditional on evidence from earlier releases.

Potential capabilities:

- Headroom Archive in Finder using File Provider architecture
- Multi-Mac storage dashboard
- Shared household or team policies
- Provider-agnostic placement
- Remote archive search across accounts
- Optional Headroom Vault
- Cross-device project state
- Storage-cost optimization

This is a platform expansion, not an early product requirement.

---

## 26. Prioritization Framework

Every proposed feature should be evaluated against the following questions:

1. Does it help prevent a low-storage emergency?
2. Does it improve understanding of what changed?
3. Does it make a recommendation safer or more actionable?
4. Does it reduce the time required to recover space?
5. Does it improve reversibility or trust?
6. Does it strengthen longitudinal knowledge or domain expertise?
7. Can it be implemented without broadening the product into a generic utility?

Features that do not support the core promise should be deferred.

### 26.1 Suggested Scoring

Score each feature from 1–5 on:

- User impact
- Frequency of need
- Differentiation
- Trust improvement
- Strategic learning
- Engineering effort
- Operational risk

A simple prioritization score can weight the first five factors positively and effort and risk negatively.

---

## 27. Product Metrics

### 27.1 North-Star Metric

A strong north-star metric is:

> **Percentage of active-user days spent above the user’s protected storage reserve.**

This measures whether Headroom is actually keeping the machine healthy.

### 27.2 Core Outcome Metrics

- Median time to restore healthy headroom
- Emergency low-storage events per active user
- Space recovered per approved action
- Recommendation acceptance rate
- Percentage of recommendations dismissed as irrelevant or unsafe
- Forecast accuracy
- Difference between estimated and actual recovered physical space
- Verified offload success rate
- Restore success rate
- Policy execution success rate

### 27.3 Engagement Metrics

- Weekly statement open rate
- Action Center visits
- Active reserve configuration rate
- Percentage of users connecting a cloud provider
- Percentage of users creating a policy
- Observer-to-Advisor conversion
- Advisor-to-Autopilot conversion

### 27.4 Trust Metrics

- Incorrect recommendation reports
- Accidental-deletion incidents
- Restore failures
- Cloud verification failures
- Permissions-related confusion
- Recommendation suppression frequency
- Autopilot reversals

A destructive-action incident rate should be treated as a critical quality metric, not a normal support metric.

### 27.5 Avoided Incentives

Do not use “gigabytes deleted” as the primary success metric. It can reward aggressive or low-quality recommendations. Headroom should optimize for healthy capacity and user confidence, not maximum deletion.

---

## 28. Business Model

### 28.1 Recommended Structure

#### Free or Trial

- Storage health dashboard
- Limited history
- Manual exploration
- Limited recommendations or actions

#### Pro

- Continuous monitoring
- Full history and forecasting
- Advanced recommendations
- Domain playbooks
- AI-assisted search and explanation
- Policies
- Bring-your-own-cloud connectors
- Multi-volume support

#### Vault

- Optional hosted storage
- Separate storage-based billing
- Advanced archive and restore capabilities

### 28.2 Pricing Considerations

A subscription is defensible because the product includes:

- Continuous monitoring
- Ongoing application recipe maintenance
- Cloud connector maintenance
- AI and classification improvements
- Support for operating-system changes

A one-time local license could also be tested, but recurring value aligns naturally with a Pro tier.

### 28.3 Packaging Principle

The local product must remain valuable without forcing users into proprietary storage. Headroom Vault should be an optional convenience and trust offering, not a requirement for basic usefulness.

---

## 29. Go-to-Market Strategy

### 29.1 Initial Positioning Message

> Never be surprised by a full Mac again. Headroom shows what changed, predicts when space will run out, and gives you safe actions to recover it.

### 29.2 Strong Demo Narrative

1. Headroom shows that the Mac will cross its safe reserve in nine days.
2. It explains that screen recordings, Docker data, and two inactive projects account for most of the growth.
3. It proposes three low-risk actions worth 63 GB.
4. The user approves an iCloud local-copy removal and a generated-data cleanup.
5. Headroom verifies the actions and updates the runway to more than a month.

This story communicates the product more effectively than a folder-size visualization.

### 29.3 Acquisition Wedges

Potential early channels:

- Developer communities
- Creative professional communities
- Mac productivity publications
- YouTube demonstrations of storage investigations
- Partnerships with Mac-focused software bundles
- SEO around specific storage problems such as Xcode, Docker, video cache, and screen recordings

### 29.4 Content Strategy

Create high-trust educational content:

- Why Mac storage disappears
- What is safe to remove from common applications
- Local versus cloud storage behavior
- How to archive completed creative projects
- How to preserve a safe reserve

Content should reinforce expertise without using scare tactics.

---

## 30. Risks and Mitigations

### 30.1 Trust Failure

**Risk:** A bad recommendation or accidental deletion damages the brand.

**Mitigation:** Favor reversible actions, require verification, use confidence thresholds, preview affected items, maintain action logs, and keep high-risk actions manual.

### 30.2 Misleading Space Estimates

**Risk:** Logical size, clones, hard links, sparse files, snapshots, and cloud placeholders cause incorrect recovery estimates.

**Mitigation:** Track physical allocation where possible, clearly label estimates, test edge cases, and verify actual recovered space after actions.

### 30.3 Permission Friction

**Risk:** Users decline broad access or do not understand why it is needed.

**Mitigation:** Provide a useful limited mode, request permissions contextually, show permission status, and explain specific value.

### 30.4 Slow Initial Scan

**Risk:** The product feels no better than existing disk inventory tools.

**Mitigation:** Progressive results, prioritized scanning, persistent index, incremental updates, and deferred hashing.

### 30.5 Cloud Transfer Failure

**Risk:** Interrupted uploads, provider limits, or ambiguous sync states lead to data loss or support burden.

**Mitigation:** Resumable transfers, durable receipts, remote verification, clear state machines, retries, and no local removal before confirmation.

### 30.6 AI Hallucination

**Risk:** The assistant incorrectly describes a file or recommends an unsafe action.

**Mitigation:** Ground explanations in structured evidence, expose uncertainty, prohibit free-form filesystem operations, and require deterministic validation.

### 30.7 Commodity Feature Competition

**Risk:** Competitors copy visible features quickly.

**Mitigation:** Build longitudinal history, user preference models, domain recipes, recoverability knowledge, and reliable execution infrastructure.

### 30.8 Scope Expansion

**Risk:** The product becomes a generic Mac cleaner and loses differentiation.

**Mitigation:** Use the core promise and prioritization questions as explicit roadmap gates.

### 30.9 Provider Dependency

**Risk:** Cloud APIs, pricing, or platform policies change.

**Mitigation:** Use provider abstractions, support multiple providers, preserve portable archive metadata, and avoid locking core value to one platform.

---

## 31. Validation Plan

### 31.1 Problem Validation

Questions to test:

- How frequently do target users approach their limit?
- How long does each cleanup session take?
- What do users fear deleting?
- What evidence creates confidence?
- Are users more interested in deletion, offloading, or prevention?
- Do users understand and value a safe reserve?

### 31.2 Concept Validation

Prototype and test:

- Protected headroom
- Runway
- What Changed
- Ranked action cards
- Recoverability labels
- Storage statement
- “Recover 50 GB safely” plan

### 31.3 Trust Validation

Test whether users understand:

- Local copy versus cloud copy
- Exact duplicate versus similar file
- Generated versus unique data
- Reversible versus permanent action
- Confidence and risk labels

### 31.4 Willingness-to-Pay Validation

Test pricing around:

- A local monitoring and recommendation product
- A Pro subscription with cloud connectors
- Optional hosted storage
- Professional playbook packs, if packaging them separately is considered

### 31.5 Technical Validation Matrix

Test on:

- Different Mac hardware generations
- Small and large SSDs
- Very high file counts
- Low-free-space conditions
- APFS clones and hard links
- Local snapshots
- iCloud placeholders
- External drives
- Network interruptions
- Multiple cloud providers
- Protected folders and limited permissions

---

## 32. Open Product Decisions

The following decisions should be resolved through research and prototypes:

1. Is Headroom the final product name?
2. Which persona is the launch wedge: developers, creatives, or broad power users?
3. What should the default safe reserve be: fixed gigabytes, percentage, or an adaptive value?
4. How much history should be stored locally?
5. Which metadata is necessary to attribute growth to applications?
6. Which three playbooks produce the strongest launch value?
7. Should Release 1 include basic natural-language search or defer it until the structured experience is mature?
8. Which cloud provider should follow iCloud first?
9. What is the appropriate boundary between the Mac App Store and direct distribution?
10. Which actions are safe enough for the first Autopilot release?
11. How should the product price Pro without making a local utility feel artificially subscription-dependent?
12. What evidence would justify building Headroom Vault?

---

## 33. Recommended Initial Decisions

Until research proves otherwise, use these defaults:

- **Working name:** Headroom
- **Platform:** macOS only
- **Launch wedge:** developers and creative professionals
- **Primary health model:** protected reserve plus runway
- **Primary interface:** dashboard and Action Center
- **Secondary interface:** disk explorer or treemap
- **Default trust mode:** Observer, followed by Advisor
- **Automation:** deferred until a later release
- **AI:** local-first interpretation and policy translation
- **Cloud:** bring-your-own-provider first
- **Hosted storage:** deferred
- **Distribution:** investigate direct, notarized distribution first
- **Brand stance:** calm, precise, transparent, and non-alarmist

---

## 34. Product Principles

1. **Prevent the emergency.** The best cleanup session is the one the user never has to initiate.
2. **Explain before acting.** Every recommendation needs evidence and understandable consequences.
3. **Prefer reversible actions.** Offload, evict, move to Trash, or regenerate before permanent deletion.
4. **Measure physical outcomes.** Report actual space recovered, not only nominal file size.
5. **AI advises; deterministic systems execute.** Models must not have unrestricted file-operation authority.
6. **Respect active work.** Project context matters more than raw size.
7. **Build trust progressively.** Observer, then Advisor, then narrowly scoped Autopilot.
8. **Stay local-first.** User files and metadata should remain on the device unless the user explicitly chooses otherwise.
9. **Avoid shame and scare tactics.** Storage is a resource to plan, not a moral failure.
10. **Own the category before expanding.** Do not become a generic Mac utility suite too early.

---

## 35. The Minimum Lovable Product

The minimum lovable version of Headroom should solve one repeated situation exceptionally well:

> “I am approaching my safe limit. Tell me what changed, show me the safest three actions, and complete them without losing anything.”

A credible first release does not need to manage every cloud provider or understand every project type. It does need to feel dramatically faster, clearer, and safer than opening a traditional disk inventory tool.

The signature first-release experience should be:

1. Headroom opens quickly with an already-current index.
2. It shows free space, reserve, and runway.
3. It explains the recent change.
4. It recommends three high-value actions.
5. The user previews and approves an action.
6. Headroom completes and verifies it.
7. The dashboard immediately shows the recovered headroom.

---

## 36. Final Product Thesis

Headroom should not compete on scanning alone. Fast scanning is necessary, but it is not the product.

The product is the decision and trust layer between a user and all the places their data can live.

Its enduring advantage can come from understanding:

- What the data is
- Why it exists
- Whether it is active
- Whether it is unique
- Whether it is recoverable
- Where else it can safely live
- Which actions this particular user will trust

The strongest long-term version of Headroom is a personal storage operating system that continuously places data according to user intent, capacity, cost, and recoverability.

The right path begins more narrowly:

> **Understand what changed. Protect a reserve. Recommend the safest actions. Verify every result.**

---

## Appendix A — Example Recommendation Types

| Recommendation | Typical risk | Reversible | Likely release |
|---|---:|---:|---:|
| Remove verified iCloud local copies | Low | Yes | 1 or 2 |
| Remove exact duplicates while preserving canonical copies | Low | Usually | 1 |
| Delete old installers already used | Low–Medium | Via Trash | 1 |
| Clear supported application cache | Low–Medium | Regenerable | 1 |
| Review old screen recordings | Medium | Via Trash | 1 |
| Archive inactive project to existing cloud provider | Medium | Yes | 2 |
| Remove project render cache after archive | Low–Medium | Regenerable | 2.1 |
| Identify near-duplicate photos or videos | Medium | Review required | 2.1 or 3 |
| Automatically evict verified cloud-backed files | Low | Yes | 3 |
| Permanently delete unique files | High | No | Manual only |

---

## Appendix B — Example Recommendation Object

```yaml
recommendation_id: rec_123
kind: verified_cloud_eviction
title: Remove local copies already stored in iCloud
estimated_physical_recovery_bytes: 26628797235
item_count: 142
risk: low
confidence: high
reversible: true
restore_method: Download from iCloud on demand
evidence:
  - All items have verified iCloud state
  - Items have not been opened in 90 days
  - Items are outside protected paths
actions:
  primary: Evict local copies
  secondary:
    - Preview items
    - Exclude selected items
    - Never suggest this folder
```

---

## Appendix C — Example Policy Object

```yaml
policy_id: policy_456
name: Protect active client work
conditions:
  all:
    - project_type: client
    - last_activity_days_less_than: 45
actions:
  - prohibit_automatic_eviction
  - prohibit_cleanup_recipes
notifications:
  - alert_if_project_growth_exceeds_gb_per_week: 20
source_text: Keep current client projects local and warn me if one grows by more than 20 GB in a week.
```

---

## Appendix D — Reference Links

- [Apple: Optimize storage space on Mac](https://support.apple.com/guide/mac-help/optimize-storage-space-sysp4ee93ca4/mac)
- [Apple Developer: File System Events](https://developer.apple.com/documentation/coreservices/file_system_events)
- [Apple Developer: File Provider](https://developer.apple.com/documentation/fileprovider/synchronizing-files-using-file-provider-extensions)
- [Apple Developer: Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- [Google Drive API: Manage uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads)
- [DaisyDisk](https://daisydiskapp.com/)

