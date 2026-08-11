export type User = {
  id: string
  name: string
  phone: string
  email: string
  emailVerified: boolean
  hasCompletedOnboarding: boolean
  kycStatus: string
}

export type Stock = {
  symbol: string
  name: string
  ltp: number
  change: number
  changePercent: number
  sector?: string
  open?: number
  high?: number
  low?: number
  previousClose?: number
  volume?: number
}

export type Candle = {
  time: string
  open: number
  high: number
  low: number
  close: number
  volume: number
}

export type ChartInterval = '1m' | '5m' | '30m' | '1h' | '1d' | '90d'

export type OptionContract = {
  symbol: string
  strike: number
  type: 'CE' | 'PE'
  ltp: number
  change: number
  oi: number
  volume: number
  expiry: string
}

export type OptionChain = {
  symbol: string
  underlyingValue: number
  expiryDates: string[]
  selectedExpiry: string
  updatedAt?: string
  provider?: string
  contracts: OptionContract[]
}

export type OptionHolding = {
  underlying: string
  assetClass: string
  strike: number
  optionType: string
  expiry: string
  contractLabel: string
  quantity: number
  avgPremium: number
  lotSize: number
}

export type OptionTrade = {
  id: string
  underlying: string
  assetClass: string
  strike: number
  optionType: string
  expiry: string
  contractLabel: string
  side: string
  quantity: number
  premium: number
  lotSize: number
  amountInr: number
  orderValueInr?: number
  time: string
  status: string
  practiceWalletBalance?: number
  realizedPnlInr?: number
  holdingQty?: number
}

export type PlaceOptionOrderInput = {
  underlying: string
  strike: number
  optionType: 'CE' | 'PE' | 'FU'
  expiry: string
  side: 'BUY' | 'SELL'
  quantity: number
  premium: number
  assetClass?: 'equity_fno' | 'commodity'
}

export type MarketIndex = {
  id: string
  name: string
  value: number
  change: number
  changePercent: number
}

export type PaperTrade = {
  id: string
  symbol: string
  side: string
  quantity: number
  price: number
  totalValue: number
  pnl?: number
  createdAt: string
}

export type PracticeWallet = {
  balance: number
  initialBalance: number
}

export type PortfolioSummary = {
  totalInvested: number
  currentValue: number
  pnl: number
  pnlPercent: number
}
