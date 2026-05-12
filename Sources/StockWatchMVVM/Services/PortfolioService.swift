// PortfolioService.swift
// StockWatchMVVM — Services
//
// Fully local. No API keys, no Firebase, no network required.
// Prices are simulated with realistic random walk for demo purposes.

import Foundation
import Combine

// MARK: - PortfolioServiceProtocol

public protocol PortfolioServiceProtocol {
    var portfolioPublisher: AnyPublisher<[Stock], Never> { get }
    func fetchPortfolio() -> [Stock]
    func addStock(_ stock: Stock) throws
    func updateStock(_ stock: Stock) throws
    func removeStock(id: UUID) throws
    func simulatePriceUpdate()
    func priceHistory(for symbol: String) -> [PricePoint]
}

// MARK: - PortfolioService

public final class PortfolioService: PortfolioServiceProtocol {

    public static let shared = PortfolioService()

    private let storageKey     = "com.stockwatch.portfolio"
    private let historyKey     = "com.stockwatch.pricehistory"
    private let encoder        = JSONEncoder()
    private let decoder        = JSONDecoder()
    private let subject        = CurrentValueSubject<[Stock], Never>([])
    private var priceHistories = [String: [PricePoint]]()

    public var portfolioPublisher: AnyPublisher<[Stock], Never> {
        subject.eraseToAnyPublisher()
    }

    public init() {
        loadHistories()
        let stocks = fetchPortfolio()
        subject.send(stocks)

        // Seed demo data if first launch
        if stocks.isEmpty { seedDemoData() }
    }

    // MARK: - CRUD

    public func fetchPortfolio() -> [Stock] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stocks = try? decoder.decode([Stock].self, from: data) else { return [] }
        return stocks
    }

    public func addStock(_ stock: Stock) throws {
        var stocks = fetchPortfolio()
        guard !stocks.contains(where: { $0.symbol == stock.symbol }) else {
            throw PortfolioError.duplicateSymbol(stock.symbol)
        }
        stocks.append(stock)
        try persist(stocks)
        recordPrice(symbol: stock.symbol, price: stock.currentPrice)
    }

    public func updateStock(_ stock: Stock) throws {
        var stocks = fetchPortfolio()
        guard let i = stocks.firstIndex(where: { $0.id == stock.id }) else {
            throw PortfolioError.notFound
        }
        stocks[i] = stock
        try persist(stocks)
    }

    public func removeStock(id: UUID) throws {
        var stocks = fetchPortfolio()
        let before = stocks.count
        stocks.removeAll { $0.id == id }
        guard stocks.count < before else { throw PortfolioError.notFound }
        try persist(stocks)
    }

    // MARK: - Price Simulation (no external API needed)

    public func simulatePriceUpdate() {
        var stocks = fetchPortfolio()
        for i in stocks.indices {
            let change = Double.random(in: -0.03...0.03)
            let newPrice = max(0.01, stocks[i].currentPrice * (1 + change))
            stocks[i] = Stock(
                id: stocks[i].id,
                symbol: stocks[i].symbol,
                companyName: stocks[i].companyName,
                shares: stocks[i].shares,
                averageBuyPrice: stocks[i].averageBuyPrice,
                currentPrice: newPrice,
                sector: stocks[i].sector,
                notes: stocks[i].notes
            )
            recordPrice(symbol: stocks[i].symbol, price: newPrice)
        }
        try? persist(stocks)
    }

    // MARK: - Price History

    public func priceHistory(for symbol: String) -> [PricePoint] {
        priceHistories[symbol.uppercased()] ?? []
    }

    private func recordPrice(symbol: String, price: Double) {
        var history = priceHistories[symbol.uppercased()] ?? []
        history.append(PricePoint(date: Date(), price: price))
        if history.count > 90 { history = Array(history.suffix(90)) }
        priceHistories[symbol.uppercased()] = history
        saveHistories()
    }

    // MARK: - Persistence

    private func persist(_ stocks: [Stock]) throws {
        let data = try encoder.encode(stocks)
        UserDefaults.standard.set(data, forKey: storageKey)
        subject.send(stocks)
    }

    private func loadHistories() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let histories = try? decoder.decode([String: [PricePoint]].self, from: data)
        else { return }
        priceHistories = histories
    }

    private func saveHistories() {
        guard let data = try? encoder.encode(priceHistories) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    // MARK: - Demo Seed Data

    private func seedDemoData() {
        let demo: [Stock] = [
            Stock(symbol: "AAPL", companyName: "Apple Inc.", shares: 10, averageBuyPrice: 150.0, currentPrice: 178.5, sector: .technology),
            Stock(symbol: "MSFT", companyName: "Microsoft Corp.", shares: 5, averageBuyPrice: 280.0, currentPrice: 415.0, sector: .technology),
            Stock(symbol: "TSLA", companyName: "Tesla Inc.", shares: 8, averageBuyPrice: 220.0, currentPrice: 195.0, sector: .consumer),
            Stock(symbol: "GOOGL", companyName: "Alphabet Inc.", shares: 3, averageBuyPrice: 130.0, currentPrice: 165.0, sector: .technology),
            Stock(symbol: "JPM", companyName: "JPMorgan Chase", shares: 12, averageBuyPrice: 148.0, currentPrice: 192.0, sector: .finance),
            Stock(symbol: "RELIANCE", companyName: "Reliance Industries", shares: 20, averageBuyPrice: 2400.0, currentPrice: 2890.0, sector: .energy),
            Stock(symbol: "TCS", companyName: "Tata Consultancy", shares: 15, averageBuyPrice: 3200.0, currentPrice: 3750.0, sector: .technology)
        ]

        // Seed historical price data (30 days)
        let calendar = Calendar.current
        for stock in demo {
            var price = stock.averageBuyPrice
            var history = [PricePoint]()
            for day in stride(from: 29, through: 0, by: -1) {
                let date = calendar.date(byAdding: .day, value: -day, to: Date())!
                price = max(1, price * (1 + Double.random(in: -0.025...0.025)))
                history.append(PricePoint(date: date, price: price))
            }
            history.append(PricePoint(date: Date(), price: stock.currentPrice))
            priceHistories[stock.symbol] = history
        }
        saveHistories()

        for stock in demo { try? addStock(stock) }
    }
}

// MARK: - Errors

public enum PortfolioError: Error, LocalizedError {
    case duplicateSymbol(String)
    case notFound
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .duplicateSymbol(let s): return "\(s) is already in your portfolio."
        case .notFound:               return "Stock not found."
        case .encodingFailed:         return "Failed to save portfolio."
        }
    }
}
