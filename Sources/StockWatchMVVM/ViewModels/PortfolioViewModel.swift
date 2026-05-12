// PortfolioViewModel.swift
// StockWatchMVVM — ViewModels
//
// MVVM: ViewModel is the brain. It owns state and exposes
// @Published properties. Views observe and react — no business
// logic in the View layer.

import Foundation
import Combine
import SwiftUI

// MARK: - PortfolioViewModel

@MainActor
public final class PortfolioViewModel: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var stocks: [Stock] = []
    @Published public private(set) var filteredStocks: [Stock] = []
    @Published public private(set) var summary: PortfolioSummary?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?

    @Published public var searchQuery: String = ""
    @Published public var selectedSector: StockSector? = nil
    @Published public var sortOption: StockSortOption = .symbol
    @Published public var sortAscending: Bool = true

    // MARK: - Dependencies

    private let service: PortfolioServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init(service: PortfolioServiceProtocol = PortfolioService.shared) {
        self.service = service
        bindService()
        bindFilters()
    }

    // MARK: - Bindings

    private func bindService() {
        service.portfolioPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stocks in
                self?.stocks = stocks
                self?.summary = PortfolioSummary.compute(from: stocks)
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }

    private func bindFilters() {
        Publishers.CombineLatest4(
            $stocks, $searchQuery, $selectedSector, $sortOption
        )
        .combineLatest($sortAscending)
        .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
        .sink { [weak self] combined, ascending in
            let (stocks, query, sector, sort) = combined
            self?.apply(stocks: stocks, query: query, sector: sector, sort: sort, ascending: ascending)
        }
        .store(in: &cancellables)
    }

    private func apply(stocks: [Stock], query: String, sector: StockSector?, sort: StockSortOption, ascending: Bool) {
        var result = stocks

        if !query.isEmpty {
            result = result.filter {
                $0.symbol.localizedCaseInsensitiveContains(query) ||
                $0.companyName.localizedCaseInsensitiveContains(query)
            }
        }

        if let sector { result = result.filter { $0.sector == sector } }

        result.sort { a, b in
            let compared: Bool
            switch sort {
            case .symbol:    compared = a.symbol < b.symbol
            case .gainLoss:  compared = a.profitLossPercent < b.profitLossPercent
            case .value:     compared = a.currentValue < b.currentValue
            case .invested:  compared = a.totalInvested < b.totalInvested
            case .addedDate: compared = a.addedAt < b.addedAt
            }
            return ascending ? compared : !compared
        }

        filteredStocks = result
    }

    private func applyFilters() {
        apply(stocks: stocks, query: searchQuery, sector: selectedSector, sort: sortOption, ascending: sortAscending)
    }

    // MARK: - Actions

    public func refresh() {
        isLoading = true
        errorMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.service.simulatePriceUpdate()
            self?.isLoading = false
        }
    }

    public func addStock(_ stock: Stock) {
        do {
            try service.addStock(stock)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func removeStocks(at offsets: IndexSet) {
        let ids = offsets.map { filteredStocks[$0].id }
        ids.forEach { id in try? service.removeStock(id: id) }
    }

    public func priceHistory(for stock: Stock) -> [PricePoint] {
        service.priceHistory(for: stock.symbol)
    }

    public func clearError() { errorMessage = nil }

    public func clearSectorFilter() { selectedSector = nil }

    // MARK: - Formatted Helpers

    public func formatted(price: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: price)) ?? "$\(price)"
    }

    public func formatted(percent: Double) -> String {
        String(format: "%+.2f%%", percent)
    }
}

// MARK: - StockDetailViewModel

@MainActor
public final class StockDetailViewModel: ObservableObject {

    @Published public private(set) var stock: Stock
    @Published public private(set) var priceHistory: [PricePoint] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public var editShares: String = ""
    @Published public var editPrice: String = ""
    @Published public var editNotes: String = ""

    private let service: PortfolioServiceProtocol

    public init(stock: Stock, service: PortfolioServiceProtocol = PortfolioService.shared) {
        self.stock   = stock
        self.service = service
        loadHistory()
        populateEditing()
    }

    private func loadHistory() {
        priceHistory = service.priceHistory(for: stock.symbol)
    }

    private func populateEditing() {
        editShares = String(format: "%.2f", stock.shares)
        editPrice  = String(format: "%.2f", stock.averageBuyPrice)
        editNotes  = stock.notes
    }

    public func saveChanges() {
        guard let shares = Double(editShares), let price = Double(editPrice), shares > 0, price > 0 else { return }
        let updated = Stock(
            id: stock.id, symbol: stock.symbol, companyName: stock.companyName,
            shares: shares, averageBuyPrice: price, currentPrice: stock.currentPrice,
            sector: stock.sector, notes: editNotes
        )
        try? service.updateStock(updated)
        stock = updated
    }

    public var chartMin: Double { (priceHistory.map(\.price).min() ?? 0) * 0.98 }
    public var chartMax: Double { (priceHistory.map(\.price).max() ?? 1) * 1.02 }
}
