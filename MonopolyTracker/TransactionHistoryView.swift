//
//  TransactionHistoryView.swift
//  MonopolyTracker
//
//  Created by vbncursed on 28/1/25.
//

import SwiftUI

enum TransactionFilter: String, CaseIterable {
    case all = "Все"
    case income = "Доходы"
    case expenses = "Расходы"
}

struct TransactionHistoryView: View {
    @ObservedObject var gameViewModel: GameViewModel
    @State private var selectedFilter: TransactionFilter = .all

    var filteredTransactions: [Transaction] {
        switch selectedFilter {
        case .all:
            return gameViewModel.transactions
        case .income:
            return gameViewModel.transactions.filter { $0.amount > 0 }
        case .expenses:
            return gameViewModel.transactions.filter { $0.amount < 0 }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                Picker("Фильтр", selection: $selectedFilter) {
                    ForEach(TransactionFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedFilter) { _ in
                    withAnimation(.easeInOut(duration: 0.3)) { } // 🔹 Анимация смены фильтра
                }

                List {
                    ForEach(filteredTransactions) { transaction in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(transaction.playerName)
                                    .font(.headline)
                                Text(transaction.formattedDate)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Text(transaction.formattedAmount)
                                .font(.headline)
                                .foregroundColor(transaction.amount > 0 ? .green : .red)
                        }
                        .padding(.vertical, 5)
                        .transition(.slide) // 🔹 Плавная анимация появления
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: filteredTransactions) // 🔹 Анимируем список
            }
            .navigationTitle("История транзакций")
        }
    }
}

#Preview {
    TransactionHistoryView(gameViewModel: GameViewModel())
}
