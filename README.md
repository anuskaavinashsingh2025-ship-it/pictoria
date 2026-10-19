# Pictora — Smart Gallery & Media Organizer

**A calm, friendly photo gallery that helps you tidy up your phone without the fear of deleting something by accident.**

Built with Flutter for iOS and Android.

---

## Table of contents

1. [Overview](#1-overview)
2. [Key features](#2-key-features)
3. [Tech stack and architecture](#3-tech-stack-and-architecture)
4. [Project structure](#4-project-structure)
5. [Setup and running](#5-setup-and-running)
6. [Permissions and platform behavior](#6-permissions-and-platform-behavior)
7. [Testing](#7-testing)
8. [Performance strategy for large media collections](#8-performance-strategy-for-large-media-collections)
9. [Known limitations](#9-known-limitations)
10. [Building an Android release APK](#10-building-an-android-release-apk)
11. [Manual testing checklist for reviewers](#11-manual-testing-checklist-for-reviewers)
12. [Credits](#12-credits)

---

## 1. Overview

Most people have thousands of photos and videos they never look at. Phones fill up, but cleaning up feels risky and tedious: one wrong tap and a memory is gone.

Pictora makes cleanup light and safe:

- **Browse** the device library in a fast, pleasant gallery.
- **Review** items one at a time with a swipe: keep it, or mark it for deletion.
- **See** what is actually using storage, such as large videos.
- **Delete only when sure**, through a separate confirmation flow that ends with the phone's own system prompt.

The visual style is "Soft Pop": warm cream backgrounds, pastel accents, rounded cards and gentle motion, so the app feels calm rather than like a cleanup tool.

---

## 2. Key features

### Onboarding
- A three-page welcome carousel that introduces the app, with a Skip button.
- It never asks for photo access. The app asks only when the user chooses to connect their library.

### Device gallery
- Photos and videos from the device library, grouped by day ("Today", "Yesterday", weekday names, then full dates) in a masonry grid.
- Video tiles show their duration. A heart on each tile marks Pictora favorites.
- **Demo mode:** if photo access isn't granted, or the library is empty, Pictora shows bundled sample photos and short video clips, so every screen can be tried without real data. A Library sheet switches between "My photo library" and "Demo photos" at any time.
- Pull to refresh, plus clear states for loading, empty results, errors (with Retry) and each permission state.

### Search
- A "Find a memory…" field that searches on the device: titles, tags (demo media), file type, the word "video", and date words such as "yesterday", "october" or "2025".

### Filters and sorting
- **Quick filters:** All, Photos, Videos, Favorites.
- **Filters sheet:** sort by Newest, Oldest, Largest or Smallest, and filter by a file-size range.
- A badge on the filter button shows when filters are active.

### Photo and video viewer
- Full-screen viewer with a Hero animation from the grid.
- **Photos:** pinch to zoom (up to 4×).
- **Details:** title, date, pixel size, duration, file type, file size, and whether the item is a favorite in the system Photos app. File type and size are fetched only when an item is opened.

### Video playback
- Real playback using the official `video_player` package: a play/pause button (it becomes a replay button at the end), a draggable progress bar, and elapsed / total time.
- A loading state (the thumbnail with a spinner) and an error state ("This video can't be played right now.").
- **No autoplay.** Playback pauses when the app goes to the background, and the player is released when the viewer closes, even if it is still loading.
- Works with device videos and with the bundled demo clips.

### Swipe-based review
- One card at a time: **swipe right (or tap Keep) to keep, swipe left (or tap Mark for deletion) to mark**.
- KEEP / DELETE labels grow as the card is dragged, and the next card peeks out behind it.
- A progress indicator, and a summary at the end that states clearly that nothing has been deleted.
- Decisions are saved on the device with `shared_preferences`, so they survive app restarts.

### Undo
- An Undo button reverses the last decision and slides the card back in. The history covers multiple steps.

### Safe deletion workflow
Swiping only *marks* an item. Deletion is a separate flow:

1. **Deletion queue:** lists every marked item. Items can be deselected or sent back to review.
2. **Confirmation screen:** explains in plain words what will happen on this phone:
   - **iOS:** items move to "Recently Deleted" for 30 days.
   - **Android 11+:** items move to the system trash for about 30 days.
   - **Android 10 and below:** deletion is permanent, and the screen says so.
3. **System prompt:** the operating system's own dialog has the final say.
4. **Honest result:** only items the platform confirms as removed leave the queue. Cancelled or failed items stay, and items already deleted elsewhere are detected and cleared.

Demo items can never be deleted.

### Storage insights
- **Device storage** from the operating system, and how much of it the photo library uses, shown as a donut chart (photos, videos, everything else, free space).
- **Large videos** (100 MB or more), biggest first, each one easy to add to the deletion queue. A "Reclaim up to …" card shows their total size, labelled as an estimate.
- **Deletion summary:** the items waiting to be deleted, what deleting them does on this platform, and buttons to continue to delete or review them.
- **Honesty rules:** totals come from the OS and library sizes are measured file by file. Nothing is guessed: the Duplicates card says plainly that duplicate detection isn't available yet.

### Accessibility
- Every custom button has a screen-reader label and exposes a tap action, so VoiceOver and TalkBack can activate it. A dedicated test (`test/semantics_actions_test.dart`) enforces this.
- Respects the system "Reduce motion" setting: swipe and page animations are turned off.
- Text colors are chosen for readable contrast (WCAG AA) on their backgrounds.
- Loading progress, such as "Measuring file sizes…", is announced as a live region.

---

## 3. Tech stack and architecture

| Area | Choice |
| --- | --- |
| Framework | Flutter (Dart SDK `^3.13.4`), Material 3 |
| Photo library | [`photo_manager`](https://pub.dev/packages/photo_manager) `^3.12.0` |
| Video playback | [`video_player`](https://pub.dev/packages/video_player) `^2.14.1` (official Flutter package) |
| Local storage | [`shared_preferences`](https://pub.dev/packages/shared_preferences) `^2.5.6`, for review decisions and the deletion queue |
| State management | Plain `ChangeNotifier` controllers with `ListenableBuilder`. No extra framework, so it is easy to follow |
| Linting | `flutter_lints` |

### Architecture

```
 Screens (widgets)
     │  listen to
     ▼
 Controllers (ChangeNotifier)
   GalleryController · ReviewController · DeletionController · InsightsController
     │  talk only to
     ▼
 MediaRepository (interface)
   ├── DeviceMediaRepository  → photo_manager (the only file that uses the plugin)
   ├── DemoMediaRepository    → bundled sample photos and clips
   └── FakeMediaRepository    → tests (no plugins, no real media)
```

- **Widgets never touch the photo library directly.** Swapping the real library for demo or test data needs no UI changes, and demo mode runs through the same code path as a real library.
- **Design tokens:** colors, spacing, radii, shadows and animation timings live in `lib/theme/app_tokens.dart`.
- **Pure helpers:** sorting, filtering, grouping, search and formatting are plain Dart functions in `lib/data/media/media_filters.dart`, so they are easy to unit-test.

---

## 4. Project structure

```
lib/
├── main.dart, app.dart          App entry and root widget
├── data/
│   ├── demo_media.dart          Bundled demo catalogue
│   ├── media/                   MediaItem model, MediaRepository interface,
│   │                            device / demo repositories, filters, thumbnails
│   └── review/                  Review records and on-device storage
├── state/                       Gallery, review, deletion and insights controllers
├── screens/
│   ├── onboarding/              Welcome carousel
│   ├── gallery/                 Gallery, viewer, video player, filters, search
│   ├── review/                  Swipe Review and its card stack
│   ├── deletion/                Deletion queue and confirmation
│   ├── insights/                Storage insights and large videos
│   └── home_shell.dart          Tabs and floating navigation bar
├── theme/                       Design tokens and text styles
└── widgets/                     Shared UI (nav bar, buttons, decorations)

assets/
├── demo_media/                  Sample photos, demo video clips, ATTRIBUTION.md
└── fonts/                       DM Serif Display

test/
├── data/                        Model, filtering, storage and demo-media tests
├── state/                       Controller tests
├── support/                     FakeMediaRepository and test helpers
└── *_test.dart                  Widget tests for each screen and flow
```

---

## 5. Setup and running

**Requirements**
- Flutter (stable channel) with Dart `3.13.4` or newer
- Xcode for iOS (deployment target iOS 15.0), or Android Studio and the Android SDK

**Install dependencies**

```bash
flutter pub get
```

**List available devices and simulators**

```bash
flutter devices
```

**Run in debug mode**

```bash
flutter run
```

To pick a device, add `-d <device-id>`.

> **Tip:** fresh simulators and emulators usually have no videos in their Photos library. Bundled demo videos play with no setup. To test a real device video on the iOS Simulator, drag an `.mp4` or `.mov` onto the simulator window (or run `xcrun simctl addmedia booted clip.mp4`), then pull to refresh in Pictora.

---

## 6. Permissions and platform behavior

Pictora only reads the library and asks the system to delete items. Media never leaves the device, and the app makes no network requests.

### iOS
| Item | Behavior |
| --- | --- |
| Permission | `NSPhotoLibraryUsageDescription`: "Pictora shows your photos and videos so you can browse and organize them. Your media stays on your device." |
| Limited access | Supported. Pictora shows a banner with a button to change the selected photos. The automatic iOS limited-access alert is turned off (`PHPhotoLibraryPreventAutomaticLimitedAccessAlert`). |
| Denied | A banner explains the situation and opens Settings. Demo photos remain available. |
| Deletion | Uses the system confirmation. Items go to "Recently Deleted" for 30 days. |
| Video | Videos are read from the library as local files and played with AVPlayer (through `video_player`). |

### Android
| Item | Behavior |
| --- | --- |
| Android 13+ | `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` |
| Android 14+ | `READ_MEDIA_VISUAL_USER_SELECTED` for partial ("selected photos") access |
| Android 12 and below | `READ_EXTERNAL_STORAGE` (`maxSdkVersion` 32) |
| Android 9 and below | `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion` 28), needed for deletion |
| Deletion | Android 11+: system trash (about 30 days). Android 10 and below: permanent, and the app says so before you confirm. |

Precise photo location is not requested.

---

## 7. Testing

The project has **158 automated tests**: unit tests and widget tests. They run against `FakeMediaRepository`, so they need no device, plugins or real photos.

**Run all tests**

```bash
flutter test
```

**Run one test file**

```bash
flutter test test/media_viewer_test.dart
```

**Static analysis and formatting**

```bash
flutter analyze
```

```bash
dart format --output=none --set-exit-if-changed .
```

**What the tests cover**
- Filtering, sorting, search, day grouping, and duration and size formatting
- Permission states, paging, source switching and refresh in the gallery controller
- Swipe Review decisions, undo, persistence and the end-of-review summary
- The deletion flow: cancelled, partial, failed, permission denied and already-deleted items
- Insights calculations, large-video detection and scan progress
- Video viewer: loading, error, no autoplay, play/pause, pausing in the background, and cleanup on close
- Screen-reader actions on every custom button

---

## 8. Performance strategy for large media collections

Pictora is designed so that browsing stays smooth regardless of library size. Operations that need information about *every* file are explicit, show progress, and are only run when needed.

### Thumbnail-based rendering
- The grid never loads original files. Each tile asks the platform for a small thumbnail sized to the tile, using a custom `ImageProvider` (`MediaThumbnailProvider`).
- Requested widths are rounded up to steps of 128 px, so tiles of slightly different sizes share one cached image.
- Because thumbnails are real `ImageProvider`s, Flutter's built-in image cache reuses them when you scroll back or return from the viewer.
- The viewer shows a screen-sized thumbnail rather than the full-resolution original, to keep memory low.

### Lazy loading and pagination
- The library is read in **pages of 120 items**. The next page loads automatically when the user scrolls within about 1,500 px of the end.
- The platform sorts by date, so paging stays consistent. Duplicate items caused by the library changing between page requests are skipped.
- The grid uses a lazily built `SliverList`, so day sections are only built when they come close to the screen.
- Loaded pages are kept per filter and survive tab switches and trips to the viewer. The library is re-read only on refresh or when access changes.
- File type and file size are fetched only when an item is opened in the viewer, not for the whole library.

### Media-size measurement and caching
- Phones don't keep file sizes in their library index, so features that need sizes (Insights, Largest/Smallest sorting and size filters) measure each file.
- Measuring reads pages of 200 items and asks for up to **8 sizes at a time**, with visible progress ("Measuring file sizes… 340 of 2000 items").
- Results are cached and reused by both the Gallery and Insights. A new scan runs only when the library changes (for example after a deletion or refresh).

### Filtering and sorting
- Date sorting (Newest/Oldest) is done by the platform, page by page, so it is fast at any size.
- Quick filters and search run in memory on the items already loaded, using pure Dart functions.
- Size-based sorting and filtering work on the fully measured library, so the first use **can take a while on large libraries** while sizes are measured. The app shows progress during this time and lets you clear the size options.

### Video player lifecycle
- One player is created only when a video is opened. There is no preloading and no autoplay.
- The player pauses when the app goes to the background and is disposed as soon as the viewer closes, including while it is still loading.

### Honest limitations
- **No benchmarks have been run.** The numbers above (page size, concurrency, thresholds) are design parameters, not measured results.
- The first size scan of a large library can take noticeable time, especially on older Android devices or with slow storage.
- On iOS, opening a video may require the system to export it to a temporary file first, which can delay playback for very large videos.

---

## 9. Known limitations

- **iCloud-only videos** are not downloaded, so videos not stored on the device show the "can't be played" message.
- The viewer shows **one item at a time**. There is no swiping between items.
- **Onboarding is shown on every launch.** Remembering that it was completed is not implemented yet.
- **Pictora favorites are kept in memory**, so they reset when the app restarts. Review decisions and the deletion queue *are* saved.
- **No duplicate or similar-photo detection.** Insights shows only measured facts.
- Video playback was verified on the iOS Simulator. **Android video playback has not been tested on a physical device.**
- The release build is signed with the default **debug key** (see below). It is suitable for testing, not for store publishing.
- Web and desktop folders exist from the Flutter template, but the photo library integration targets **iOS and Android** only.

---

## 10. Building an Android release APK

**Build the APK**

```bash
flutter build apk --release
```

**Output file**

```
build/app/outputs/flutter-apk/app-release.apk
```

**Install it on a connected Android device**

```bash
flutter install --release
```

Or with adb:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

> **Note:** `android/app/build.gradle.kts` currently signs release builds with the debug key, so the APK installs and runs for testing. Publishing to Google Play would need a proper signing key and a unique `applicationId` (currently `com.example.pictoria`).

---

## 11. Manual testing checklist for reviewers

**Onboarding and demo mode**
- [ ] Launch the app. The welcome carousel appears, and **Skip** or the arrow button opens the Gallery.
- [ ] No photo permission prompt appears during onboarding.
- [ ] Without granting access, the Gallery shows demo photos and videos, with a banner explaining demo mode.

**Library access**
- [ ] Choose to connect the library and allow access. Your own photos appear, grouped by day.
- [ ] Deny access. A banner explains it and offers to open Settings, and demo photos stay available.
- [ ] (iOS) Choose "Limit access". The banner offers to change the selected photos.
- [ ] Tap the profile button to open the Library sheet and switch between "My photo library" and "Demo photos".

**Gallery, search and filters**
- [ ] Scroll a long library. More items load automatically, and the scrolling stays smooth.
- [ ] Tap **Photos**, **Videos** and **Favorites**. The grid updates.
- [ ] Search "video", "yesterday" or a month name. The results match.
- [ ] Open Filters and sort by **Largest**. A "Measuring file sizes…" progress line appears, then the items are ordered by size.
- [ ] Set a size range. Only items in that range remain, and the filter button shows a badge.
- [ ] Tap a heart on a tile, then open **Favorites**.

**Viewer and video playback**
- [ ] Open a photo. It zooms in from the grid, pinch-to-zoom works, and the details show date, size and file type.
- [ ] Open a demo video (for example "Dog running on the beach"). It doesn't play until **Play** is tapped, then the time and progress bar advance.
- [ ] Tap **Pause**, drag the progress bar, and let it reach the end (the button becomes replay).
- [ ] While a video plays, send the app to the background and come back. The video is paused.
- [ ] Close the viewer with **✕**. The thumbnail animates back to the grid.

**Swipe Review and undo**
- [ ] Open **Review**. Swipe right to keep and left to mark for deletion, and try the buttons too.
- [ ] Tap **Undo**. The last card slides back.
- [ ] Close and reopen the app. Your review decisions are still there.

**Safe deletion** (use test photos you don't need)
- [ ] Open the deletion queue. Deselect one item and send another back to review.
- [ ] Continue. The confirmation screen explains what will happen on this platform.
- [ ] Cancel the system prompt. Nothing is deleted and the items stay in the queue.
- [ ] Confirm. Only the deleted items leave the queue, and the result screen reports the outcome.
- [ ] In demo mode, confirm that demo items can't be deleted.

**Insights**
- [ ] Open **Insights**. Device storage and the library breakdown appear after measuring, and items marked in Review appear in the deletion summary.
- [ ] If any videos are 100 MB or more, they are listed biggest first and can be added to the deletion queue.

**Accessibility**
- [ ] With VoiceOver or TalkBack on, every button is announced with a clear label and can be activated.
- [ ] With "Reduce motion" on, swipes and transitions happen without animation.

---

## 12. Credits

- Demo photos are from [Unsplash](https://unsplash.com), used under the Unsplash License. The three demo video clips are slow-zoom versions of three of those photos. Photographers are credited in [`assets/demo_media/ATTRIBUTION.md`](assets/demo_media/ATTRIBUTION.md).
- The headline font is DM Serif Display, licensed under the SIL Open Font License 1.1.
