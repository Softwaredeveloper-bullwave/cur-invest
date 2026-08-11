import { useEffect, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { Navbar } from '../../components/layout/Navbar'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { RedirectIfAuthenticated } from '../../components/auth/RedirectIfAuthenticated'
import { ApiError, sendOtp, verifyOtp } from '../../api/client'
import { useAuth } from '../../context/AuthContext'

const RESEND_COOLDOWN_SEC = 30

export function OtpPage() {
  const { state } = useLocation() as {
    state?: {
      phone?: string
      email?: string
      emailProofToken?: string
      devOtp?: string
      otpMode?: string
    }
  }
  const phone = state?.phone ?? ''
  const emailProofToken =
    state?.emailProofToken || sessionStorage.getItem('bullwave_email_proof') || ''
  const navigate = useNavigate()
  const { login } = useAuth()
  const [otp, setOtp] = useState('')
  const [error, setError] = useState('')
  const [info, setInfo] = useState('')
  const [loading, setLoading] = useState(false)
  const [resending, setResending] = useState(false)
  const [secondsLeft, setSecondsLeft] = useState(RESEND_COOLDOWN_SEC)
  const [devOtp, setDevOtp] = useState(state?.devOtp ?? '')

  useEffect(() => {
    if (secondsLeft <= 0) return
    const id = window.setTimeout(() => setSecondsLeft((s) => s - 1), 1000)
    return () => window.clearTimeout(id)
  }, [secondsLeft])

  if (!phone) {
    navigate('/login/phone', { replace: true })
    return null
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setInfo('')
    setLoading(true)
    try {
      const res = await verifyOtp(phone, otp.trim(), emailProofToken || undefined)
      sessionStorage.removeItem('bullwave_email_proof')
      sessionStorage.removeItem('bullwave_verified_email')
      login(res.access, res.refresh, res.user)
      if (res.user.hasCompletedOnboarding) {
        navigate('/app', { replace: true })
      } else {
        navigate('/app/onboarding/profile', { replace: true })
      }
    } catch (err: unknown) {
      setError(err instanceof ApiError ? err.message : 'Invalid OTP')
    } finally {
      setLoading(false)
    }
  }

  async function handleResend() {
    if (secondsLeft > 0 || resending || loading) return
    setError('')
    setInfo('')
    setResending(true)
    try {
      const res = await sendOtp(phone)
      setOtp('')
      setDevOtp(res.devOtp ?? '')
      setSecondsLeft(RESEND_COOLDOWN_SEC)
      setInfo(
        res.devOtp
          ? `New code sent. Dev OTP: ${res.devOtp}`
          : `OTP resent to +91 ${phone}`,
      )
    } catch (err: unknown) {
      setError(err instanceof ApiError ? err.message : 'Could not resend OTP')
    } finally {
      setResending(false)
    }
  }

  const canResend = secondsLeft === 0 && !resending && !loading

  return (
    <RedirectIfAuthenticated>
      <Navbar />
      <main className="mx-auto max-w-md px-4 py-12">
        <p className="mb-2 text-xs font-medium uppercase tracking-wider text-brand-lime">
          Step 2 of 2 · Phone
        </p>
        <h1 className="text-2xl font-bold">Enter phone OTP</h1>
        <p className="mt-2 text-sm text-muted">Sent to +91 {phone}</p>
        {devOtp && (
          <p className="mt-2 rounded-lg bg-brand-gold/10 px-3 py-2 text-sm text-brand-gold">
            Dev OTP: {devOtp}
          </p>
        )}
        <form onSubmit={handleSubmit} className="mt-8 space-y-4">
          <Input
            label="6-digit OTP"
            placeholder="123456"
            inputMode="numeric"
            maxLength={6}
            value={otp}
            onChange={(e) => {
              setOtp(e.target.value)
              setError('')
              setInfo('')
            }}
            error={error}
            hint={info && !error ? info : undefined}
          />
          <Button type="submit" className="w-full" disabled={loading || resending}>
            {loading ? 'Verifying…' : 'Verify & continue'}
          </Button>
        </form>

        <div className="mt-6 text-center text-sm">
          {canResend ? (
            <button
              type="button"
              onClick={() => void handleResend()}
              disabled={resending}
              className="font-medium text-brand-lime hover:underline disabled:opacity-60"
            >
              {resending ? 'Sending…' : 'Resend OTP'}
            </button>
          ) : (
            <p className="text-muted">
              Resend in 0:{secondsLeft.toString().padStart(2, '0')}
            </p>
          )}
        </div>
      </main>
    </RedirectIfAuthenticated>
  )
}
