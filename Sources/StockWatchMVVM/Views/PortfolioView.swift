// PortfolioView.swift
// StockWatchMVVM — Views
//
// Pure SwiftUI. Views hold zero business logic.
// All state comes from ViewModel via @StateObject / @ObservedObject.

import SwiftUI

// MARK: - Root App Entry

@main
struct StockWatchApp: App {
    var body: some Scene {
        WindowGroup {
            PortfolioView()
        }
    }
}

// MARK: - PortfolioView (Main Screen)

struct PortfolioView: View {
    @StateObject private var vm = PortfolioViewModel()
    @State private var showAddSheet = false
    @State private var showSortSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        summaryCard
                        searchAndFilter
                        stockList
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }

                if vm.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarItems }
            .sheet(isPresented: $showAddSheet) { AddStockView(vm: vm) }
            .actionSheet(isPresented: $showSortSheet) { sortActionSheet }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.clearError() } }
            )) {
                Button("OK") { vm.clearError() }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    // MARK: Summary Card

    private var summaryCard: some View {
        Group {
            if let summary = vm.summary {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Value")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(vm.formatted(price: summary.currentValue))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("P&L")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: summary.isProfit ? "arrow.up.right" : "arrow.down.right")
                                Text(vm.formatted(percent: summary.totalProfitLossPercent))
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(summary.isProfit ? .green : .red)
                        }
                    }

                    Divider()

                    HStack {
                        statItem(label: "Invested", value: vm.formatted(price: summary.totalInvested))
                        Spacer()
                        statItem(label: "P&L Amt", value: vm.formatted(price: summary.totalProfitLoss),
                                 color: summary.isProfit ? .green : .red)
                        Spacer()
                        statItem(label: "Holdings", value: "\(summary.stockCount)")
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func statItem(label: String, value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline).fontWeight(.semibold).foregroundStyle(color)
        }
    }

    // MARK: Search & Filter

    private var searchAndFilter: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search symbol or company", text: $vm.searchQuery)
                    .autocorrectionDisabled()
                if !vm.searchQuery.isEmpty {
                    Button { vm.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("All", isSelected: vm.selectedSector == nil) {
                        vm.clearSectorFilter()
                    }
                    ForEach(StockSector.allCases, id: \.rawValue) { sector in
                        filterChip("\(sector.emoji) \(sector.rawValue)", isSelected: vm.selectedSector == sector) {
                            vm.selectedSector = vm.selectedSector == sector ? nil : sector
                        }
                    }
                }
            }
        }
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    // MARK: Stock List

    private var stockList: some View {
        LazyVStack(spacing: 8) {
            if vm.filteredStocks.isEmpty {
                ContentUnavailableView(
                    vm.stocks.isEmpty ? "No Holdings" : "No Results",
                    systemImage: vm.stocks.isEmpty ? "chart.bar.xaxis" : "magnifyingglass",
                    description: Text(vm.stocks.isEmpty ? "Tap + to add your first stock" : "Try adjusting your search or filters")
                )
                .padding(.top, 40)
            } else {
                ForEach(vm.filteredStocks) { stock in
                    NavigationLink(destination: StockDetailView(stock: stock)) {
                        StockRowView(stock: stock, vm: vm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAddSheet = true } label: {
                Image(systemName: "plus")
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            Button { vm.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(vm.isLoading ? 360 : 0))
                    .animation(vm.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                               value: vm.isLoading)
            }
        }
    }

    private var sortActionSheet: ActionSheet {
        ActionSheet(title: Text("Sort By"), buttons:
            StockSortOption.allCases.map { opt in
                .default(Text(opt.rawValue + (vm.sortOption == opt ? " ✓" : ""))) {
                    if vm.sortOption == opt { vm.sortAscending.toggle() }
                    else { vm.sortOption = opt }
                }
            } + [.cancel()]
        )
    }
}

// MARK: - StockRowView

struct StockRowView: View {
    let stock: Stock
    let vm: PortfolioViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Symbol Badge
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(stock.isProfit ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 48, height: 48)
                Text(String(stock.symbol.prefix(3)))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(stock.isProfit ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(stock.symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(stock.companyName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(stock.sector.emoji) \(stock.sector.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(vm.formatted(price: stock.currentValue))
                    .font(.system(size: 15, weight: .semibold))
                Text(vm.formatted(percent: stock.profitLossPercent))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(stock.isProfit ? .green : .red)
                Text("\(String(format: "%.0f", stock.shares)) shares")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - StockDetailView

struct StockDetailView: View {
    let stock: Stock
    @StateObject private var vm: StockDetailViewModel
    @State private var isEditing = false
    @Environment(\.dismiss) private var dismiss

    init(stock: Stock) {
        self.stock = stock
        _vm = StateObject(wrappedValue: StockDetailViewModel(stock: stock))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                metricsGrid
                if !vm.priceHistory.isEmpty { priceChartCard }
                if isEditing { editCard }
            }
            .padding()
        }
        .navigationTitle(vm.stock.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing { vm.saveChanges() }
                    isEditing.toggle()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var headerCard: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(vm.stock.companyName)
                        .font(.headline)
                    Text("\(vm.stock.sector.emoji) \(vm.stock.sector.rawValue)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(String(format: "₹%.2f / $%.2f", vm.stock.currentPrice, vm.stock.currentPrice))
                        .font(.title3).bold()
                    Text("Current Price")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var metricsGrid: some View {
        let metrics: [(String, String, Color?)] = [
            ("Shares",     String(format: "%.2f", vm.stock.shares),          nil),
            ("Avg. Buy",   String(format: "%.2f", vm.stock.averageBuyPrice), nil),
            ("Invested",   String(format: "%.2f", vm.stock.totalInvested),   nil),
            ("Curr. Value",String(format: "%.2f", vm.stock.currentValue),    nil),
            ("P&L",        String(format: "%+.2f", vm.stock.profitLoss),     vm.stock.isProfit ? .green : .red),
            ("P&L %",      String(format: "%+.2f%%", vm.stock.profitLossPercent), vm.stock.isProfit ? .green : .red)
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(metrics, id: \.0) { label, value, color in
                VStack(spacing: 4) {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                    Text(value).font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(color ?? .primary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var priceChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Price History (30 Days)")
                .font(.headline)

            // Simple sparkline using Canvas
            Canvas { context, size in
                let prices = vm.priceHistory.map(\.price)
                guard prices.count > 1 else { return }
                let minP = prices.min()! * 0.98
                let maxP = prices.max()! * 1.02
                let w = size.width / CGFloat(prices.count - 1)

                var path = Path()
                for (i, price) in prices.enumerated() {
                    let x = CGFloat(i) * w
                    let y = size.height - CGFloat((price - minP) / (maxP - minP)) * size.height
                    i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                }
                let isProfit = (prices.last ?? 0) >= (prices.first ?? 0)
                context.stroke(path, with: .color(isProfit ? .green : .red), lineWidth: 2)
            }
            .frame(height: 120)
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var editCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Position").font(.headline)
            labeledField("Shares", binding: $vm.editShares, keyboard: .decimalPad)
            labeledField("Avg. Buy Price", binding: $vm.editPrice, keyboard: .decimalPad)
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes").font(.caption).foregroundStyle(.secondary)
                TextField("Optional notes", text: $vm.editNotes)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func labeledField(_ label: String, binding: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: binding)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboard)
        }
    }
}

// MARK: - AddStockView

struct AddStockView: View {
    @ObservedObject var vm: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var symbol      = ""
    @State private var companyName = ""
    @State private var shares      = ""
    @State private var buyPrice    = ""
    @State private var currentPx   = ""
    @State private var sector      = StockSector.technology
    @State private var notes       = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Stock Info") {
                    TextField("Symbol (e.g. AAPL)", text: $symbol).autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    TextField("Company Name", text: $companyName)
                    Picker("Sector", selection: $sector) {
                        ForEach(StockSector.allCases, id: \.rawValue) {
                            Text("\($0.emoji) \($0.rawValue)").tag($0)
                        }
                    }
                }

                Section("Position") {
                    TextField("Shares", text: $shares).keyboardType(.decimalPad)
                    TextField("Average Buy Price", text: $buyPrice).keyboardType(.decimalPad)
                    TextField("Current Price", text: $currentPx).keyboardType(.decimalPad)
                }

                Section("Notes (optional)") {
                    TextField("Any notes...", text: $notes)
                }
            }
            .navigationTitle("Add Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !symbol.isEmpty && !companyName.isEmpty &&
        Double(shares) != nil && Double(buyPrice) != nil && Double(currentPx) != nil
    }

    private func save() {
        guard let s = Double(shares), let bp = Double(buyPrice), let cp = Double(currentPx) else { return }
        let stock = Stock(symbol: symbol, companyName: companyName, shares: s,
                          averageBuyPrice: bp, currentPrice: cp, sector: sector, notes: notes)
        vm.addStock(stock)
        dismiss()
    }
}
