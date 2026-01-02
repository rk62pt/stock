import { NextResponse } from 'next/server';

// Interface for TWSE STOCK_DAY_ALL (Full List)
interface TwseStockDayAll {
    Code: string;
    Name: string;
    ClosingPrice: string;
    Change: string;
    // Other fields available but unused: TradeVolume, TradeValue, OpeningPrice, etc.
}

// Interface for TWSE STOCK_DAY (Individual Daily Report)
// Response format: { date: "20251231", data: [ ["114/12/31", "1,000", "1,000", "990", "1,000", "+10.0", ...], ... ] }
// Fields indices:
// 0: Date (e.g. 114/12/31)
// 6: ClosingPrice
// 7: Change (e.g. +10.00, -5.50, X0.00)

// Simple in-memory cache for the full list
let searchCache: TwseStockDayAll[] | null = null;
let lastSearchFetchTime = 0;
const SEARCH_CACHE_DURATION = 60 * 1000; // 60 seconds

export const dynamic = 'force-dynamic';

// Helper to fetch full list for SEARCH
async function getStockDayAll(): Promise<TwseStockDayAll[]> {
    const now = Date.now();
    if (searchCache && (now - lastSearchFetchTime < SEARCH_CACHE_DURATION)) {
        return searchCache;
    }

    try {
        const res = await fetch('https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL');
        if (!res.ok) {
            throw new Error(`TWSE API error: ${res.status}`);
        }
        const data = await res.json();
        searchCache = data;
        lastSearchFetchTime = now;
        return data;
    } catch (error) {
        console.error("Failed to fetch STOCK_DAY_ALL:", error);
        return searchCache || [];
    }
}

// Helper to fetch individual daily data for WATCHLIST/QUOTES
async function getIndividualStockDay(code: string) {
    // Format date as YYYYMMDD
    const today = new Date();
    const yyyy = today.getFullYear();
    const mm = String(today.getMonth() + 1).padStart(2, '0');
    const dd = String(today.getDate()).padStart(2, '0');
    const dateStr = `${yyyy}${mm}${dd}`;

    const url = `https://www.twse.com.tw/exchangeReport/STOCK_DAY?response=json&date=${dateStr}&stockNo=${code}`;

    try {
        const res = await fetch(url);
        if (!res.ok) return null;

        const json = await res.json();
        // If "stat" is not OK or no data, return null
        if (json.stat !== 'OK' || !json.data || json.data.length === 0) {
            return null;
        }

        // Get the last entry (latest trading day in this month)
        // Data format: [Date, Vol, VolMoney, Open, High, Low, Close, Change, Trans]
        const lastEntry = json.data[json.data.length - 1];

        const closePriceStr = lastEntry[6].replace(/,/g, '');
        const changeStr = lastEntry[7].replace(/,/g, '').replace(/X/g, ''); // Remove 'X' which sometimes denotes Ex-dividend

        const close = parseFloat(closePriceStr) || 0;
        const change = parseFloat(changeStr) || 0;

        // Calculate previous close to determine percent
        // Close = Prev + Change  => Prev = Close - Change
        // Percent = (Change / Prev) * 100
        const prevClose = close - change;
        let changePercent = 0;
        if (prevClose !== 0) {
            changePercent = (change / prevClose) * 100;
        }

        return {
            price: close,
            change: change,
            changePercent: changePercent
        };

    } catch (error) {
        console.error(`Failed to fetch individual data for ${code}:`, error);
        return null;
    }
}


export async function GET(request: Request) {
    const { searchParams } = new URL(request.url);
    const symbolsParam = searchParams.get('symbols');
    const queryParam = searchParams.get('query');

    // Helper to add CORS headers
    const headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
    };

    // --- SEARCH LOGIC (Use Cached Full List) ---
    if (queryParam) {
        const allStocks = await getStockDayAll();
        const lowerQuery = queryParam.toLowerCase();

        const filtered = allStocks.filter(stock =>
            stock.Code.includes(lowerQuery) ||
            stock.Name.includes(lowerQuery)
        ).slice(0, 10);

        const results = filtered.map(stock => ({
            symbol: `${stock.Code}.TW`,
            regularMarketPrice: parseFloat(stock.ClosingPrice) || 0,
            regularMarketChange: parseFloat(stock.Change) || 0,
            regularMarketChangePercent: 0, // List view doesn't technically need precise percent, or we could calc it
            shortName: stock.Name,
            longName: stock.Name,
        }));

        return NextResponse.json({ results }, { headers });
    }

    // --- QUOTES LOGIC (Fetch Fresh Individual Data) ---
    if (symbolsParam) {
        const requestedSymbols = symbolsParam.split(',').map(s => s.trim().replace('.TW', ''));

        if (requestedSymbols.length === 0) {
            return NextResponse.json({ data: [] }, { headers });
        }

        // We also check the full list just to get the Names (since individual API doesn't return easy machine-readable name in data array)
        const allStocks = await getStockDayAll();

        const quotePromises = requestedSymbols.map(async (code) => {
            // 1. Get basic info (Name) from cached list
            const basicInfo = allStocks.find(s => s.Code === code);
            const name = basicInfo ? basicInfo.Name : code;

            // 2. Fetch fresh detailed data
            const freshData = await getIndividualStockDay(code);

            if (freshData) {
                return {
                    symbol: `${code}.TW`,
                    regularMarketPrice: freshData.price,
                    regularMarketChange: freshData.change,
                    regularMarketChangePercent: freshData.changePercent,
                    shortName: name,
                    longName: name,
                };
            } else {
                // Fallback to cached data if individual fetch fails
                if (basicInfo) {
                    const close = parseFloat(basicInfo.ClosingPrice) || 0;
                    const change = parseFloat(basicInfo.Change) || 0;
                    let pct = 0;
                    if (close - change !== 0) pct = (change / (close - change)) * 100;

                    return {
                        symbol: `${code}.TW`,
                        regularMarketPrice: close,
                        regularMarketChange: change,
                        regularMarketChangePercent: pct,
                        shortName: name,
                        longName: name,
                    };
                }
                // Completely failed
                return null;
            }
        });

        const quotes = await Promise.all(quotePromises);
        const validQuotes = quotes.filter(Boolean);

        return NextResponse.json({ data: validQuotes }, { headers });
    }

    return NextResponse.json(
        { error: 'No symbols or query provided' },
        { status: 400, headers }
    );
}

export async function OPTIONS() {
    return NextResponse.json({}, {
        headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
        },
    });
}
