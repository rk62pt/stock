const pkg = require('yahoo-finance2');

async function test() {
    console.log("Starting test...");
    let yf;
    try {
        const YahooFinance = pkg.YahooFinance || pkg.default || pkg;
        try {
            yf = new YahooFinance();
        } catch (e) {
            yf = YahooFinance;
        }
    } catch (e) {
        console.error("Setup failed:", e);
        return;
    }

    try {
        const query = '1519';
        console.log(`Searching for ${query}...`);
        const results = await yf.search(query);
        console.log("Search Success!");
        console.log("Keys:", Object.keys(results));

        if (results.quotes) {
            console.log("Quotes found:", results.quotes.length);
            if (results.quotes.length > 0) {
                console.log("First quote:", results.quotes[0]);
            }
        } else {
            console.log("WARNING: results.quotes is missing!");
        }

    } catch (e) {
        console.error("Search Error:", e.message);
    }
}

test();
