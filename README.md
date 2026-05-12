# StockWatchMVVM

A production-quality iOS stock portfolio tracker built with **MVVM + SwiftUI**.  
**No Firebase. No API keys. No sign-in. Runs 100% offline with local data.**

---

## Architecture — MVVM

```
┌─────────────────────────────────────────────────────┐
│                       VIEW                          │
│  PortfolioView, StockDetailView, AddStockView       │
│  • Observes ViewModel via @StateObject              │
│  • Sends user actions to ViewModel                  │
│  • Zero business logic                              │
└───────────────────┬─────────────────────────────────┘
                    │ @Published bindings
                    ▼
┌─────────────────────────────────────────────────────┐
│                   VIEWMODEL                         │
│  PortfolioViewModel, StockDetailViewModel           │
│  • Owns all UI state (@Published)                   │
│  • Applies filtering, sorting, search               │
│  • Coordinates with Service layer                   │
│  • Uses Combine for reactive data flow              │
└───────────────────┬─────────────────────────────────┘
                    │ protocol calls
                    ▼
┌─────────────────────────────────────────────────────┐
│                   SERVICE                           │
│  PortfolioService (PortfolioServiceProtocol)        │
│  • CRUD operations via UserDefaults + JSON          │
│  • Publishes changes via Combine                    │
│  • Simulates price changes (no API needed)          │
└───────────────────┬─────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│                   MODEL                             │
│  Stock, PortfolioSummary, PricePoint                │
│  • Plain Swift structs, Codable                     │
│  • No UIKit/SwiftUI imports                         │
└─────────────────────────────────────────────────────┘
```

---

## Features

- ✅ Full MVVM with Combine reactive bindings
- ✅ Portfolio overview with total P&L, invested, current value
- ✅ Per-stock detail: shares, avg. price, P&L, price history chart
- ✅ Search by symbol or company name
- ✅ Filter by sector (Technology, Finance, Healthcare, etc.)
- ✅ Multi-column sort (symbol, gain/loss, value, date)
- ✅ Add/edit/delete holdings
- ✅ 30-day simulated price history with sparkline chart
- ✅ Demo data seeded on first launch
- ✅ Refresh to simulate market price movement
- ✅ **Zero external dependencies**

---

## Local Storage

All data is stored with `UserDefaults` + JSON encoding. No cloud services required.

```swift
// Reactive updates via Combine
PortfolioService.shared.portfolioPublisher
    .receive(on: DispatchQueue.main)
    .sink { stocks in
        // update UI
    }
    .store(in: &cancellables)
```

---

## Project Structure

```
StockWatchMVVM/
├── Models/
│   └── Stock.swift               # Stock, PortfolioSummary, PricePoint, enums
├── Services/
│   └── PortfolioService.swift    # Local CRUD + price simulation + Combine publisher
├── ViewModels/
│   └── PortfolioViewModel.swift  # PortfolioViewModel + StockDetailViewModel
└── Views/
    └── PortfolioView.swift       # SwiftUI: PortfolioView, Detail, Add, Row
```

---

## Getting Started

1. Clone the repo
2. Open in Xcode (iOS 16+)
3. Build & run — demo data loads automatically on first launch
4. Tap **↻** to simulate price updates

No API keys. No accounts. No network access needed.

---

## Testing the ViewModel

The service is protocol-driven — swap in a mock for unit tests:

```swift
final class MockPortfolioService: PortfolioServiceProtocol {
    var portfolioPublisher: AnyPublisher<[Stock], Never> { ... }
    func fetchPortfolio() -> [Stock] { return mockStocks }
    // ...
}

final class PortfolioViewModelTests: XCTestCase {
    func test_searchFilter_reducesResults() async {
        let service = MockPortfolioService()
        let vm = await PortfolioViewModel(service: service)
        await MainActor.run { vm.searchQuery = "AAPL" }
        XCTAssertEqual(vm.filteredStocks.count, 1)
    }
}
```

---

## Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15+
- No external dependencies

---

## Author

**Pratik Joshi** — Sr. iOS Developer  
[LinkedIn](https://www.linkedin.com/in/pratik-joshi-ios) · [Portfolio](https://portfolios-eight-eosin.vercel.app)

---

## License

MIT
