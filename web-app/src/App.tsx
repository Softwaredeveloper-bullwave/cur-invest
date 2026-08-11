import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './context/AuthContext'
import { AppShell } from './components/layout/AppShell'
import { LandingPage } from './pages/LandingPage'
import { PricingPage, PrivacyPage, SupportPage, TermsPage } from './pages/StaticPages'
import { LoginPage } from './pages/auth/LoginPage'
import { EmailOtpPage } from './pages/auth/EmailOtpPage'
import { PhoneLoginPage } from './pages/auth/PhoneLoginPage'
import { OtpPage } from './pages/auth/OtpPage'
import { OnboardingRouter, ProfileSetupPage } from './pages/auth/OnboardingPages'
import { DashboardPage, LiveTradingPage } from './pages/app/DashboardPage'
import { MarketsPage } from './pages/app/MarketsPage'
import { TradePage } from './pages/app/TradePage'
import { PortfolioPage } from './pages/app/PortfolioPage'
import { FnoHubPage } from './pages/app/FnoHubPage'
import { FnoTradePage } from './pages/app/FnoTradePage'

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<LandingPage />} />
          <Route path="/pricing" element={<PricingPage />} />
          <Route path="/privacy" element={<PrivacyPage />} />
          <Route path="/terms" element={<TermsPage />} />
          <Route path="/support" element={<SupportPage />} />

          <Route path="/login" element={<LoginPage />} />
          <Route path="/login/email-otp" element={<EmailOtpPage />} />
          <Route path="/login/phone" element={<PhoneLoginPage />} />
          <Route path="/login/otp" element={<OtpPage />} />

          <Route path="/app/onboarding" element={<OnboardingRouter />} />
          <Route path="/app/onboarding/profile" element={<ProfileSetupPage />} />
          <Route path="/app/onboarding/email" element={<Navigate to="/login" replace />} />

          <Route path="/app" element={<AppShell />}>
            <Route index element={<DashboardPage />} />
            <Route path="markets" element={<MarketsPage />} />
            <Route path="fno" element={<FnoHubPage />} />
            <Route path="fno/:symbol" element={<FnoTradePage />} />
            <Route path="portfolio" element={<PortfolioPage />} />
            <Route path="trade/:symbol" element={<TradePage />} />
            <Route path="live" element={<LiveTradingPage />} />
          </Route>

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}
