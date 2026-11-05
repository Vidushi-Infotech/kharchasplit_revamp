# Store listing (ASO)

The text for both store pages lives next to each platform, in the folder
layout fastlane uses, so it can be pasted by hand or uploaded with
`fastlane supply` / `fastlane deliver`.

| Store | Folder | Languages |
|---|---|---|
| Google Play | `android/fastlane/metadata/android/<lang>/` | `en-US`, `hi-IN` |
| App Store | `ios/fastlane/metadata/<lang>/` | `en-US`, `hi` |

## Where each file goes

**Play Console → Grow → Store presence → Main store listing**

| File | Field | Limit |
|---|---|---|
| `title.txt` | App name | 30 |
| `short_description.txt` | Short description | 80 |
| `full_description.txt` | Full description | 4000 |
| `changelogs/<versionCode>.txt` | Release notes (on the release) | 500 |

Hindi: *Manage translations → Add your own translations → Hindi (hi-IN)*, then
paste the `hi-IN` files.

**App Store Connect → the app → the new version (3.5.0)**

| File | Field | Limit | Needs a new version? |
|---|---|---|---|
| `name.txt` | Name (App Information) | 30 | yes |
| `subtitle.txt` | Subtitle (App Information) | 30 | yes |
| `keywords.txt` | Keywords | 100 | yes |
| `description.txt` | Description | 4000 | yes |
| `promotional_text.txt` | Promotional Text | 170 | no, edit any time |
| `release_notes.txt` | What's New | 4000 | yes |

Hindi: add *Hindi* from the language menu at the top right of the version page,
then paste the `hi` files.

## Rules (a listing can be rejected for these)

- No other app's name anywhere (e.g. "Splitwise"), not even in keywords.
- No "best", "#1", "free" or emoji in the title / name.
- App Store keywords: commas, no spaces after them, and no word that is already
  in the name or subtitle (it is counted anyway).
- Only claim what the app does. Update the text when a feature changes.

## After it goes live

- Watch Play Console → *Store performance* and App Store Connect →
  *App Analytics* for 2–4 weeks before changing keywords again.
- Reply to reviews, especially low ratings.
- The app asks for a rating by itself (see `lib/core/services/review_prompt.dart`):
  after 3 saved expenses / payments, at least 3 days after the first, at most
  once every 120 days and 3 times in all. Account → *Rate KharchaSplit* opens
  the store page.
