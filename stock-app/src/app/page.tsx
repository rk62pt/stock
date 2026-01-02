"use client";

import { useEffect, useState, useCallback } from "react";
import { StockCard } from "@/components/StockCard";
import { Search, Plus, RefreshCw, AlertCircle } from "lucide-react";
import { cn } from "@/lib/utils";

interface StockData {
    symbol: string;
    regularMarketPrice: number;
    regularMarketChange: number;
    regularMarketChangePercent: number;
    shortName?: string;
    longName?: string;
}

const DEFAULT_STOCKS = ["2330.TW", "0050.TW", "2454.TW"];

export default function Home() {
    const [symbols, setSymbols] = useState<string[]>([]);
    const [stocks, setStocks] = useState<StockData[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [searchQuery, setSearchQuery] = useState("");
    const [searchResults, setSearchResults] = useState<StockData[]>([]);
    const [isSearching, setIsSearching] = useState(false);
    const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

    // Initialize from Server
    useEffect(() => {
        const loadPortfolio = async () => {
            try {
                const res = await fetch('/api/portfolio');
                if (res.ok) {
                    const json = await res.json();
                    if (json.symbols && Array.isArray(json.symbols)) {
                        setSymbols(json.symbols);
                    }
                }
            } catch (error) {
                console.error("Failed to load portfolio", error);
                setSymbols(DEFAULT_STOCKS);
            }
        };
        loadPortfolio();
    }, []);

    // Save to Server Helper
    const savePortfolio = async (newSymbols: string[]) => {
        try {
            await fetch('/api/portfolio', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ symbols: newSymbols }),
            });
        } catch (error) {
            console.error("Failed to save portfolio", error);
        }
    };

    // Fetch Stock Data
    const fetchStocks = useCallback(async () => {
        if (symbols.length === 0) {
            setStocks([]);
            setLoading(false);
            return;
        }

        try {
            setError(null);
            const res = await fetch(`/api/stocks?symbols=${symbols.join(',')}&t=${new Date().getTime()}`);

            if (!res.ok) {
                throw new Error("Failed to fetch");
            }

            const json = await res.json();
            if (json.data) {
                // Map to ensure we match the requested order or just replace
                setStocks(json.data);
                setLastUpdated(new Date());
            } else if (json.error) {
                setError(json.error);
            }
        } catch (error) {
            console.error("Failed to fetch stocks", error);
            setError("無法取得股價資訊");
        } finally {
            setLoading(false);
        }
    }, [symbols]);

    // Polling
    useEffect(() => {
        fetchStocks();
        const interval = setInterval(fetchStocks, 10000); // 10 seconds
        return () => clearInterval(interval);
    }, [fetchStocks]);

    // Handle Search
    const handleSearch = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!searchQuery.trim()) return;

        setIsSearching(true);
        setSearchResults([]);
        try {
            const res = await fetch(`/api/stocks?query=${encodeURIComponent(searchQuery)}`);
            const json = await res.json();
            if (json.results) {
                setSearchResults(json.results);
            }
        } catch (error) {
            console.error("Search failed", error);
        } finally {
            setIsSearching(false);
        }
    };

    const addStock = (symbol: string) => {
        if (!symbols.includes(symbol)) {
            const newSymbols = [...symbols, symbol];
            setSymbols(newSymbols);
            savePortfolio(newSymbols);
            setSearchQuery(""); // Clear search
            setSearchResults([]); // Clear results
        }
    };

    const removeStock = (symbolToRem: string) => {
        const newSymbols = symbols.filter(s => s !== symbolToRem);
        setSymbols(newSymbols);
        savePortfolio(newSymbols);
    };

    // Convert stock array to map for easy lookup if needed, but array is fine for < 20 stocks

    return (
        <div className="min-h-screen bg-gray-50 dark:bg-gray-950 text-gray-900 dark:text-gray-100 font-sans p-6 pb-20">
            <div className="max-w-5xl mx-auto space-y-8">

                {/* Header */}
                <header className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                    <div>
                        <h1 className="text-3xl font-extrabold tracking-tight bg-gradient-to-r from-blue-600 to-cyan-500 bg-clip-text text-transparent">
                            台股即時看板
                        </h1>
                        <p className="text-sm text-gray-500 mt-1 flex items-center gap-2">
                            <span className={cn("inline-block w-2 h-2 rounded-full animate-pulse", error ? "bg-red-500" : "bg-green-500")}></span>
                            {error ? "系統異常" : (loading ? "連線中..." : "系統運作中")}
                            {!error && lastUpdated && ` • 更新時間: ${lastUpdated.toLocaleTimeString()}`}
                        </p>
                    </div>

                    <button
                        onClick={fetchStocks}
                        className="flex items-center gap-2 px-4 py-2 text-sm font-medium bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
                    >
                        <RefreshCw size={16} className={loading && !error ? "animate-spin" : ""} />
                        刷新報價
                    </button>
                </header>

                {/* Error Alert */}
                {error && (
                    <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 p-4 rounded-xl flex items-center gap-2">
                        <AlertCircle size={20} />
                        <p className="font-medium">{error}</p>
                    </div>
                )}
                {/* Search Section */}
                <div className="bg-white dark:bg-gray-900 p-6 rounded-2xl shadow-sm border border-gray-200 dark:border-gray-800 space-y-4">
                    <form onSubmit={handleSearch} className="flex gap-2">
                        <div className="relative flex-1">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
                            <input
                                type="text"
                                placeholder="輸入代號或名稱搜尋 (例如: 2330, 台積電)..."
                                className="w-full pl-10 pr-4 py-3 rounded-xl bg-gray-100 dark:bg-gray-800 border-transparent focus:bg-white dark:focus:bg-gray-950 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                                value={searchQuery}
                                onChange={(e) => setSearchQuery(e.target.value)}
                            />
                        </div>
                        <button
                            type="submit"
                            disabled={isSearching}
                            className="bg-blue-600 hover:bg-blue-700 text-white px-6 rounded-xl font-medium transition-colors disabled:opacity-50"
                        >
                            {isSearching ? "搜尋中..." : "搜尋"}
                        </button>
                    </form>

                    {/* Search Results */}
                    {searchResults.length > 0 && (
                        <div className="grid gap-2 mt-4 max-h-60 overflow-y-auto custom-scrollbar p-2 bg-gray-50 dark:bg-gray-800/50 rounded-lg">
                            <p className="text-xs font-semibold text-gray-500 px-2 mb-1">搜尋結果</p>
                            {searchResults.map((result) => (
                                <div key={result.symbol} className="flex items-center justify-between p-3 bg-white dark:bg-gray-900 rounded-lg border border-gray-200 dark:border-gray-800">
                                    <div>
                                        <span className="font-bold text-gray-900 dark:text-gray-100 mr-2">{result.symbol}</span>
                                        <span className="text-sm text-gray-500">{result.shortName || result.longName}</span>
                                    </div>
                                    {symbols.includes(result.symbol) ? (
                                        <span className="text-xs text-green-500 font-medium px-3 py-1 bg-green-500/10 rounded-full">已加入</span>
                                    ) : (
                                        <button
                                            onClick={() => addStock(result.symbol)}
                                            className="flex items-center gap-1 text-xs font-medium text-blue-600 hover:text-blue-700 bg-blue-50 dark:bg-blue-900/20 hover:bg-blue-100 dark:hover:bg-blue-900/40 px-3 py-1.5 rounded-full transition-colors"
                                        >
                                            <Plus size={14} /> 加入
                                        </button>
                                    )}
                                </div>
                            ))}
                        </div>
                    )}
                </div>

                {/* Stock Grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {stocks.map(stock => (
                        <StockCard key={stock.symbol} stock={stock} onRemove={removeStock} />
                    ))}

                    {stocks.length === 0 && !loading && (
                        <div className="col-span-full py-12 text-center text-gray-500">
                            <AlertCircle className="mx-auto mb-3 opacity-20" size={48} />
                            <p>目前沒有追蹤的股票</p>
                            <p className="text-sm opacity-60">請使用上方搜尋列加入股票</p>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
