import { useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { Navbar } from '../../components/layout/Navbar'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { RedirectIfAuthenticated } from '../../components/auth/RedirectIfAuthenticated'
import { ApiError, sendOtp } from '../../api/client'
import { normalizePhone } from '../../lib/format'

export function PhoneLoginPage() {
  const { state } = useLocation() as {
    state?: { email?: string; emailProofToken?: string }
  }
  const emailProofToken =
    state?.emailProofToken || sessionStorage.getItem('bullwave_email_proof') || ''
  const email = state?.email || sessionStorage.getItem('bullwave_verified_email') || ''

  const [phone, setPhone] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    if (!emailProofToken) {
      setError('Verify your email first.')
      navigate('/login', { replace: true })
      return
    }
    const normalized = normalizePhone(phone)
    if (normalized.length !== 10) {
      setError('Enter a valid 10-digit mobile number')
      return
    }
    setLoading(true)
    try {
      const res = await sendOtp(normalized)
      navigate('/login/otp', {
        state: {
          phone: normalized,
          email,
          emailProofToken,
          devOtp: res.devOtp,
          otpMode: res.otpMode,
        },
      })
    } catch (err: unknown) {
      if (err instanceof ApiError) setError(err.message)
      else setError('Could not send OTP')
    } finally {
      setLoading(false)
    }
  }

  return (
    <RedirectIfAuthenticated>
      <Navbar />
      <main className="mx-auto flex min-h-[70vh] max-w-md flex-col justify-center px-4 py-12">
        <p className="mb-2 text-xs font-medium uppercase tracking-wider text-brand-lime">
          Step 2 of 2 · Phone
        </p>
        <h1 className="text-2xl font-bold">Verify your phone</h1>
        <p className="mt-2 text-sm text-muted">
          {email ? (
            <>
              Email verified: <span className="text-white">{email}</span>. Now confirm your mobile
              number.
            </>
          ) : (
            "We'll send a 6-digit OTP to your phone."
          )}
        </p>
        <form onSubmit={handleSubmit} className="mt-8 space-y-4">
          <Input
            label="Mobile number"
            placeholder="9876543210"
            inputMode="numeric"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            error={error}
          />
          <Button type="submit" className="w-full" disabled={loading}>
            {loading ? 'Sending…' : 'Send phone OTP'}
          </Button>
        </form>
      </main>
    </RedirectIfAuthenticated>
  )
}
