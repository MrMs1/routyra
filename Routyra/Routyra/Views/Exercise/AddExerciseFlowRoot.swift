//
//  AddExerciseFlowRoot.swift
//  Routyra
//
//  Entry point for the "Add Custom Exercise" flow.
//  Loads the local profile and hosts a NavigationStack for the two-step flow:
//  1) Choose a BodyPart
//  2) Enter an exercise name
//

import SwiftUI
import SwiftData

struct AddExerciseFlowRoot: View {
    /// Callback when an exercise is successfully created.
    let onCreated: (Exercise) -> Void

    /// Callback when the flow is cancelled.
    var onCancel: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var profile: LocalProfile?
    @State private var selectedBodyPart: BodyPart?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let profile = profile {
                    BodyPartPickerView(profile: profile) { bodyPart in
                        selectedBodyPart = bodyPart
                        navigationPath.append(NavigationDestination.exerciseName)
                    }
                } else {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .exerciseName:
                    if let profile = profile, let bodyPart = selectedBodyPart {
                        NewExerciseNameView(
                            profile: profile,
                            bodyPart: bodyPart,
                            onCreated: { exercise in
                                onCreated(exercise)
                                dismiss()
                            }
                        )
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onCancel?()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadProfile()
        }
    }

    private func loadProfile() {
        profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
    }

    // MARK: - Navigation

    private enum NavigationDestination: Hashable {
        case exerciseName
    }
}

// MARK: - Sheet Modifier

extension View {
    /// Presents the "Add Exercise" flow as a sheet.
    /// - Parameters:
    ///   - isPresented: Binding to control sheet presentation.
    ///   - onCreated: Called when an exercise is successfully created.
    func addExerciseSheet(
        isPresented: Binding<Bool>,
        onCreated: @escaping (Exercise) -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            AddExerciseFlowRoot(
                onCreated: { exercise in
                    onCreated(exercise)
                    isPresented.wrappedValue = false
                },
                onCancel: {
                    isPresented.wrappedValue = false
                }
            )
        }
    }
}

#Preview {
    AddExerciseFlowRoot(
        onCreated: { exercise in
            print("Created exercise: \(exercise.name)")
        }
    )
    .modelContainer(for: [
        LocalProfile.self,
        BodyPart.self,
        Exercise.self
    ], inMemory: true)
    .preferredColorScheme(.dark)
}
