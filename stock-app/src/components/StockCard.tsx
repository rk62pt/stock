import { Trash2, TrendingUp, TrendingDown } from "lucide-react";
import { cn } from "@/lib/utils";

interface StockData {
    symbol: string;
    regularMarketPrice: number;
    regularMarketChange: number;
    regularMarketChangePercent: number;
    shortName?: string;
    longName?: string;
}

interface StockCardProps {
    stock: StockData;
    onRemove: (symbol: string) => void;
}

export function StockCard({ stock, onRemove }: StockCardProps) {
    const isUp = stock.regularMarketChange > 0;
    const isDown = stock.regularMarketChange < 0;
    const colorClass = isUp ? "text-red-500" : isDown ? "text-green-500" : "text-gray-500";

    // Format percentage: 2.5 -> +2.50%
    const percent = (stock.regularMarketChangePercent || 0).toFixed(2);
    const change = (stock.regularMarketChange || 0).toFixed(2);

    return (
        <div className="relative group p-4 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm hover:shadow-md transition-shadow">
            <div className="flex justify-between items-start">
                <div>
                    <h3 className="font-bold text-lg text-gray-900 dark:text-gray-100">
                        {stock.shortName || stock.symbol}
                    </h3>
                    <p className="text-sm text-gray-500 font-mono">{stock.symbol}</p>
                </div>
                <div className="text-right">
                    <p className={cn("text-2xl font-bold font-mono tracking-tighter", colorClass)}>
                        {stock.regularMarketPrice?.toFixed(2)}
                    </p>
                    <div className={cn("flex items-center justify-end text-sm font-medium space-x-1", colorClass)}>
                        {isUp && <TrendingUp size={16} />}
                        {isDown && <TrendingDown size={16} />}
                        <span>
                            {stock.regularMarketChange > 0 ? '+' : ''}{change} ({stock.regularMarketChange > 0 ? '+' : ''}{percent}%)
                        </span>
                    </div>
                </div>
            </div>

            <button
                onClick={() => onRemove(stock.symbol)}
                className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 p-1.5 text-gray-400 hover:text-red-500 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-all"
                aria-label="Remove stock"
            >
                <Trash2 size={16} />
            </button>
        </div>
    );
}
