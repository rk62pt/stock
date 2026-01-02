const pkg = require('yahoo-finance2');
const YahooFinance = pkg.YahooFinance || pkg.default || pkg;

async function test() {
    try {
        console.log("Trying to instantiate...");
        const yf = new YahooFinance();
        console.log("Instantiation success");
        const results = await yf.quote('2330.TW');
        console.log("Success:", results);
    } catch (e) {
        console.error("Instantiation or Quote Error:", e.message);

        // Fallback: maybe it's already an instance?
        try {
            console.log("Trying as instance...");
            const yf = pkg.default || pkg;
            const results = await yf.quote('2330.TW');
            console.log("Success (instance):", results);
        } catch (e2) {
            console.error("Instance Error:", e2.message);
        }
    }
}

test();
