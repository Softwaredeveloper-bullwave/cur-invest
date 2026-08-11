export const FNO_INDICES = [
  { symbol: 'NIFTY', label: 'Nifty 50', exchange: 'NSE', lotSize: 25 },
  { symbol: 'BANKNIFTY', label: 'Bank Nifty', exchange: 'NSE', lotSize: 15 },
  { symbol: 'FINNIFTY', label: 'Fin Nifty', exchange: 'NSE', lotSize: 25 },
  { symbol: 'MIDCPNIFTY', label: 'Midcap Select', exchange: 'NSE', lotSize: 50 },
  { symbol: 'SENSEX', label: 'Sensex', exchange: 'BSE', lotSize: 10 },
  { symbol: 'BANKEX', label: 'Bankex', exchange: 'BSE', lotSize: 15 },
] as const

export const FNO_STOCKS = [
  'RELIANCE',
  'TCS',
  'HDFCBANK',
  'INFY',
  'ICICIBANK',
  'SBIN',
  'ITC',
  'BHARTIARTL',
  'KOTAKBANK',
  'AXISBANK',
  'LT',
  'MARUTI',
  'TITAN',
  'BAJFINANCE',
  'HCLTECH',
] as const

export const FUTURES_MARGIN_PCT = 0.12

export function fnoLotSize(symbol: string): number {
  const found = FNO_INDICES.find((i) => i.symbol === symbol.toUpperCase())
  return found?.lotSize ?? 1
}

export function futuresMarginInr(spot: number, lots: number, lotSize: number) {
  return spot * lots * lotSize * FUTURES_MARGIN_PCT
}

export function optionPremiumInr(premium: number, lots: number, lotSize: number) {
  return premium * lots * lotSize
}
