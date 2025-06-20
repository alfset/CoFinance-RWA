const alpacaKey = 'secret.AlpacaKey';
const alpacaSecret = 'secret.Alpcasecret';

const symbolToMint = args[0];
const paymentTokenSymbol = args[1];
const amountPaidRaw = args[2];

// Check if market is open
const marketStatusRes = await Functions.makeHttpRequest({
  url: `https://paper-api.alpaca.markets/v2/clock`,
  headers: {
    'APCA-API-KEY-ID': alpacaKey,
    'APCA-API-SECRET-KEY': alpacaSecret
  }
});

if (marketStatusRes.error) throw Error('Market status check failed');
if (!marketStatusRes.data?.is_open) return Functions.encodeUint256(0);

// Convert raw amount to float based on token decimals
const divisor = paymentTokenSymbol.toUpperCase() === 'USDC' ? 1e6 : 1e18;
const amountPaid = parseFloat(amountPaidRaw) / divisor;

// Get USD price of the token via CoinGecko
const coinGeckoIdMap = {
  'USDC': 'usd-coin',
  'WETH': 'ethereum',
  'WAVAX': 'avalanche',
  'LINK': 'chainlink'
};
const coinGeckoId = coinGeckoIdMap[paymentTokenSymbol.toUpperCase()] || paymentTokenSymbol.toLowerCase();

const priceRes = await Functions.makeHttpRequest({
  url: `https://api.coingecko.com/api/v3/simple/price?ids=${coinGeckoId}&vs_currencies=usd`
});

if (priceRes.error) throw Error('Price fetch failed');
const priceUsd = parseFloat(priceRes.data[coinGeckoId].usd);

// Compute notional amount in USD (90% safety margin)
const notionalUsd = (amountPaid * priceUsd * 0.9).toFixed(2);

// Submit a single market buy order
const orderRes = await Functions.makeHttpRequest({
  url: 'https://paper-api.alpaca.markets/v2/orders',
  method: 'POST',
  headers: {
    'APCA-API-KEY-ID': alpacaKey,
    'APCA-API-SECRET-KEY': alpacaSecret,
    'Content-Type': 'application/json'
  },
  data: {
    symbol: symbolToMint,
    notional: notionalUsd,
    side: 'buy',
    type: 'market',
    time_in_force: 'day'
  }
});

if (orderRes.error || !orderRes.data?.id) throw Error('Order failed');
const orderId = orderRes.data.id;

// Fetch order status immediately (no polling)
const statusRes = await Functions.makeHttpRequest({
  url: `https://paper-api.alpaca.markets/v2/orders/${orderId}`,
  headers: {
    'APCA-API-KEY-ID': alpacaKey,
    'APCA-API-SECRET-KEY': alpacaSecret
  }
});

if (statusRes.error) throw Error('Order status fetch failed');

const status = statusRes.data?.status;
if (status !== 'filled') return Functions.encodeUint256(0);

// Get filled quantity
const qty = parseFloat(statusRes.data?.filled_qty || "0");
const qtyInt = Math.round(qty * 1e18);
return Functions.encodeUint256(qtyInt);
