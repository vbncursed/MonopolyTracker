//
//  AddPlayerModalView.swift
//  MonopolyTracker
//
//  Created by vbncursed on 28/1/25.
//

import SwiftUI

struct AddPlayerModalView: View {
    @Binding var isPresented: Bool
    @ObservedObject var gameViewModel: GameViewModel
    @State private var newPlayerName: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Добавить игрока")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)

                TextField("Имя игрока", text: $newPlayerName)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .foregroundColor(.primary)
                    .padding(.horizontal)

                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .navigationTitle("Добавление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        withAnimation(.spring()) { isPresented = false }
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        if !newPlayerName.isEmpty {
                            withAnimation(.spring()) {
                                gameViewModel.addPlayer(name: newPlayerName)
                                newPlayerName = ""
                                isPresented = false
                            }
                        }
                    }
                    .foregroundColor(.blue)
                    .bold()
                }
            }
        }
    }
}
