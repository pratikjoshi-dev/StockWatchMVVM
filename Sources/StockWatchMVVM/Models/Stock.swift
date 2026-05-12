// Stock.swift
// StockWatchMVVM — Models

import Foundation

// MARK: - Stock

public struct Stock: Identifiable, Codable, Equatable {
    public let id: UUID
    public let symbol: String
    public let companyName: String
    public var shares: Double
    public var averageBuyPrice: Double
    public var currentPrice: Double
    public var sector: StockSector
    public var addedAt: Date
    public var notes: String

    public init(
        id: UUID = UUID(),
        symbol: String,
        companyName: String,
        shares: Double,
        averageBuyPrice: Double,
        currentPrice: Double,
        sector: StockSector = .technology,
        notes: String = ""
    ) {
        self.id              = id
        self.symbol          = symbol.uppercased()
        self.companyName     = companyName
        self.shares          = shares
        self.averageBuyPrice = averageBuyPrice
        self.currentPrice    = currentPrice
        self.sector          = sector
        self.addedAt         = Date()
        self.notes           = notes
    }

    // MARK: - Computed

    public var totalInvested: Double  { shares * averageBuyPrice }
    public var currentValue: Double   { shares * currentPrice }
    public var profitLoss: Double     { currentValue - totalInvested }
    public var profitLossPercent: Double {
        guard totalInvested > 0 else { return 0 }
        return (profitLoss / totalInvested) * 100
    }
    public var isProfit: Bool { profitLoss >= 0 }
}

// MARK: - StockSector

public enum StockSector: String, Codable, CaseIterable {
    case technology    = "Technology"
    case finance       = "Finance"
    case healthcare    = "Healthcare"
    case energy        = "Energy"
    case consumer      = "Consumer"
    case industrial    = "Industrial"
    case realEstate    = "Real Estate"
    case utilities     = "Utilities"
    case materials     = "Materials"
    case other         = "Other"

    var emoji: String {
        switch self {
        case .technology:  return "💻"
        case .finance:     return "🏦"
        case .healthcare:  return "🏥"
        case .energy:      return "⚡"
        case .consumer:    return "🛒"
        case .industrial:  return "🏭"
        case .realEstate:  return "🏠"
        case .utilities:   return "🔧"
        case .materials:   return "⛏"
        case .other:       return "📦"
        }
    }
}

// MARK: - Portfolio Summary

public struct PortfolioSummary {
    public let totalInvested: Double
    public let currentValue: Double
    public let totalProfitLoss: Double
    public let totalProfitLossPercent: Double
    public let stockCount: Int
    public let sectorBreakdown: [StockSector: Double]

    public var isProfit: Bool { totalProfitLoss >= 0 }

    public static func compute(from stocks: [Stock]) -> PortfolioSummary {
        let invested     = stocks.reduce(0) { $0 + $1.totalInvested }
        let value        = stocks.reduce(0) { $0 + $1.currentValue }
        let pl           = value - invested
        let plPct        = invested > 0 ? (pl / invested) * 100 : 0

        var sectorMap = [StockSector: Double]()
        for stock in stocks {
            sectorMap[stock.sector, default: 0] += stock.currentValue
        }

        return PortfolioSummary(
            totalInvested: invested,
            currentValue: value,
            totalProfitLoss: pl,
            totalProfitLossPercent: plPct,
            stockCount: stocks.count,
            sectorBreakdown: sectorMap
        )
    }
}

// MARK: - Price History (local simulation)

public struct PricePoint: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let price: Double

    public init(date: Date, price: Double) {
        self.id    = UUID()
        self.date  = date
        self.price = price
    }
}

// MARK: - Sort Options

public enum StockSortOption: String, CaseIterable {
    case symbol      = "Symbol"
    case gainLoss    = "Gain/Loss %"
    case value       = "Current Value"
    case invested    = "Total Invested"
    case addedDate   = "Date Added"
}
