//
//  GuidanceTipView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 03/06/26.
//

import SwiftUI

/// A molecule that displays a composition guidance tip using atomic components.
struct GuidanceTipView: View {
    let tip: String

    var body: some View {
        Text(tip)
            .textStyle(Typography.caption, color: .primary)
            .glassPill()
            .animation(.spring(response: 0.5), value: tip)
            .id(tip) // Force transition when tip changes
    }
}
