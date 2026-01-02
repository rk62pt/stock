import { NextResponse } from 'next/server';
import fs from 'fs';
import path from 'path';

// Define the path to the stocks.json file
// Using process.cwd() ensures it's relative to the project root
const DATA_FILE_PATH = path.join(process.cwd(), 'stocks.json');

const DEFAULT_STOCKS = ["2330.TW", "0050.TW", "2454.TW"];

// Helper to read stocks
function readStocksFromFile() {
    try {
        if (!fs.existsSync(DATA_FILE_PATH)) {
            // If file doesn't exist, return defaults and create it
            writeStocksToFile(DEFAULT_STOCKS);
            return DEFAULT_STOCKS;
        }
        const fileContent = fs.readFileSync(DATA_FILE_PATH, 'utf-8');
        const data = JSON.parse(fileContent);
        return Array.isArray(data) ? data : DEFAULT_STOCKS;
    } catch (error) {
        console.error("Error reading stocks file:", error);
        return DEFAULT_STOCKS;
    }
}

// Helper to write stocks
function writeStocksToFile(stocks: string[]) {
    try {
        fs.writeFileSync(DATA_FILE_PATH, JSON.stringify(stocks, null, 2), 'utf-8');
        return true;
    } catch (error) {
        console.error("Error writing stocks file:", error);
        return false;
    }
}

export async function GET() {
    const stocks = readStocksFromFile();
    return NextResponse.json({ symbols: stocks });
}

export async function POST(request: Request) {
    try {
        const body = await request.json();
        const { symbols } = body;

        if (!Array.isArray(symbols)) {
            return NextResponse.json({ error: 'Invalid data format. "symbols" must be an array.' }, { status: 400 });
        }

        if (writeStocksToFile(symbols)) {
            return NextResponse.json({ success: true, symbols });
        } else {
            return NextResponse.json({ error: 'Failed to save data' }, { status: 500 });
        }
    } catch (error) {
        return NextResponse.json({ error: 'Invalid request' }, { status: 400 });
    }
}
