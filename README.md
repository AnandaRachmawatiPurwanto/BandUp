# BandUp

A macOS app for IELTS practice. It interrupts you with short vocabulary quizzes during the day, labels every word with its CEFR level (A1–C2), and gives feedback on your speaking and writing using Apple's on-device AI. It's free, works offline, and nothing leaves your Mac.

## Features

- **Surprise word pop-ups.** Five times a day by default, a notification shows a word and its level (e.g. *despise · B2*). You type a sentence using the word straight into the notification and get feedback a few seconds later: your own sentence with the mistakes fixed, plus another example of how to use the word.
- **Spaced repetition.** A word you get right comes back after 1, 3, 7, 14, 30, then 60 days. A word you miss comes back after 4 hours.
- **Speaking practice.** Answer IELTS Part 1–3 questions out loud. You get a live transcript, words per minute, an estimated band for fluency, vocabulary and grammar, and suggested word upgrades.
- **Writing practice.** Task 2 essays with a word count and a 40-minute timer. Every word is coloured by level, a bar shows your A/B/C mix, and you get feedback on the four IELTS criteria.
- **Progress window.** Shows your streak, words learned per level, activity over the last 14 days, your band estimates over time, and the words you miss most.
- **Word library.** All 9,984 words, searchable and filterable by level and by status (seen, learned, missed).
- **Study material.** 12 lessons: how the exam works, what each band means, the Task 2 question types and a paragraph plan, Task 1, linking words, Speaking Parts 1–3, fluency, upgrading basic vocabulary, and common mistakes made by Indonesian speakers.
- **Menu bar icon** for a quick quiz, speaking, writing and settings.

## Requirements

- macOS 26 or later with **Apple Intelligence turned on** (System Settings → Apple Intelligence & Siri). Without it, the app still runs, but you get no AI feedback.
- Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) to build.
- No Apple Developer Program membership is needed. The app is signed to run locally.

## Build and run

```bash
xcodegen generate
swift test
xcodebuild -project BandUp.xcodeproj -scheme BandUp -derivedDataPath build/DD build
open build/DD/Build/Products/Debug/BandUp.app
```

`swift test` runs the tests for the core logic. Run `xcodegen generate` again whenever you add or remove files in the app target.

If `xcode-select` points at the Command Line Tools instead of Xcode, set this first:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

The first time you open the app, allow notifications. The first time you use Speaking, allow the microphone and speech recognition.

## Usage tips

- **Close the window (⌘W) instead of quitting (⌘Q).** If you quit, the menu bar icon goes away too.
- To answer a pop-up, hover over it and click **Options → Answer** (or **Answer**), type your sentence, then click **Check**. Type `?` or click **I don't know** to see what the word means.
- To try a pop-up without waiting, open the menu bar icon and click **Send test pop-up**.
- In **Settings** you can change your target level (default B2), the number of pop-ups per day, and the hours they can appear.

## How it's built

```
Sources/
  BandUpCore/        Swift package: the logic, with no UI (tested with swift test)
    WordBank         CEFR word list loaded from Resources/words.json
    LevelTagger      labels each word in a text with its level (NaturalLanguage finds the base form)
    LearnerProgress  spaced-repetition boxes, streak, history; saved as JSON
    Summary          numbers for the Progress window
    Feedback         FeedbackEngine protocol + AppleFeedbackEngine (Foundation Models)
    Lessons, Prompts study material and practice questions
  BandUpApp/         macOS SwiftUI app: windows, menu bar, notifications, microphone
Tests/BandUpCoreTests/
Data/                source CSVs for the word list
tools/build_wordlist.py   rebuilds Resources/words.json from Data/
project.yml          XcodeGen spec for the app
```

Progress is saved to `~/Library/Application Support/BandUp/progress.json`.

### AI feedback

All AI calls go through the `FeedbackEngine` protocol in `Sources/BandUpCore/Feedback.swift`. The built-in engine uses Apple's **Foundation Models** framework:

- **Structured output.** Results are `@Generable` structs, so the model fills in typed fields (`isCorrect`, `corrected`, band scores limited to 0–9, …) instead of returning free text.
- **Overall band.** The app calculates it from the criterion scores using IELTS rounding. The model is not asked for it.
- **One session per request**, with responses capped at 800 tokens.
- **Guardrail fallback.** If the default safety filter blocks an ordinary learner sentence, the request is retried once with `.permissiveContentTransformations` guardrails.

Band scores from the on-device model are rough estimates, not official IELTS scores. Speaking is judged from the transcript only, so pronunciation isn't scored.

To add a cloud model (OpenAI, Claude, …), write another type that conforms to `FeedbackEngine`. The result structs are `Codable`, so the engine can decode JSON into them, and the UI doesn't need to change. Cloud APIs charge per request.

## Word list data and attribution

- **CEFR-J Wordlist Version 1.5** (A1–B2). Compiled by Yukio Tono, Tokyo University of Foreign Studies. Free for research and commercial use with citation. http://www.cefr-j.org/
- **Octanove Vocabulary Profile C1/C2 version 1.0** by Octanove Labs, licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

Both lists were obtained from [openlanguageprofiles/olp-en-cefrj](https://github.com/openlanguageprofiles/olp-en-cefrj). `tools/build_wordlist.py` merges them and splits variant spellings ("analyze/analyse") into separate entries.

The lessons and practice questions were written for this app. The band descriptions are simplified summaries, not the official IELTS band descriptors.

## Roadmap

- iPhone version with a home-screen widget (needs an Apple Developer Program membership)
- Open at login, and hiding the Dock icon when no window is open
- Optional cloud feedback engine
