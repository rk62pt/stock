# Changelog

## [Unreleased] - 2026-01-11

### Added
- **Stock Table**:
    - Added "Market Value" (市值) and "Average Cost" (均價) columns.
    - Added sorting functionality for Market Value/Cost column.
    - Added "Total Cost" (總成本) display.
- **Transaction History Dialog**:
    - Enhanced summary section to display:
        - Market Value (市值)
        - Total Cost (總成本)
        - Unrealized Profit/Loss (未實現損益) with percentage.
        - Realized Profit/Loss (已實現損益).
    - Improved layout of the summary section for better readability.

### Changed
- **UI/UX**:
    - Updated `StockTable` column headers to be multi-line for better space utilization (e.g., "現價\n均價").
    - Adjusted column spacing and row height for a more compact yet readable view.
    - Added color coding for Profit/Loss (Red for gain, Green for loss).
