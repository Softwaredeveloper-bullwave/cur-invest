import { useCallback, useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Navbar } from '../../components/layout/Navbar'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { GoogleSignInButton } from '../../components/auth/GoogleSignInButton'
import {
  RedirectIfAuthenticated,
  destinationForUser,
} from '../../components/auth/RedirectIfAuthenticated'
import { ApiError, loginWithGoogle, sendWebEmailOtp } from '../../api/client'
import { useAuth } from '../../context/AuthContext'

export function LoginPage() {
  const [email, setEmail] = useState('')
  const [error, setError] = useState('')
  const [hint, setHint] = useState('')
  const [loading, setLoading] = useState(false)
  const [googleLoading, setGoogleLoading] = useState(false)
  const emailInputRef = useRef<HTMLInputElement>(null)
  const navigate = useNavigate()
  const { login } = useAuth()

  function goToPhone(emailValue: string, emailProofToken: string, name?: string) {
    sessionStorage.setItem('bullwave_email_proof', emailProofToken)
    sessionStorage.setItem('bullwave_verified_email', emailValue)
    if (name) sessionStorage.setItem('bullwave_google_name', name)
    navigate('/login/phone', {
      state: { email: emailValue, emailProofToken, name },
      replace: true,
    })
  }

  async function sendEmailCode(trimmed: string) {
    setLoading(true)
    try {
      const res = await sendWebEmailOtp(trimmed)
      navigate('/login/email-otp', {
        state: { email: trimmed, devOtp: res.devOtp, otpMode: res.otpMode },
      })
    } catch (err: unknown) {
      if (err instanceof ApiError) setError(err.message)
      else if (err instanceof TypeError) {
        setError('Cannot reach API. Start Django on port 8000 or check VITE_API_BASE_URL.')
      } else setError('Could not send email OTP')
    } finally {
      setLoading(false)
    }
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setHint('')
    const trimmed = email.trim().toLowerCase()
    if (!trimmed.includes('@')) {
      setError('Enter a valid email address')
      return
    }
    await sendEmailCode(trimmed)
  }

  const handleGoogle = useCallback(
    async (idToken: string) => {
      setError('')
      setHint('')
      setGoogleLoading(true)
      try {
        const res = await loginWithGoogle(idToken)
        if (res.access && res.refresh && res.user) {
          sessionStorage.removeItem('bullwave_email_proof')
          sessionStorage.removeItem('bullwave_verified_email')
          login(res.access, res.refresh, res.user)
          navigate(destinationForUser(res.user), { replace: true })
          return
        }
        if (!res.emailProofToken) {
          setError('Google sign-in incomplete. Try email OTP.')
          return
        }
        goToPhone(res.email, res.emailProofToken, res.name)
      } catch (err: unknown) {
        setError(err instanceof ApiError ? err.message : 'Google sign-in failed')
      } finally {
        setGoogleLoading(false)
      }
    },
    [login, navigate],
  )

  function handleGmailFallback() {
    setError('')
    const trimmed = email.trim().toLowerCase()
    if (trimmed.includes('@')) {
      void sendEmailCode(trimmed)
      return
    }
    setHint('Enter your Gmail below, then tap Send email code.')
    emailInputRef.current?.focus()
  }

  return (
    <RedirectIfAuthenticated>
      <Navbar />
      <main className="mx-auto flex min-h-[70vh] max-w-md flex-col justify-center px-4 py-12">
        <p className="mb-2 text-xs font-medium uppercase tracking-wider text-brand-lime">
          Step 1 of 2 · Email
        </p>
        <h1 className="text-2xl font-bold">Sign in to BullWave</h1>
        <p className="mt-2 text-sm text-muted">
          Returning users go straight to paper trading. New users verify email, then phone once.
        </p>

        <div className="mt-8 space-y-4">
          <GoogleSignInButton
            onCredential={handleGoogle}
            onUseEmailFallback={handleGmailFallback}
            onError={setError}
            disabled={googleLoading || loading}
          />
          {googleLoading && (
            <p className="text-center text-sm text-muted">Signing in with Google…</p>
          )}

          <div className="flex items-center gap-3 text-xs text-muted">
            <div className="h-px flex-1 bg-white/10" />
            or use email OTP
            <div className="h-px flex-1 bg-white/10" />
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <Input
              ref={emailInputRef}
              label="Gmail / Email"
              type="email"
              placeholder="you@gmail.com"
              value={email}
              onChange={(e) => {
                setEmail(e.target.value)
                setHint('')
                setError('')
              }}
              error={error}
              hint={hint}
            />
            <Button type="submit" className="w-full" disabled={loading || googleLoading}>
              {loading ? 'Sending…' : 'Send email code'}
            </Button>
          </form>
        </div>

        <p className="mt-6 text-center text-xs text-muted">
          Already verified email?{' '}
          <Link to="/login/phone" className="text-brand-lime hover:underline">
            Continue with phone
          </Link>
        </p>
      </main>
    </RedirectIfAuthenticated>
  )
}
