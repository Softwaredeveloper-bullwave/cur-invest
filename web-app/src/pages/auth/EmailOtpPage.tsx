import { useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { Navbar } from '../../components/layout/Navbar'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import {
  RedirectIfAuthenticated,
  destinationForUser,
} from '../../components/auth/RedirectIfAuthenticated'
import { ApiError, verifyWebEmailOtp } from '../../api/client'
import { useAuth } from '../../context/AuthContext'

export function EmailOtpPage() {
  const { state } = useLocation() as {
    state?: { email?: string; devOtp?: string; otpMode?: string }
  }
  const email = state?.email ?? ''
  const navigate = useNavigate()
  const { login } = useAuth()
  const [otp, setOtp] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  if (!email) {
    navigate('/login', { replace: true })
    return null
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const res = await verifyWebEmailOtp(email, otp.trim())
      if (res.access && res.refresh && res.user) {
        sessionStorage.removeItem('bullwave_email_proof')
        sessionStorage.removeItem('bullwave_verified_email')
        login(res.access, res.refresh, res.user)
        navigate(destinationForUser(res.user), { replace: true })
        return
      }
      if (!res.emailProofToken) {
        setError('Email verified but session missing. Try again.')
        return
      }
      sessionStorage.setItem('bullwave_email_proof', res.emailProofToken)
      sessionStorage.setItem('bullwave_verified_email', res.email)
      navigate('/login/phone', {
        state: { email: res.email, emailProofToken: res.emailProofToken },
        replace: true,
      })
    } catch (err: unknown) {
      setError(err instanceof ApiError ? err.message : 'Invalid code')
    } finally {
      setLoading(false)
    }
  }

  return (
    <RedirectIfAuthenticated>
      <Navbar />
      <main className="mx-auto max-w-md px-4 py-12">
        <p className="mb-2 text-xs font-medium uppercase tracking-wider text-brand-lime">
          Step 1 of 2 · Email
        </p>
        <h1 className="text-2xl font-bold">Enter email code</h1>
        <p className="mt-2 text-sm text-muted">Sent to {email}</p>
        {state?.devOtp && (
          <p className="mt-2 rounded-lg bg-brand-gold/10 px-3 py-2 text-sm text-brand-gold">
            Dev OTP: {state.devOtp}
          </p>
        )}
        <form onSubmit={handleSubmit} className="mt-8 space-y-4">
          <Input
            label="6-digit code"
            placeholder="123456"
            inputMode="numeric"
            maxLength={6}
            value={otp}
            onChange={(e) => setOtp(e.target.value)}
            error={error}
          />
          <Button type="submit" className="w-full" disabled={loading}>
            {loading ? 'Verifying…' : 'Verify email & continue'}
          </Button>
        </form>
      </main>
    </RedirectIfAuthenticated>
  )
}
