//
//  BalancedContentWidth.swift
//  9AM Challenge 3 MVP
//
//  Keeps screens at a comfortable reading width on iPad while leaving the
//  full screen available on iPhone.
//

import SwiftUI

private struct BalancedContentWidth: ViewModifier {
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

extension View {
    /// Centers this view with balanced side margins on large screens.
    func balancedContentWidth(maxWidth: CGFloat = 900) -> some View {
        modifier(BalancedContentWidth(maxWidth: maxWidth))
    }
}
