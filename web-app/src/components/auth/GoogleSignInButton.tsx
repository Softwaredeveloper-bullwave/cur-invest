import { useCallback, useEffect, useRef, useState } from 'react'
import { api } from '../../api/client'

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (config: Record<string, unknown>) => void
          renderButton: (el: HTMLElement, config: Record<string, unknown>) => void
          prompt: (cb?: (notification: {
            isNotDisplayed: () => boolean
            isSkippedMoment: () => boolean
            isDismissedMoment: () => boolean
          }) => void) => void
          cancel: () => void
        }
      }
    }
  }
}

const SCRIPT_ID = 'google-gsi-client'

function loadGoogleScript(): Promise<void> {
  if (window.google?.accounts?.id) return Promise.resolve()
  const existing = document.getElementById(SCRIPT_ID) as HTMLScriptElement | null
  if (existing) {
    return new Promise((resolve, reject) => {
      if (window.google?.accounts?.id) {
        resolve()
        return
      }
      existing.addEventListener('load', () => resolve())
      existing.addEventListener('error', () => reject(new Error('Google script failed')))
    })
  }
  return new Promise((resolve, reject) => {
    const script = document.createElement('script')
    script.id = SCRIPT_ID
    script.src = 'https://accounts.google.com/gsi/client'
    script.async = true
    script.defer = true
    script.onload = () => resolve()
    script.onerror = () => reject(new Error('Could not load Google Sign-In'))
    document.head.appendChild(script)
  })
}

function GoogleLogo({ className = '' }: { className?: string }) {
  return (
    <svg className={className} width="20" height="20" viewBox="0 0 48 48" aria-hidden>
      <path
        fill="#EA4335"
        d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"
      />
      <path
        fill="#4285F4"
        d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"
      />
      <path
        fill="#FBBC05"
        d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"
      />
      <path
        fill="#34A853"
        d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"
      />
    </svg>
  )
}

type Props = {
  onCredential: (idToken: string) => void
  onUseEmailFallback?: () => void
  onError?: (message: string) => void
  disabled?: boolean
}

export function GoogleSignInButton({
  onCredential,
  onUseEmailFallback,
  onError,
  disabled,
}: Props) {
  const [clientId, setClientId] = useState(
    () => (import.meta.env.VITE_GOOGLE_CLIENT_ID as string | undefined)?.trim() || '',
  )
  const [loadingConfig, setLoadingConfig] = useState(true)
  const [renderFailed, setRenderFailed] = useState(false)
  const [busy, setBusy] = useState(false)
  const buttonHostRef = useRef<HTMLDivElement>(null)
  const cbRef = useRef(onCredential)
  const onErrorRef = useRef(onError)
  cbRef.current = onCredential
  onErrorRef.current = onError

  const oauthReady = Boolean(clientId)

  useEffect(() => {
    let cancelled = false
    void (async () => {
      let id = (import.meta.env.VITE_GOOGLE_CLIENT_ID as string | undefined)?.trim() || ''
      if (!id) {
        try {
          const cfg = await api<{ enabled: boolean; clientId: string }>('/auth/google/config/', {
            auth: false,
          })
          id = (cfg.clientId || '').trim()
        } catch {
          id = ''
        }
      }
      if (!cancelled) {
        setClientId(id)
        setLoadingConfig(false)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [])

  const initGoogle = useCallback(async (id: string) => {
    await loadGoogleScript()
    if (!window.google?.accounts?.id) throw new Error('Google Sign-In unavailable')
    window.google.accounts.id.initialize({
      client_id: id,
      callback: (response: { credential?: string }) => {
        setBusy(false)
        if (response.credential) cbRef.current(response.credential)
        else onErrorRef.current?.('Google did not return a credential. Try again.')
      },
      auto_select: false,
      cancel_on_tap_outside: true,
      context: 'signin',
      ux_mode: 'popup',
    })
  }, [])

  // Render Google's official button (reliable popup / account chooser).
  useEffect(() => {
    if (!clientId || !buttonHostRef.current || loadingConfig) return
    let cancelled = false
    void (async () => {
      try {
        await initGoogle(clientId)
        if (cancelled || !buttonHostRef.current || !window.google) return
        buttonHostRef.current.innerHTML = ''
        window.google.accounts.id.renderButton(buttonHostRef.current, {
          type: 'standard',
          theme: 'outline',
          size: 'large',
          text: 'continue_with',
          shape: 'pill',
          width: 400,
          logo_alignment: 'left',
        })
        setRenderFailed(false)
      } catch {
        if (!cancelled) setRenderFailed(true)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [clientId, initGoogle, loadingConfig])

  async function handleFallbackClick() {
    if (disabled || busy || loadingConfig) return
    if (!oauthReady) {
      onUseEmailFallback?.()
      return
    }
    setBusy(true)
    try {
      await initGoogle(clientId)
      const btn = buttonHostRef.current?.querySelector('div[role="button"]') as HTMLElement | null
      if (btn) {
        btn.click()
        window.setTimeout(() => setBusy(false), 8000)
        return
      }
      window.google?.accounts.id.prompt((notification) => {
        if (
          notification.isNotDisplayed() ||
          notification.isSkippedMoment() ||
          notification.isDismissedMoment()
        ) {
          setBusy(false)
          onErrorRef.current?.(
            'Could not open Google sign-in. In Google Cloud → Credentials, add Authorized JavaScript origin http://localhost:5174, then refresh. Or use email OTP below.',
          )
        }
      })
      window.setTimeout(() => setBusy(false), 8000)
    } catch (err) {
      setBusy(false)
      onError?.(err instanceof Error ? err.message : 'Google Sign-In failed')
    }
  }

  if (loadingConfig) {
    return (
      <button
        type="button"
        disabled
        className="flex w-full items-center justify-center gap-3 rounded-xl border border-white/15 bg-white px-4 py-3 text-sm font-semibold text-[#1f1f1f] opacity-60"
      >
        <GoogleLogo />
        Loading…
      </button>
    )
  }

  if (!oauthReady) {
    return (
      <button
        type="button"
        onClick={handleFallbackClick}
        disabled={disabled}
        className="flex w-full items-center justify-center gap-3 rounded-xl border border-white/15 bg-white px-4 py-3 text-sm font-semibold text-[#1f1f1f] transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-60"
      >
        <GoogleLogo />
        Continue with Gmail
      </button>
    )
  }

  return (
    <div className="relative w-full">
      {/* Official GIS button — this is what opens Google */}
      <div
        ref={buttonHostRef}
        className={`flex w-full justify-center overflow-hidden rounded-xl bg-white [&_iframe]:!w-full ${disabled ? 'pointer-events-none opacity-60' : ''}`}
      />
      {(renderFailed || busy) && (
        <button
          type="button"
          onClick={() => void handleFallbackClick()}
          disabled={disabled || busy}
          className="mt-2 flex w-full items-center justify-center gap-3 rounded-xl border border-white/15 bg-white px-4 py-3 text-sm font-semibold text-[#1f1f1f] transition hover:bg-gray-50 disabled:opacity-60"
        >
          <GoogleLogo />
          {busy ? 'Opening Google…' : 'Continue with Google'}
        </button>
      )}
    </div>
  )
}
