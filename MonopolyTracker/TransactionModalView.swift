//
//  TransactionModalView.swift
//  MonopolyTracker
//
//  Created by vbncursed on 28/1/25.
//

import SwiftUI

struct TransactionModalView: View {
    @Binding var isPresented: Bool
    @Binding var amount: String
    var player: Player
    var onConfirm: (Int) -> Void

    @State private var isAdding: Bool = true

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(player.name)
                    .font(.title)
                    .bold()
                    .foregroundColor(.primary)

                Text("$\(player.balance)")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.green)

                Divider()

                Picker("Тип операции", selection: $isAdding) {
                    Text("Добавить").tag(true)
                    Text("Снять").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                TextField("Введите сумму", text: $amount)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .foregroundColor(.primary)
                    .padding(.horizontal)

                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .navigationTitle("Изменить баланс")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        withAnimation(.spring()) { isPresented = false } // 🔹 Закрытие с анимацией
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Применить") {
                        if let value = Int(amount), value > 0 {
                            let finalAmount = isAdding ? value : -value
                            withAnimation(.spring()) {
                                onConfirm(finalAmount)
                                amount = ""
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
