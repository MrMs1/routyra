# Routyra project summary

- Purpose: Minimalist workout logging iOS app focused on fast, calm strength training logging (see `design.md`).
- Tech stack: Swift + SwiftUI app, SwiftData for persistence; Xcode project `Routyra/Routyra.xcodeproj`.
- Entry point: `Routyra/Routyra/RoutyraApp.swift` (`@main`, sets up SwiftData `ModelContainer`).
- Structure: `Routyra/Routyra` source root with `Models/`, `Views/`, `Services/`, `Theme/`, `Extensions/`, `Resources/`, `Assets.xcassets`; tests in `RoutyraTests/` and `RoutyraUITests/`.
- UI/UX guidance: detailed in `design.md` (dark mode, calm UI, no gamification, etc.).
