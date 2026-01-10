# Repository Guidelines

## Project Structure & Module Organization

- `Routyra/` contains the iOS app target.
  - `Routyra/RoutyraApp.swift`: app entry point and SwiftData setup.
  - `Routyra/Models/`: SwiftData entities (plans, workouts, cycles).
  - `Routyra/Services/`: business logic as enum namespaces with static methods.
  - `Routyra/Views/`: SwiftUI views by feature (Workout, History, Routines, Settings).
  - `Routyra/Theme/`: `AppColors` and styling constants.
  - `Routyra/Resources/`: localization files (`en.lproj`, `ja.lproj`).
  - `Routyra/Assets.xcassets/`: images and app assets.
- `RoutyraTests/` and `RoutyraUITests/`: XCTest targets.
- `specs/` and `design.md`: product specs and UX guidelines.

## Build, Test, and Development Commands

Run from repo root:

```bash
# Open in Xcode
open Routyra/Routyra.xcodeproj

# Build (Debug)
xcodebuild -project Routyra/Routyra.xcodeproj -scheme Routyra -configuration Debug build

# Run tests on simulator
xcodebuild -project Routyra/Routyra.xcodeproj -scheme Routyra test -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Coding Style & Naming Conventions

- SwiftUI + SwiftData; 4-space indentation.
- Types: `UpperCamelCase`; methods/vars: `camelCase`.
- Use `// MARK:` sections in large files.
- Services follow enum-namespace pattern (static methods).
- Localization uses `L10n.tr("key")`; keys live in `Routyra/Resources/`.
- No SwiftLint or auto-formatting configured—keep changes tidy and consistent.

## Testing Guidelines

- XCTest is used; unit tests in `RoutyraTests/`, UI tests in `RoutyraUITests/`.
- Name files `*Tests.swift` and keep test cases focused on one behavior.
- Run the `xcodebuild ... test` command above before shipping logic changes.

## Commit & Pull Request Guidelines

- Commit messages follow a short prefix style seen in history (e.g., `feat: ...`).
- Prefer concise, present-tense summaries; use `fix:` or `chore:` when appropriate.
- PRs should include: summary, relevant screenshots for UI changes, and test command run (or note if not run).

## Design & UX Notes

- Follow `design.md`: fast logging, calm UI, no misleading state, and minimal visual noise.
