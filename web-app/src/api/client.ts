import type {
  Candle,
  ChartInterval,
  MarketIndex,
  OptionChain,
  OptionHolding,
  OptionTrade,
  PaperTrade,
  PlaceOptionOrderInput,
  PortfolioSummary,
  PracticeWallet,
  Stock,
  User,
} from './types'

const API_BASE =
  (import.meta.env.VITE_API_BASE_URL as string | undefined)?.replace(/\/$/, '') ?? '/api/v1'

const ACCESS_KEY = 'bullwave_access'
const REFRESH_KEY = 'bullwave_refresh'

export class ApiError extends Error {
  status: number
  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

export function getAccessToken() {
  return localStorage.getItem(ACCESS_KEY)
}

export function getRefreshToken() {
  return localStorage.getItem(REFRESH_KEY)
}

export function setTokens(access: string, refresh: string) {
  localStorage.setItem(ACCESS_KEY, access)
  localStorage.setItem(REFRESH_KEY, refresh)
}

export function clearTokens() {
  localStorage.removeItem(ACCESS_KEY)
  localStorage.removeItem(REFRESH_KEY)
}

async function refreshAccessToken(): Promise<string | null> {
  const refresh = getRefreshToken()
  if (!refresh) return null
  try {
    const res = await fetch(`${API_BASE}/auth/token/refresh/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-BullWave-Client': 'web' },
      body: JSON.stringify({ refresh }),
    })
    if (!res.ok) return null
    const data = (await res.json()) as { access: string; refresh?: string }
    setTokens(data.access, data.refresh ?? refresh)
    return data.access
  } catch {
    return null
  }
}

type ApiOptions = Omit<RequestInit, 'body'> & {
  body?: Record<string, unknown>
  auth?: boolean
}

export async function api<T>(path: string, options: ApiOptions = {}): Promise<T> {
  const { body, auth = true, ...init } = options
  const headers = new Headers(init.headers)
  headers.set('Accept', 'application/json')
  headers.set('X-BullWave-Client', 'web')
  if (body) headers.set('Content-Type', 'application/json')

  let token = auth ? getAccessToken() : null
  if (auth && token) headers.set('Authorization', `Bearer ${token}`)

  const doFetch = (access?: string | null) => {
    const h = new Headers(headers)
    if (auth && access) h.set('Authorization', `Bearer ${access}`)
    return fetch(`${API_BASE}${path}`, {
      ...init,
      headers: h,
      body: body ? JSON.stringify(body) : undefined,
    })
  }

  let response = await doFetch(token)

  if (response.status === 401 && auth) {
    const newToken = await refreshAccessToken()
    if (newToken) response = await doFetch(newToken)
  }

  const data = await response.json().catch(() => ({}))
  if (!response.ok) {
    const detail =
      typeof data.detail === 'string'
        ? data.detail
        : Array.isArray(data.detail)
          ? data.detail.join(', ')
          : response.status === 404
            ? 'API not found. Restart Django (python manage.py runserver) to load new routes.'
            : `Request failed (${response.status})`
    throw new ApiError(detail, response.status)
  }
  return data as T
}

// ── Auth ──

export async function sendOtp(phone: string) {
  return api<{ success: boolean; devOtp?: string; otpMode: string; isRegistered?: boolean }>(
    '/auth/send-otp/',
    { auth: false, method: 'POST', body: { phone } },
  )
}

export async function verifyOtp(phone: string, otp: string, emailProofToken?: string) {
  const body: Record<string, unknown> = { phone, otp }
  if (emailProofToken) body.emailProofToken = emailProofToken
  return api<{ access: string; refresh: string; user: User; isNewUser: boolean }>(
    '/auth/verify-otp/',
    { auth: false, method: 'POST', body },
  )
}

/** Website signup — email OTP before phone (no JWT). */
export async function sendWebEmailOtp(email: string) {
  return api<{ success: boolean; email: string; otpMode: string; devOtp?: string }>(
    '/auth/web/send-email-otp/',
    { auth: false, method: 'POST', body: { email } },
  )
}

export async function verifyWebEmailOtp(email: string, otp: string) {
  return api<{
    success: boolean
    email: string
    emailProofToken?: string
    nextStep?: 'phone' | 'app' | 'onboarding'
    isReturningUser?: boolean
    access?: string
    refresh?: string
    user?: User
    message?: string
  }>('/auth/web/verify-email-otp/', {
    auth: false,
    method: 'POST',
    body: { email, otp },
  })
}

/** Continue with Google — JWT for returning users; emailProofToken for new users. */
export async function loginWithGoogle(idToken: string) {
  return api<{
    success: boolean
    email: string
    name?: string
    emailProofToken?: string
    nextStep?: 'phone' | 'app' | 'onboarding'
    isReturningUser?: boolean
    access?: string
    refresh?: string
    user?: User
    message?: string
  }>('/auth/google/', { auth: false, method: 'POST', body: { idToken } })
}

export async function fetchGoogleAuthConfig() {
  return api<{ enabled: boolean; clientId: string }>('/auth/google/config/', { auth: false })
}

export async function sendEmailOtp(email: string) {
  return api<{ success: boolean; devOtp?: string }>('/auth/send-email-otp/', {
    method: 'POST',
    body: { email },
  })
}

export async function verifyEmailOtp(email: string, otp: string) {
  return api<{ success: boolean; user: User }>('/auth/verify-email-otp/', {
    method: 'POST',
    body: { email, otp },
  })
}

export async function completeProfile(name: string, city = '') {
  return api<User>('/users/me/complete-profile/', {
    method: 'POST',
    body: { name, city },
  })
}

export async function fetchMe() {
  return api<User>('/users/me/')
}

// ── Markets ──

export async function fetchMarketLive() {
  return api<{ stocks: Stock[]; indices: MarketIndex[]; updatedAt: string }>('/market/live/')
}

export async function searchStocks(q: string) {
  return api<Stock[]>(`/stocks/search/?q=${encodeURIComponent(q)}`)
}

export async function fetchQuote(symbol: string) {
  return api<Stock>(`/stocks/${encodeURIComponent(symbol)}/quote/`)
}

export async function fetchCandles(
  symbol: string,
  interval: ChartInterval | string = '1d',
  opts?: { fast?: boolean },
) {
  const params = new URLSearchParams({ interval })
  if (opts?.fast) params.set('fast', '1')
  return api<Candle[]>(`/stocks/${encodeURIComponent(symbol)}/candles/?${params}`)
}

// ── Paper trading ──

export async function fetchPracticeWallet() {
  return api<PracticeWallet>('/wallet/practice/')
}

export async function fetchPaperTrades() {
  return api<PaperTrade[]>('/paper-trading/orders/')
}

export async function placePaperTrade(symbol: string, side: 'BUY' | 'SELL', quantity: number) {
  return api<PaperTrade>('/paper-trading/orders/', {
    method: 'POST',
    body: { symbol, side, quantity },
  })
}

// ── F&O paper trading ──

export async function fetchOptionChain(
  symbol: string,
  opts?: { expiry?: string; fast?: boolean },
) {
  const params = new URLSearchParams()
  if (opts?.expiry) params.set('expiry', opts.expiry)
  if (opts?.fast) params.set('fast', '1')
  const q = params.toString()
  return api<OptionChain>(
    `/options/${encodeURIComponent(symbol)}/chain/${q ? `?${q}` : ''}`,
  )
}

export async function placeOptionOrder(input: PlaceOptionOrderInput) {
  return api<OptionTrade>('/options/orders/', {
    method: 'POST',
    body: {
      underlying: input.underlying,
      strike: input.strike,
      optionType: input.optionType,
      expiry: input.expiry,
      side: input.side,
      quantity: input.quantity,
      premium: input.premium,
      assetClass: input.assetClass ?? 'equity_fno',
    },
  })
}

export async function fetchOptionHoldings(assetClass = 'equity_fno') {
  return api<{ holdings: OptionHolding[] }>(
    `/options/holdings/?asset_class=${encodeURIComponent(assetClass)}`,
  )
}

export async function fetchOptionTrades() {
  return api<{ trades: OptionTrade[] }>('/options/orders/')
}

export async function fetchPortfolioAnalytics() {
  return api<PortfolioSummary & { holdings?: unknown[] }>('/portfolio/analytics/')
}

export async function fetchHealth() {
  return api<{ status: string }>('/health/', { auth: false })
}

export function isPracticeReady(user: User | null) {
  return Boolean(user?.emailVerified && user?.hasCompletedOnboarding)
}
