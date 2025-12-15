//
//  View+Extensions.swift
//  Routyra
//
//  SwiftUI View extensions.
//

import SwiftUI

extension View {
    /// Conditionally applies a transformation to the view.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
