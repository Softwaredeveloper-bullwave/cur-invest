import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Navbar } from '../../components/layout/Navbar'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { ApiError, completeProfile } from '../../api/client'
import { useAuth } from '../../context/AuthContext'

export function ProfileSetupPage() {
  const [name, setName] = useState(() => sessionStorage.getItem('bullwave_google_name') || '')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()
  const { user, refreshUser } = useAuth()

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (name.trim().length < 2) {
      setError('Enter your full name')
      return
    }
    if (!user?.emailVerified) {
      setError('Verify your email first.')
      navigate('/login', { replace: true })
      return
    }
    setLoading(true)
    try {
      await completeProfile(name.trim())
      sessionStorage.removeItem('bullwave_google_name')
      await refreshUser()
      navigate('/app', { replace: true })
    } catch (err: unknown) {
      setError(err instanceof ApiError ? err.message : 'Could not save profile')
    } finally {
      setLoading(false)
    }
  }

  return (
    <>
      <Navbar />
      <main className="mx-auto max-w-md px-4 py-12">
        <h1 className="text-2xl font-bold">Almost there</h1>
        <p className="mt-2 text-sm text-muted">
          Email and phone verified. Tell us your name to unlock paper trading.
        </p>
        <form onSubmit={handleSubmit} className="mt-8 space-y-4">
          <Input
            label="Full name"
            placeholder="Your name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            error={error}
          />
          <Button type="submit" className="w-full" disabled={loading}>
            Start paper trading
          </Button>
        </form>
      </main>
    </>
  )
}

export function OnboardingRouter() {
  const { user, loading } = useAuth()
  const navigate = useNavigate()

  if (loading) return null
  if (!user) {
    navigate('/login', { replace: true })
    return null
  }
  if (!user.emailVerified) {
    navigate('/login', { replace: true })
    return null
  }
  if (!user.hasCompletedOnboarding) {
    return <ProfileSetupPage />
  }
  navigate('/app', { replace: true })
  return null
}
