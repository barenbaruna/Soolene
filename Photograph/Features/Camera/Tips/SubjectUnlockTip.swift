//
//  SubjectUnlockTip.swift
//  Photograph
//
//  One-time TipKit tip after the user's first subject lock.
//

import TipKit

struct SubjectUnlockTip: Tip {
    @Parameter
    static var shouldShow: Bool = false

    var title: Text {
        Text("Change object")
    }

    var message: Text? {
        Text("Tap Clear object to pick a different focus. You can also double-tap the preview.")
    }

    var rules: [Rule] {
        #Rule(Self.$shouldShow) { $0 == true }
    }
}

enum SubjectUnlockTipController {
    @MainActor
    static func updateShouldShow(
        hasCompletedWalkthrough: Bool,
        hasLockedSubjectOnce: Bool,
        showsPicker: Bool
    ) {
        SubjectUnlockTip.shouldShow = hasCompletedWalkthrough
            && hasLockedSubjectOnce
            && showsPicker
    }
}
