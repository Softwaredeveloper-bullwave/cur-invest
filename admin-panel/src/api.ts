const API_BASE =
  (import.meta.env.VITE_API_BASE_URL as string | undefined)?.replace(/\/$/, '') ??
  (import.meta.env.DEV
    ? '/api/v1/admin-panel'
    : `${window.location.protocol}//${window.location.hostname}:8000/api/v1/admin-panel`)

const TOKEN_KEY = 'bullwave_admin_access'

/** Vite dev server: skip login screen. Set VITE_ADMIN_DEV_NO_AUTH=false to test login locally. */
export const DEV_NO_AUTH =
  import.meta.env.DEV && import.meta.env.VITE_ADMIN_DEV_NO_AUTH !== 'false'

export function getToken() {
  return sessionStorage.getItem(TOKEN_KEY)
}

export function setToken(token: string) {
  sessionStorage.setItem(TOKEN_KEY, token)
}

export function clearToken() {
  sessionStorage.removeItem(TOKEN_KEY)
}

type ApiOptions = Omit<RequestInit, 'body'> & {
  body?: BodyInit | Record<string, unknown>
}

export async function api<T>(path: string, options: ApiOptions = {}): Promise<T> {
  const headers = new Headers(options.headers)
  const token = getToken()
  if (token) headers.set('Authorization', `Bearer ${token}`)

  let body = options.body
  if (body && typeof body === 'object' && !(body instanceof FormData)) {
    headers.set('Content-Type', 'application/json')
    body = JSON.stringify(body)
  }

  let response: Response
  try {
    response = await fetch(`${API_BASE}${path}`, { ...options, headers, body: body as BodyInit })
  } catch {
    throw new Error(
      `Cannot reach the API at ${API_BASE}. ` +
        'Start Django on port 8000 (see admin-panel/README.md), or set VITE_API_BASE_URL in admin-panel/.env and restart Vite.',
    )
  }
  const data = await response.json().catch(() => ({}))
  if (!response.ok) {
    if (response.status === 401) clearToken()
    const detail =
      typeof data.detail === 'string'
        ? data.detail
        : typeof data.message === 'string'
          ? data.message
          : response.status >= 500
            ? `Server error (${response.status}). Check that the API is deployed and restarted on EC2.`
            : `Request failed (${response.status})`
    throw new Error(detail)
  }
  return data as T
}

export { API_BASE }
