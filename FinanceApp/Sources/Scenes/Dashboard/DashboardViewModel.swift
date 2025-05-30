//
//  DashboardViewModel.swift
//  FinanceApp
//
//  Created by Arthur Rios on 09/05/25.
//

import Foundation
import UserNotifications
import SwiftUICore

final class DashboardViewModel {
    let budgetRepo: BudgetRepository
    let transactionRepo: TransactionRepository
    private let calendar = Calendar.current
    
    private let monthRange: ClosedRange<Int>
    private let notificationCenter = UNUserNotificationCenter.current()
    
    init(budgetRepo: BudgetRepository = BudgetRepository(), transactionRepo: TransactionRepository = TransactionRepository(), monthRange: ClosedRange<Int> = -12...24) { // 3 years
        self.budgetRepo = budgetRepo
        self.transactionRepo = transactionRepo
        self.monthRange = monthRange
    }
    
    func loadMonthlyCards() -> [MonthBudgetCardType] {
        let today = Date()
        
        let budgetsByAnchor: [Int: Int] = budgetRepo.fetchBudgets()
            .reduce(into: [:]) { acc, entry in
                acc[entry.monthDate] = entry.amount
        }
        
        let allTxs = transactionRepo.fetchTransactions()
        
        let expensesByAnchor = allTxs
            .filter { $0.type == .expense }
            .reduce(into: [:]) { acc, tx in
                acc[tx.budgetMonthDate, default: 0] += tx.amount
            }
        
        let incomesByAnchor = allTxs
            .filter { $0.type == .income }
            .reduce(into: [:]) { acc, tx in
                acc[tx.budgetMonthDate, default: 0] += tx.amount
            }
        
        let anchors = monthRange.map { offset in
            let dt = calendar.date(byAdding: .month, value: offset, to: today)!
            return dt.monthAnchor
        }.sorted()
        
        var runningBalance = [Int: Int]()
        var previousAvailable = 0
        
        let cards: [MonthBudgetCardType] = anchors.compactMap { anchor in
            let date = Date(timeIntervalSince1970: TimeInterval(anchor))
            let month = DateFormatter.monthFormatter.string(from: date)
            
            let expense = expensesByAnchor[anchor] ?? 0
            let income = incomesByAnchor[anchor] ?? 0
            let budgetLimit = budgetsByAnchor[anchor]
            
            let net = income - expense
            let available = previousAvailable + net
            
            previousAvailable = available
            runningBalance[anchor] = available
            
            return MonthBudgetCardType(
                date: date,
                month: "month.\(month.lowercased())".localized,
                usedValue: expense,
                budgetLimit: budgetLimit,
                availableValue: available
            )
        }
        
        return cards.sorted { $0.date < $1.date }
    }
    
    func deleteTransaction(id: Int) -> Result<Void, Error> {
        do {
            try transactionRepo.delete(id: id)
            
            let notifID = "transaction_\(id)"
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [notifID])
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    func scheduleAllTransactionNotifications() {
        let allTxs = transactionRepo.fetchTransactions()
        let now = Date()
        
        allTxs
            .filter { $0.date >= now }
            .forEach { scheduleNotification(for: $0) }
    }
    
    private func scheduleNotification(for tx: Transaction) {
        let id = "transaction_\(tx.id)"
        
        var comps = calendar.dateComponents([.year, .month, .day], from: tx.date)
        comps.hour = 8
        comps.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        
        let titleKey = tx.type == .income ? "notification.transaction.title.income" : "notification.transaction.title.expense"
        let bodyKey = tx.type == .income ? "notification.transaction.body.income" : "notification.transaction.body.expense"
        
        
        let amountString = tx.amount.currencyString
        let title = titleKey.localized
        let body = bodyKey.localized(amountString, tx.title)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    private func printPendingNotifications() {
        notificationCenter.getPendingNotificationRequests { requests in
            for request in requests {
                let title = request.content.title
                let body  = request.content.body
                print("🔔 Pending — title: \(title), body: \(body)")
            }
        }
    }
}
