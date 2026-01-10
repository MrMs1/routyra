# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
# Open project in Xcode
open Routyra/Routyra.xcodeproj

# Build from command line
xcodebuild -project Routyra/Routyra.xcodeproj -scheme Routyra -configuration Debug build

# Run tests
xcodebuild -project Routyra/Routyra.xcodeproj -scheme Routyra test -destination 'platform=iOS Simulator,name=iPhone 16'
```

Note: No SwiftLint or other linting tools are configured.

## Architecture Overview

Routyra is a minimalist iOS workout logging app built with SwiftUI and SwiftData. The app prioritizes fast, calm workout logging with minimal cognitive load.

### Layer Structure

```
RoutyraApp.swift          # Entry point, SwiftData ModelContainer setup
├── Models/               # SwiftData entities (21 files)
├── Services/             # Business logic as enum namespaces with static methods
├── Views/                # SwiftUI views organized by feature
├── Theme/                # AppColors, Strings (localization constants)
├── Extensions/           # L10n (localization), Localizer, utilities
└── Resources/            # en.lproj, ja.lproj localization files
```

### Data Model Hierarchy

**Core**: `LocalProfile` → `Exercise`, `BodyPart` (with translations)

**Workout Recording**:
- `WorkoutDay` (one per date per profile) → `WorkoutExerciseEntry` → `WorkoutSet`
- Sets use soft-delete (`isSoftDeleted` flag) for undo support
- Lazy set creation: sets created only when logged, not as placeholders

**Workout Planning**:
- `WorkoutPlan` → `PlanDay` → `PlanExercise` → `PlannedSet`
- `PlanCycle` → `PlanCycleItem` (for rotating through multiple plans)
- Progress tracking: `PlanProgress`, `PlanCycleProgress`

**Key Enums** (in `Enums.swift`):
- `ExecutionMode`: `.single` (one active plan) or `.cycle` (rotation)
- `WorkoutMode`: `.free` (ad-hoc) or `.routine` (from plan)
- `EntrySource`: `.routine` or `.free`

### Services Pattern

Services are implemented as enums with static methods (namespace pattern):

- **WorkoutService**: Workout day/set operations, enforces one workout per date
- **PlanService**: Plan CRUD, `expandPlanToWorkout()` converts plan to entries
- **CycleService**: Cycle progression, day advancement
- **DateUtilities**: Date normalization with configurable transition hour (default 3 AM)

### View Structure

```
MainTabView (4 tabs)
├── WorkoutView          # Primary logging screen (~1250 lines, complex)
├── HistoryView          # Past workouts
├── RoutinesView         # Plan/cycle management
└── SettingsView         # Config & exercise management
```

### Localization

- `L10n.tr("key")` helper for translations
- `Strings.swift` contains all localization key constants
- Supported: English (en), Japanese (ja)
- Resources in `Resources/{locale}.lproj/Localizable.strings`

## Design Philosophy

From `design.md`:
- Fast logging is highest priority
- Calm, non-intrusive UI (no gamification)
- Focus shown by structure (expanded/collapsed), not loud colors
- UI never lies about workout state
- Only one exercise card expanded at a time
- Ads only between collapsed cards, never near expanded

## Color Scheme (Dark Mode Only)

Defined in `Theme/AppColors.swift`:
- Background: `#0F0F10`
- Card: `#1C1C1E` (normal), `#141416` (completed)
- Accent blue: `#0A84FF`
- Text: white (primary), `#8E8E93` (secondary), `#636366` (muted)

## Code Conventions

- Swift standard naming: UpperCamelCase for types, camelCase for variables/methods
- `// MARK:` sections for organization in larger files
- Services use enum namespace pattern with static functions
- Views use `@Query` for SwiftData, `@State` for local UI state
