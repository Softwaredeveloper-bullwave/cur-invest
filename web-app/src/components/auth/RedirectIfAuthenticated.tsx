import { Navigate } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'

/** If JWT session is saved, skip login and go to paper trading / onboarding. */
export function RedirectIfAuthenticated({ children }: { children: React.ReactNode }) {
  const { user, loading, isAuthenticated, practiceReady } = useAuth()

  if (loading) {
    return (
      <div className="flex min-h-[50vh] items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-brand-lime border-t-transparent" />
      </div>
    )
  }

  if (isAuthenticated && user) {
    if (practiceReady) return <Navigate to="/app" replace />
    return <Navigate to="/app/onboarding/profile" replace />
  }

  return <>{children}</>
}

export function destinationForUser(user: { hasCompletedOnboarding: boolean }) {
  return user.hasCompletedOnboarding ? '/app' : '/app/onboarding/profile'
}
