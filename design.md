# Routyra – Design & UX Specification (for Claude Code)

## Overview

Routyra is a minimalist workout logging app focused on **fast, calm, and structured strength training 기록**.
The primary value is _recording sets with minimal cognitive load_, not social features or analytics-first design.

This document describes the **finalized UX, UI concepts, and navigation rules** to be used as input for coding with Claude Code.

---

## Core Design Principles

- Fast logging is the highest priority
- Calm, non-intrusive UI (no gamification pressure)
- Structure over decoration
- UI should never lie about state
- Focus is shown by structure (expanded/collapsed), not loud color
- Ads must never interfere with logging actions

---

## App Navigation (Footer Tabs)

Bottom tab bar contains **4 tabs**, each with a clearly separated context.

```
[ Workout ] [ History ] [ Routines ] [ Settings ]
```

### 1. Workout (Home / Logging)

- Default tab on app launch
- Main workout logging screen
- Expanded / Collapsed exercise cards
- State is preserved when switching tabs
- Ads are extremely limited here

### 2. History

- Weekly → Monthly workout history
- Past workout viewing and editing
- Ads allowed (non-intrusive)

### 3. Routines

- Create / edit workout routines
- Define exercise order and set counts
- Used outside active training

### 4. Settings

- App configuration
- Exercise management
- Pro / Ads removal
- Theme & language

---

## Data Storage

- **SwiftData** is used for persistence
- CloudKit is OFF initially (future extension)
- Core entities (conceptual):

  - Workout (date-based)
  - Exercise
  - Set (weight, reps, order)
  - Routine

---

## Workout Screen – Layout

### Top Header

- Center: "Workout"
- Left: Date (tappable, focuses week strip)
- Right: Flame icon + streak count

### Weekly Activity Strip

- Horizontal strip of 7 vertical pill bars
- Indicates workout days in the current week
- Muted blue = workout done
- Dark gray = no workout
- Today slightly emphasized
- Only focused day shows weekday label (e.g. Mon)
- Informational only (no heavy interaction)

---

## Exercise Cards (Core UX)

Workout screen shows a vertical list of **exercise cards**.

### Card States

Only ONE card can be expanded at a time.

| State                  | Meaning                    | Visual Priority |
| ---------------------- | -------------------------- | --------------- |
| Expanded               | Focused, unfinished        | Highest         |
| Collapsed (unfinished) | Unfinished but not focused | Medium          |
| Completed              | Finished exercise          | Low             |

### Key Rules

- **Unfinished exercises all have the SAME emphasis** (no ranking by color)
- Focus is expressed by **expansion/structure**, not strong color
- Editing interactions are available **only inside the Expanded card**

---

## Sets UI (Dot → Number transform)

Inside the Expanded card, set progress is shown as a **vertical column**.

### Default state (calm)

- Most sets are represented as dots

  - **Filled dot** = completed set
  - **Empty dot** = planned but not completed

### Active set indicator

- Exactly **one** set is the active/focused set.
- The active set dot transforms into a **circled number** (set index or reps indicator; use a single clear meaning consistently).
- This circled number **replaces** the dot at the same vertical position (structure must not shift).

### Entering edit state

- **Tap the circled number** to enter edit state for that set.
- For editing a past set:

  1. tap a completed dot to select it (it becomes the circled number)
  2. tap the circled number again to open edit UI

- Shortcut: **long-press a completed dot** to open edit state directly.

### Edit UI (inline, appears to the right)

When a set is in edit state, show an inline row aligned with the selected dot:

- `[ 60 ] kg × [ 8 ] reps`
- Only the numeric fields are editable (labels are static)
- Subtle gray outlines; do **not** use loud accent colors
- A small, low-contrast **trash icon** appears at the far right to delete that set

### Edit constraints

- Only **completed** sets can be edited/deleted.
- Only **one** set can be in edit state at a time.
- Exiting edit state:

  - Done / tap outside / switch set selection / switch exercise / log a new set
  - Returns to the calm dot-only view

### Delete behavior

- Delete is available **only** from the set edit state (trash icon).
- No modal confirmation.
- Always provide **Snack bar Undo** (e.g. "Set removed" [Undo]).

### Planned sets adjustment

- Long-press on a **future empty dot** reduces planned set count by 1.
- Provide Undo via snack bar.
- Do not treat this as deleting a completed set.

---

## Manual input (kg / reps)

Within the Expanded card:

- `kg` and `reps` numbers are tappable.
- Tapping each number enters inline numeric input for that field.
- Keyboard:

  - kg: decimal pad (supports 62.5)
  - reps: number pad

Typography note:

- Current values should be readable; consider making reps slightly larger than kg.

---

## Ads Placement Rules

Ads are allowed but must never interfere with logging.

Rules:

- Ads appear ONLY between collapsed cards
- Never inside an expanded card
- Never directly before or after the expanded card
- Slightly smaller than exercise cards
- Always labeled `Sponsored`
- Calm, low-contrast appearance

---

## Bottom Status Bar

Fixed bottom bar showing workout summary:

- Sets: `8`
- Exercises: `3`
- Total Volume: `4,320 kg`

Design:

- Dark background
- Thin divider
- White numbers, muted labels

---

## Snack Bar (Temporary UI)

Appears after logging a set.

Content:

- `Set logged: 60 kg × 8`
- Inline `+ / –` controls
- `Undo` action

Design:

- Semi-transparent
- Non-intrusive
- Auto-dismiss

---

## Visual Style

- Dark mode only (initially)
- Background: #0F0F10
- Accent blue reserved for primary actions only
- SF Pro–style typography
- Generous spacing
- No charts, no social features, no noise

---

## Non-Goals (Explicitly Out of Scope)

- Social sharing
- Rankings / leaderboards
- Nutrition tracking
- Body weight tracking
- Aggressive gamification

---

## Product Philosophy (for Claude Code)

> "The UI should quietly tell the truth about the workout state.
> The user should never wonder what to do next."

This app is designed to feel **inevitable, calm, and reliable** during training.
