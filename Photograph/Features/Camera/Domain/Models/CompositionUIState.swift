//
//  CompositionUIState.swift
//  Soolene
//

import Foundation

/// Presentation-facing composition and guidance state owned by the domain layer.
struct CompositionUIState: Equatable {
    var phase: GuidancePhase = .scanning
    var mlSuggestion: CompositionType?
    var userSelectedComposition: CompositionType?
    var isSubjectPinned = false
    var recommendedLabel: String?
}
