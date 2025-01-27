//
//  SwipeToDeleteView.swift
//  MonopolyTracker
//
//  Created by vbncursed on 28/1/25.
//

import SwiftUI

struct SwipeToDeleteView<Content: View>: View {
    let onDelete: () -> Void
    let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var showDelete: Bool = false

    // ✅ Делаем инициализатор доступным
    init(@ViewBuilder content: @escaping () -> Content, onDelete: @escaping () -> Void) {
        self.content = content
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack {
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        onDelete()
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .padding(.trailing, 10)
            }
            .opacity(showDelete ? 1 : 0)

            content()
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < -20 {
                                withAnimation {
                                    offset = -80
                                    showDelete = true
                                }
                            } else if value.translation.width > 20 {
                                withAnimation {
                                    offset = 0
                                    showDelete = false
                                }
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > 20 {
                                withAnimation {
                                    offset = 0
                                    showDelete = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if showDelete {
                        withAnimation {
                            offset = 0
                            showDelete = false
                        }
                    } else {
                        contentTapAction?()
                    }
                }
        }
    }

    private var contentTapAction: (() -> Void)?
    
    func onTap(_ action: @escaping () -> Void) -> some View {
        var copy = self
        copy.contentTapAction = action
        return copy
    }
}
