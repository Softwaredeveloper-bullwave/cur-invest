import { useCallback, useEffect, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import {
  Activity, AlertTriangle, BadgeCheck, BarChart3, Bell, CheckCircle2, Clock3, Coins, FileCheck2,
  Headphones, IndianRupee, Landmark, LayoutDashboard, LineChart, LogOut, Mail, MessageSquare,
  Package, RefreshCw, ScrollText, Send, ShieldCheck, Trash2, TrendingUp, UserX, Users, XCircle,
} from 'lucide-react'
import { api, API_BASE, clearToken, DEV_NO_AUTH, getToken, setToken } from './api'
import './App.css'

type Tab =
  | 'dashboard' | 'users' | 'kyc' | 'stocks' | 'commodities' | 'futures' | 'options'
  | 'money' | 'support' | 'announcements' | 'errors' | 'audit'
type Json = Record<string, unknown>

const NAV: { id: Tab; label: string; icon: ReactNode }[] = [
  { id: 'dashboard', label: 'Dashboard', icon: <LayoutDashboard size={18} /> },
  { id: 'users', label: 'Users', icon: <Users size={18} /> },
  { id: 'kyc', label: 'KYC', icon: <BadgeCheck size={18} /> },
  { id: 'stocks', label: 'Stocks', icon: <TrendingUp size={18} /> },
  { id: 'commodities', label: 'Commodities', icon: <Package size={18} /> },
  { id: 'futures', label: 'Futures', icon: <LineChart size={18} /> },
  { id: 'options', label: 'Options', icon: <BarChart3 size={18} /> },
  { id: 'money', label: 'Money', icon: <IndianRupee size={18} /> },
  { id: 'support', label: 'Support', icon: <Headphones size={18} /> },
  { id: 'announcements', label: 'Announcements', icon: <Send size={18} /> },
  { id: 'errors', label: 'Errors & Logs', icon: <AlertTriangle size={18} /> },
  { id: 'audit', label: 'Audit log', icon: <ScrollText size={18} /> },
]

const PATHS: Record<Tab, string> = {
  dashboard: '/dashboard/',
  users: '/users/',
  kyc: '/kyc/overview/',
  stocks: '/trading/stocks/',
  commodities: '/trading/commodities/',
  futures: '/trading/futures/',
  options: '/trading/options/',
  money: '/reports/finance/',
  support: '/support/tickets/',
  announcements: '/broadcasts/',
  errors: '/errors/?status=open',
  audit: '/audit/',
}

const money = (value: unknown) =>
  new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(Number(value || 0))
const date = (value?: string | null) => (value ? new Date(value).toLocaleString('en-IN') : '—')

function Status({ value }: { value?: string }) {
  const normalized = (value || 'unknown').toLowerCase()
  return <span className={`status status-${normalized}`}>{normalized.replaceAll('_', ' ')}</span>
}

function DocumentLinks({ row }: { row: Json }) {
  const docs = (Array.isArray(row.documents) ? row.documents : []) as Json[]
  const fallbackUrls = [
    ...(Array.isArray(row.panDocumentUrls) ? (row.panDocumentUrls as string[]) : []),
    ...(Array.isArray(row.pan_image_urls) ? (row.pan_image_urls as string[]) : []),
    ...(row.selfieUrl ? [String(row.selfieUrl)] : []),
    ...(row.document_url ? [String(row.document_url)] : []),
  ].filter(Boolean)

  const links = docs.length
    ? docs.map((doc) => ({
        key: `${doc.type}-${doc.url}`,
        label: String(doc.label || doc.type || 'Document'),
        url: String(doc.url || ''),
      }))
    : fallbackUrls.map((url, idx) => ({
        key: `${url}-${idx}`,
        label: idx === 0 && row.selfieUrl === url ? 'Selfie' : `Document ${idx + 1}`,
        url,
      }))

  if (!links.length) {
    return <small className="muted">No files uploaded</small>
  }

  return (
    <div className="doc-link-stack">
      {links.map((link) => (
        <a
          key={link.key}
          className="document-link"
          href={link.url}
          target="_blank"
          rel="noreferrer"
        >
          {link.label}
        </a>
      ))}
    </div>
  )
}

function Login({ onLogin }: { onLogin: () => void }) {
  const [phone, setPhone] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  async function submit(event: FormEvent) {
    event.preventDefault()
    setLoading(true)
    setError('')
    try {
      const result = await api<{ access: string }>('/auth/login/', {
        method: 'POST',
        body: { phone, password },
      })
      setToken(result.access)
      onLogin()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed.')
    } finally {
      setLoading(false)
    }
  }
  return (
    <main className="login-page">
      <section className="login-card">
        <div className="brand-mark"><ShieldCheck size={30} /></div>
        <p className="eyebrow">BULLWAVE CAPITAL</p>
        <h1>Admin control centre</h1>
        <p className="muted">Staff-only access. Every approval and rejection is audited.</p>
        <form onSubmit={submit}>
          <label>Admin phone<input value={phone} onChange={(e) => setPhone(e.target.value)} autoComplete="username" required /></label>
          <label>Password<input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" required /></label>
          {error && <div className="error-banner">{error}</div>}
          <button className="primary wide" disabled={loading}>{loading ? 'Signing in…' : 'Sign in securely'}</button>
        </form>
      </section>
    </main>
  )
}

function Metric({
  label, value, tone = '', tab: targetTab, onNavigate,
}: {
  label: string; value: ReactNode; tone?: string; tab?: Tab; onNavigate?: (tab: Tab) => void
}) {
  const clickable = Boolean(targetTab && onNavigate)
  const className = `metric ${tone}${clickable ? ' metric-clickable' : ''}`
  const inner = <><span>{label}</span><strong>{value}</strong></>
  if (!clickable) return <article className={className}>{inner}</article>
  return (
    <button type="button" className={className} onClick={() => onNavigate!(targetTab!)}>
      {inner}
    </button>
  )
}

function SummaryRow({ summary }: { summary: Json }) {
  if (!summary || !Object.keys(summary).length) return null
  return (
    <div className="metric-grid compact">
      {summary.totalTrades != null && <Metric label="Total trades" value={summary.totalTrades as number} />}
      {summary.buyOrders != null && <Metric label="Buy orders" value={summary.buyOrders as number} tone="positive" />}
      {summary.sellOrders != null && <Metric label="Sell orders" value={summary.sellOrders as number} tone="warning" />}
      {summary.totalPnl != null && <Metric label="Total P&L" value={money(summary.totalPnl)} tone="positive" />}
      {summary.total != null && summary.active == null && <Metric label="Total" value={summary.total as number} />}
      {summary.active != null && <Metric label="Active users" value={summary.active as number} tone="positive" />}
      {summary.blocked != null && <Metric label="Blocked" value={summary.blocked as number} tone="danger" />}
      {summary.kycPending != null && <Metric label="Pending KYC" value={summary.kycPending as number} tone="warning" />}
      {summary.panPending != null && <Metric label="PAN pending" value={summary.panPending as number} tone="warning" />}
      {summary.fnoPending != null && <Metric label="F&O pending" value={summary.fnoPending as number} tone="warning" />}
    </div>
  )
}

function RevenueChart({ chart }: { chart: Json[] }) {
  const max = Math.max(...chart.map((d) => Number(d.revenue || 0)), 1)
  return (
    <section className="panel">
      <div className="section-title"><div><h2>Revenue overview</h2><p>Paid orders — last 14 days</p></div></div>
      <div className="chart-bars">
        {chart.map((day) => (
          <div key={String(day.date)} className="chart-bar-col" title={`${day.label}: ${money(day.revenue)} (${day.orders} orders)`}>
            <div className="chart-bar" style={{ height: `${Math.max(8, (Number(day.revenue || 0) / max) * 100)}%` }} />
            <span>{String(day.label)}</span>
          </div>
        ))}
      </div>
    </section>
  )
}

function ActivityFeed({ items }: { items: Json[] }) {
  const icon = (type: string) => {
    if (type.includes('payment')) return <IndianRupee size={16} />
    if (type.includes('kyc')) return <BadgeCheck size={16} />
    if (type.includes('wallet')) return <Coins size={16} />
    return <Activity size={16} />
  }
  return (
    <section className="panel">
      <div className="section-title"><div><h2>Recent activity</h2><p>Registrations, payments, KYC, wallet top-ups</p></div></div>
      <ul className="activity-list">
        {items.map((item, idx) => (
          <li key={`${item.at}-${idx}`} className={`activity-item activity-${item.status}`}>
            <span className="activity-icon">{icon(String(item.type))}</span>
            <div>
              <strong>{String(item.title)}</strong>
              <small>{String(item.detail)}</small>
              <small className="activity-time">{date(String(item.at))}</small>
            </div>
          </li>
        ))}
        {!items.length && <li className="empty-inline">No recent activity.</li>}
      </ul>
    </section>
  )
}

function Dashboard({ data, onNavigate }: { data: Json; onNavigate: (tab: Tab) => void }) {
  const users = (data.users || {}) as Json
  const reviews = (data.reviews || {}) as Json
  const moneyData = (data.money || {}) as Json
  return (
    <>
      <div className="metric-grid">
        <Metric label="Total users" value={Number(users.total ?? 0)} tab="users" onNavigate={onNavigate} />
        <Metric label="Active users" value={Number(users.active ?? 0)} tone="positive" tab="users" onNavigate={onNavigate} />
        <Metric label="Blocked users" value={Number(users.blocked ?? 0)} tone="danger" tab="users" onNavigate={onNavigate} />
        <Metric label="Pending KYC" value={Number(users.kycPending ?? 0)} tone="warning" tab="kyc" onNavigate={onNavigate} />
        <Metric label="Verified KYC" value={Number(users.kycVerified ?? 0)} tone="positive" tab="kyc" onNavigate={onNavigate} />
        <Metric label="Bank reviews" value={Number(reviews.bankPending ?? 0)} tone="warning" tab="kyc" onNavigate={onNavigate} />
        <Metric label="F&O reviews" value={Number(reviews.fnoPending ?? 0)} tone="warning" tab="kyc" onNavigate={onNavigate} />
        <Metric label="Revenue (paid)" value={money(moneyData.paidTotal)} tone="positive" tab="money" onNavigate={onNavigate} />
        <Metric label="Open support" value={Number((data.support as Json)?.openTickets ?? 0)} tone="warning" tab="support" onNavigate={onNavigate} />
      </div>
      <div className="dashboard-grid">
        <RevenueChart chart={(data.revenueChart as Json[]) || []} />
        <section className="panel">
          <div className="section-title"><div><h2>Recent users</h2><p>Latest registrations</p></div></div>
          <div className="table-wrap compact">
            <table>
              <thead><tr><th>User</th><th>Email</th><th>Status</th><th>KYC</th><th>Joined</th></tr></thead>
              <tbody>
                {((data.recentUsers as Json[]) || []).map((row) => (
                  <tr key={String(row.id)}>
                    <td><strong>{String(row.name || 'Unnamed')}</strong><small>{String(row.phone)}</small></td>
                    <td>{String(row.email || '—')}</td>
                    <td><Status value={row.isActive ? 'active' : 'blocked'} /></td>
                    <td><Status value={String(row.kycStatus)} /></td>
                    <td>{date(String(row.dateJoined))}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </div>
      <ActivityFeed items={(data.recentActivity as Json[]) || []} />
      <button type="button" className="info-panel info-panel-clickable" onClick={() => onNavigate('kyc')}>
        <Clock3 size={22} />
        <div>
          <strong>24-hour manual bank + UPI review SLA</strong>
          <p>Users submit bank account and UPI ID together. Staff approves or rejects both within 24 hours.</p>
          <span className="info-panel-link">Open KYC reviews →</span>
        </div>
      </button>
    </>
  )
}

function Empty({ text }: { text: string }) {
  return <div className="empty"><CheckCircle2 size={30} /><strong>{text}</strong></div>
}

function UserModal({
  userId, onClose, onUpdated,
}: { userId: string; onClose: () => void; onUpdated: () => void }) {
  const [user, setUser] = useState<Json | null>(null)
  const [edit, setEdit] = useState(false)
  const [form, setForm] = useState({ name: '', email: '', city: '' })
  const [error, setError] = useState('')

  const loadUser = useCallback(async (silent = false) => {
    try {
      const row = await api<Json>(`/users/${userId}/`)
      setUser(row)
      if (!silent) {
        setForm({ name: String(row.name || ''), email: String(row.email || ''), city: String(row.city || '') })
      }
      setError('')
    } catch (err) {
      if (!silent) setError(err instanceof Error ? err.message : 'Load failed')
    }
  }, [userId])

  useEffect(() => {
    loadUser()
    const timer = window.setInterval(() => { loadUser(true).catch(() => {}) }, 5000)
    return () => window.clearInterval(timer)
  }, [loadUser])

  async function save() {
    try {
      const updated = await api<Json>(`/users/${userId}/`, { method: 'PATCH', body: form })
      setUser(updated)
      setEdit(false)
      onUpdated()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Save failed')
    }
  }

  async function blockToggle() {
    const action = user?.isActive ? 'block' : 'unblock'
    if (!window.confirm(`${action} this user?`)) return
    await api(`/users/${userId}/${action}/`, { method: 'POST', body: {} })
    onUpdated()
    onClose()
  }

  async function remove() {
    if (!window.confirm('Permanently delete this user? This cannot be undone.')) return
    await api(`/users/${userId}/delete/`, { method: 'DELETE' })
    onUpdated()
    onClose()
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <header><h2>User details</h2><button type="button" className="modal-close" onClick={onClose}>×</button></header>
        {error && <div className="error-banner">{error}</div>}
        {!user ? <div className="loading">Loading…</div> : (
          <>
            {edit ? (
              <div className="modal-form">
                <label>Name<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
                <label>Email<input value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></label>
                <label>City<input value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} /></label>
                <div className="actions"><button className="approve" onClick={save}>Save</button><button onClick={() => setEdit(false)}>Cancel</button></div>
              </div>
            ) : (
              <dl className="detail-grid">
                <dt>Phone</dt><dd className="mono">{String(user.phone)}</dd>
                <dt>Name</dt><dd>{String(user.name || '—')}</dd>
                <dt>Email</dt><dd>{String(user.email || '—')}</dd>
                <dt>Status</dt><dd><Status value={user.isActive ? 'active' : 'blocked'} /></dd>
                <dt>KYC</dt><dd><Status value={String(user.kycStatus)} /></dd>
                <dt>Overall</dt><dd><Status value={String(user.overallKycStatus || user.kycStatus)} /></dd>
                <dt>PAN</dt><dd><Status value={String(user.panStatus)} /></dd>
                <dt>Aadhaar</dt><dd><Status value={String(user.aadhaarStatus || '—')} /></dd>
                <dt>Selfie</dt><dd><Status value={String(user.selfieStatus || '—')} /></dd>
                <dt>Bank</dt><dd><Status value={String(user.bankStatus || '—')} /></dd>
                <dt>UPI</dt><dd>{String(user.upiVpa || '—')} <Status value={String(user.upiStatus || '—')} /></dd>
                <dt>Wallet</dt><dd className="money">{money(user.walletBalance)}</dd>
                <dt>Joined</dt><dd>{date(String(user.dateJoined))}</dd>
              </dl>
            )}
            {!edit && !user.isStaff && (
              <div className="actions modal-actions">
                <button onClick={() => setEdit(true)}>Edit user</button>
                <button className={user.isActive ? 'reject' : 'approve'} onClick={blockToggle}>
                  <UserX size={15} /> {user.isActive ? 'Block user' : 'Unblock user'}
                </button>
                <button className="reject" onClick={remove}><Trash2 size={15} /> Delete</button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}

function UsersPage({ data, reload }: { data: Json; reload: () => void }) {
  const [selected, setSelected] = useState<string | null>(null)
  const rows = (data.results as Json[]) || []
  const summary = (data.summary as Json) || {}
  return (
    <>
      <SummaryRow summary={summary} />
      <div className="table-wrap">
        <table>
          <thead><tr><th>User</th><th>Email</th><th>Phone</th><th>Status</th><th>KYC</th><th>PAN</th><th>Wallet</th><th>Joined</th><th>Actions</th></tr></thead>
          <tbody>
            {rows.map((row) => (
              <tr key={String(row.id)}>
                <td><strong>{String(row.name || 'Unnamed')}</strong></td>
                <td>{String(row.email || '—')}</td>
                <td className="mono">{String(row.phone)}</td>
                <td><Status value={row.isActive ? 'active' : 'blocked'} /></td>
                <td><Status value={String(row.kycStatus)} /></td>
                <td><Status value={String(row.panStatus)} /></td>
                <td className="money">{money(row.walletBalance)}</td>
                <td>{date(String(row.dateJoined))}</td>
                <td><button className="link-btn" onClick={() => setSelected(String(row.id))}>View details</button></td>
              </tr>
            ))}
          </tbody>
        </table>
        {!rows.length && <Empty text="No users found." />}
      </div>
      {selected && <UserModal userId={selected} onClose={() => setSelected(null)} onUpdated={reload} />}
    </>
  )
}

function KycPage({ data, reload }: { data: Json; reload: (opts?: { silent?: boolean }) => Promise<void> }) {
  const summary = (data.summary as Json) || {}
  const panRows = (data.panRequests as Json[]) || []
  const bankRows = (data.bankRequests as Json[]) || []
  const identityRows = (data.identityReviews as Json[]) || []
  const selfieRows = (data.selfieRequests as Json[]) || []
  const fnoRows = (data.fnoRequests as Json[]) || []
  const profiles = (data.profiles as Json[]) || []
  const [actionError, setActionError] = useState('')

  async function runAction(action: () => Promise<void>) {
    setActionError('')
    try {
      await action()
    } catch (err) {
      setActionError(err instanceof Error ? err.message : 'Action failed.')
    }
  }

  async function panDecide(id: string, decision: 'approve' | 'reject') {
    const reason = decision === 'reject' ? window.prompt('Rejection reason') : ''
    if (decision === 'reject' && (!reason || reason.trim().length < 3)) return
    await runAction(async () => {
      await api(`/kyc/pan/${id}/${decision}/`, { method: 'POST', body: { reason } })
      await reload({ silent: true })
    })
  }

  async function bankDecide(id: string, decision: 'approve' | 'reject') {
    const note = window.prompt(decision === 'approve' ? 'Optional note' : 'Rejection reason', '')
    if (note === null || (decision === 'reject' && note.trim().length < 3)) return
    await runAction(async () => {
      await api(`/kyc/bank/${id}/${decision}/`, {
        method: 'POST', body: decision === 'approve' ? { note } : { reason: note },
      })
      await reload({ silent: true })
    })
  }

  async function fnoDecide(id: string, decision: 'approve' | 'reject') {
    const reason = decision === 'reject' ? window.prompt('Rejection reason') : ''
    if (decision === 'reject' && (!reason || reason.trim().length < 3)) return
    await runAction(async () => {
      await api(`/kyc/fno/${id}/${decision}/`, {
        method: 'POST',
        body: decision === 'reject' ? { reason } : {},
      })
      await reload({ silent: true })
    })
  }

  async function aadhaar(userId: string, decision: 'approve' | 'reject') {
    const reason = window.prompt(decision === 'approve' ? 'Optional note' : 'Rejection reason') ?? ''
    if (decision === 'reject' && reason.trim().length < 3) return
    await runAction(async () => {
      await api(`/kyc/aadhaar/${userId}/${decision}/`, { method: 'POST', body: { reason } })
      await reload({ silent: true })
    })
  }

  async function finalKycApprove(userId: string) {
    const note = window.prompt('Optional note for final KYC approval', '') ?? ''
    await runAction(async () => {
      await api(`/kyc/final/${userId}/approve/`, { method: 'POST', body: { note } })
      await reload({ silent: true })
    })
  }

  async function upiApprove(userId: string) {
    const note = window.prompt('Optional note for UPI approval', '') ?? ''
    await runAction(async () => {
      await api(`/kyc/upi/${userId}/approve/`, { method: 'POST', body: { note } })
      await reload({ silent: true })
    })
  }

  async function upiReject(userId: string) {
    const reason = window.prompt('Reason for rejecting this UPI ID', '') ?? ''
    if (reason.trim().length < 3) return
    await runAction(async () => {
      await api(`/kyc/upi/${userId}/reject/`, { method: 'POST', body: { reason } })
      await reload({ silent: true })
    })
  }

  async function bankApprove(userId: string) {
    await runAction(async () => {
      await api(`/kyc/bank-profile/${userId}/approve/`, { method: 'POST', body: { note: '' } })
      await reload({ silent: true })
    })
  }

  function hasUpiOnFile(row: Json) {
    return Boolean(String(row.upiVpa || row.upiVpaMasked || '').trim())
  }

  function upiPending(row: Json) {
    return String(row.upiStatus || '').toLowerCase() === 'pending' && hasUpiOnFile(row)
  }

  function bankPending(row: Json) {
    if (String(row.bankStatus || '').toLowerCase() !== 'pending') return false
    if (row.bankPendingAdminReview === true) return true
    const acct = String(row.accountNumber || '').trim()
    return acct.length > 0 && acct !== '—'
  }

  function canCompleteKyc(row: Json) {
    if (row.readyForFinalApproval === true) return true
    const verified = (value: unknown) => String(value || '').toLowerCase() === 'verified'
    return (
      verified(row.panStatus) &&
      verified(row.aadhaarStatus) &&
      verified(row.upiStatus) &&
      String(row.selfieStatus || '').toLowerCase() === 'verified' &&
      bankPending(row)
    )
  }

  async function selfieDecide(userId: string, decision: 'approve' | 'reject') {
    const note = window.prompt(decision === 'approve' ? 'Optional note' : 'Rejection reason', '')
    if (note === null || (decision === 'reject' && note.trim().length < 3)) return
    await runAction(async () => {
      await api(`/kyc/selfie/${userId}/${decision}/`, {
        method: 'POST', body: decision === 'approve' ? { note } : { reason: note },
      })
      await reload({ silent: true })
    })
  }

  return (
    <>
      {actionError && <div className="error-banner">{actionError}</div>}
      <SummaryRow summary={{
        ...summary,
        total: Number(summary.panPending || 0) + Number(summary.panApproved || 0) + Number(summary.panRejected || 0),
      }} />
      <div className="metric-grid compact">
        <Metric label="PAN pending" value={Number(summary.panPending ?? 0)} tone="warning" />
        <Metric label="PAN approved" value={Number(summary.panApproved ?? 0)} tone="positive" />
        <Metric label="PAN rejected" value={Number(summary.panRejected ?? 0)} tone="danger" />
        <Metric label="Bank pending" value={Number(summary.bankPending ?? 0)} tone="warning" />
        <Metric label="Bank approved" value={Number(summary.bankApproved ?? 0)} tone="positive" />
        <Metric label="Bank rejected" value={Number(summary.bankRejected ?? 0)} tone="danger" />
        <Metric label="Selfie pending" value={Number(summary.selfiePending ?? 0)} tone="warning" />
        <Metric label="Selfie verified" value={Number(summary.selfieVerified ?? 0)} tone="positive" />
        <Metric label="Selfie rejected" value={Number(summary.selfieRejected ?? 0)} tone="danger" />
        <Metric label="F&O pending" value={Number(summary.fnoPending ?? 0)} tone="warning" />
        <Metric label="F&O approved" value={Number(summary.fnoApproved ?? 0)} tone="positive" />
        <Metric label="F&O rejected" value={Number(summary.fnoRejected ?? 0)} tone="danger" />
      </div>

      <div className="section-title compact"><h2><LineChart size={18} /> F&O document reviews</h2></div>
      <p className="muted" style={{ margin: '0 0 16px' }}>
        Users upload bank statements, Form 16, or ITR for F&amp;O access. Review each document and approve or reject manually.
      </p>
      <div className="review-grid">
        {fnoRows.map((row) => (
          <article className="review-card" key={String(row.id)}>
            <div className="review-head">
              <div>
                <strong>{String(row.user_name || (row.user as Json)?.name || 'Unnamed')}</strong>
                <small>{String(row.user_phone || (row.user as Json)?.phone)}</small>
              </div>
              <Status value={String(row.status)} />
            </div>
            <dl>
              <dt>Proof type</dt><dd>{String(row.proof_label || row.proof_type)}</dd>
              <dt>Portfolio value</dt><dd>{money(row.portfolio_value)}</dd>
              <dt>Submitted</dt><dd>{date(String(row.created_at))}</dd>
              {row.reviewed_at ? <><dt>Reviewed</dt><dd>{date(String(row.reviewed_at))}</dd></> : null}
              {row.rejection_reason ? <><dt>Reason</dt><dd>{String(row.rejection_reason)}</dd></> : null}
            </dl>
            {row.document_url ? (
              <a className="document-link" href={String(row.document_url)} target="_blank" rel="noreferrer">
                Open uploaded document
              </a>
            ) : (
              <small className="muted">No document file attached.</small>
            )}
            {row.status === 'PENDING' && (
              <div className="actions">
                <button className="approve" onClick={() => fnoDecide(String(row.id), 'approve')}><CheckCircle2 size={15} /> Approve F&O</button>
                <button className="reject" onClick={() => fnoDecide(String(row.id), 'reject')}><XCircle size={15} /> Reject</button>
              </div>
            )}
          </article>
        ))}
        {!fnoRows.length && <Empty text="No F&O document reviews pending." />}
      </div>

      <div className="section-title compact"><h2><FileCheck2 size={18} /> PAN requests</h2></div>
      <div className="review-grid">
        {panRows.map((row) => (
          <article className="review-card" key={String(row.id)}>
            <div className="review-head">
              <div><strong>{String(row.full_name || row.fullName)}</strong><small>{String((row.user as Json)?.phone)}</small></div>
              <Status value={String(row.status)} />
            </div>
            <dl><dt>PAN</dt><dd className="mono">{String(row.pan_number || row.panNumber)}</dd>
              <dt>DOB</dt><dd>{String(row.dob)}</dd><dt>Submitted</dt><dd>{date(String(row.created_at || row.createdAt))}</dd></dl>
            <DocumentLinks row={row} />
            {row.status === 'PENDING' && (
              <div className="actions">
                <button className="approve" onClick={() => panDecide(String(row.id), 'approve')}><CheckCircle2 size={15} /> Approve</button>
                <button className="reject" onClick={() => panDecide(String(row.id), 'reject')}><XCircle size={15} /> Reject</button>
              </div>
            )}
          </article>
        ))}
        {!panRows.length && <Empty text="No PAN requests." />}
      </div>

      <div className="section-title compact"><h2><Landmark size={18} /> Bank & UPI reviews</h2></div>
      <div className="table-wrap">
        <table>
          <thead><tr><th>User</th><th>Account</th><th>IFSC</th><th>UPI</th><th>Submitted / due</th><th>Status</th><th>Action</th></tr></thead>
          <tbody>
            {bankRows.map((row) => (
              <tr key={String(row.id)}>
                <td><strong>{String(row.userName || 'Unnamed')}</strong><small>{String(row.userPhone)}</small></td>
                <td className="mono">{String(row.accountNumber)}</td>
                <td className="mono">{String(row.ifsc)}</td>
                <td className="mono">{String(row.upiVpa || row.upiVpaMasked || '—')}</td>
                <td><small>{date(String(row.submittedAt))}</small><small>Due {date(String(row.reviewDueAt))}</small></td>
                <td><Status value={String(row.status)} /></td>
                <td>{row.status === 'pending' ? (
                  <div className="actions">
                    <button className="approve" onClick={() => bankDecide(String(row.id), 'approve')}><CheckCircle2 size={15} /> Approve</button>
                    <button className="reject" onClick={() => bankDecide(String(row.id), 'reject')}><XCircle size={15} /> Reject</button>
                  </div>
                ) : <small>{String(row.reviewNote || 'Reviewed')}</small>}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!bankRows.length && <Empty text="No bank + UPI reviews." />}
      </div>

      <div className="section-title compact"><h2><FileCheck2 size={18} /> UPI + Selfie identity reviews</h2></div>
      <div className="review-grid">
        {identityRows.map((row) => (
          <article className="review-card" key={String(row.userId)}>
            <div className="review-head">
              <div><strong>{String(row.userName || 'Unnamed')}</strong><small>{String(row.userPhone)}</small></div>
              <Status value={String(row.overallStatus || 'pending')} />
            </div>
            <dl>
              <dt>Bank</dt>
              <dd className="mono">
                {row.ifsc ? `•••• ${String(row.accountNumber || '—')} / ${String(row.ifsc)}` : '—'}
                <Status value={String(row.bankStatus || 'pending')} />
              </dd>
              <dt>UPI ID</dt>
              <dd className="mono">
                {String(row.upiVpa || row.upiVpaMasked || '—')}
                <Status value={String(row.upiStatus)} />
              </dd>
              <dt>Selfie</dt><dd><Status value={String(row.selfieStatus)} /></dd>
            </dl>
            {row.selfieUrl ? (
              <a className="document-link" href={String(row.selfieUrl)} target="_blank" rel="noreferrer">Open selfie</a>
            ) : null}
            <DocumentLinks row={row} />
            <div className="actions">
              {bankPending(row) ? (
                <button className="approve" onClick={() => bankApprove(String(row.userId))}><CheckCircle2 size={15} /> Approve bank</button>
              ) : null}
              {upiPending(row) ? (
                <>
                  <button className="approve" onClick={() => upiApprove(String(row.userId))}><CheckCircle2 size={15} /> Approve UPI</button>
                  <button className="reject" onClick={() => upiReject(String(row.userId))}><XCircle size={15} /> Reject UPI</button>
                </>
              ) : null}
              {row.selfieStatus === 'completed' ? (
                <>
                  <button className="approve" onClick={() => selfieDecide(String(row.userId), 'approve')}><CheckCircle2 size={15} /> Approve selfie</button>
                  <button className="reject" onClick={() => selfieDecide(String(row.userId), 'reject')}><XCircle size={15} /> Reject selfie</button>
                </>
              ) : null}
              {canCompleteKyc(row) ? (
                <button className="approve" onClick={() => finalKycApprove(String(row.userId))}><CheckCircle2 size={15} /> Complete KYC</button>
              ) : null}
            </div>
          </article>
        ))}
        {!identityRows.length && <Empty text="No UPI + selfie reviews pending." />}
      </div>

      <div className="section-title compact"><h2><FileCheck2 size={18} /> Selfie reviews (legacy)</h2></div>
      <div className="review-grid">
        {selfieRows.map((row) => (
          <article className="review-card" key={String(row.userId)}>
            <div className="review-head">
              <div><strong>{String(row.userName || 'Unnamed')}</strong><small>{String(row.userPhone)}</small></div>
              <Status value={String(row.selfieStatus)} />
            </div>
            <dl>
              <dt>Uploaded</dt><dd>{date(String(row.uploadedAt))}</dd>
              <dt>Review due</dt><dd>{date(String(row.reviewDueAt))}</dd>
              <dt>PAN name</dt><dd>{String(row.panName || '—')}</dd>
            </dl>
            {row.selfieUrl ? (
              <a className="document-link" href={String(row.selfieUrl)} target="_blank" rel="noreferrer">Open selfie</a>
            ) : null}
            <DocumentLinks row={row} />
            {row.selfieStatus === 'completed' && (
              <div className="actions">
                <button className="approve" onClick={() => selfieDecide(String(row.userId), 'approve')}><CheckCircle2 size={15} /> Approve</button>
                <button className="reject" onClick={() => selfieDecide(String(row.userId), 'reject')}><XCircle size={15} /> Reject</button>
              </div>
            )}
            {row.selfieStatus === 'rejected' && row.reviewNote ? (
              <small>{String(row.reviewNote)}</small>
            ) : null}
          </article>
        ))}
        {!selfieRows.length && <Empty text="No selfie reviews." />}
      </div>

      <div className="section-title compact"><h2>All KYC profiles</h2></div>
      <div className="table-wrap">
        <table>
          <thead><tr><th>User</th><th>PAN</th><th>Aadhaar</th><th>Bank</th><th>Selfie</th><th>UPI</th><th>Overall</th><th>Documents</th><th>Actions</th></tr></thead>
          <tbody>
            {profiles.map((row) => (
              <tr key={String(row.userId)}>
                <td><strong>{String(row.name || 'Unnamed')}</strong><small>{String(row.phone)}</small></td>
                <td><span className="mono">{String(row.panNumber || '—')}</span><Status value={String(row.panStatus)} /></td>
                <td><span>•••• {String(row.aadhaarLast4 || '—')}</span><Status value={String(row.aadhaarStatus)} /></td>
                <td><span className="mono">{String(row.accountNumber || '—')}</span><Status value={String(row.bankStatus)} /></td>
                <td><Status value={String(row.selfieStatus || 'pending')} /></td>
                <td><span className="mono">{String(row.upiVpa || '—')}</span><Status value={String(row.upiStatus)} /></td>
                <td><Status value={String(row.overallStatus)} /></td>
                <td><DocumentLinks row={row} /></td>
                <td><div className="actions">
                  {bankPending(row) ? (
                    <button className="approve" onClick={() => bankApprove(String(row.userId))}><CheckCircle2 size={15} /> Approve bank</button>
                  ) : null}
                  {upiPending(row) ? (
                    <>
                      <button className="approve" onClick={() => upiApprove(String(row.userId))}><CheckCircle2 size={15} /> Approve UPI</button>
                      <button className="reject" onClick={() => upiReject(String(row.userId))}><XCircle size={15} /> Reject UPI</button>
                    </>
                  ) : null}
                  {canCompleteKyc(row) ? (
                    <button className="approve" onClick={() => finalKycApprove(String(row.userId))}><CheckCircle2 size={15} /> Complete KYC</button>
                  ) : null}
                  <button className="icon-action approve" title="Approve Aadhaar" onClick={() => aadhaar(String(row.userId), 'approve')}><CheckCircle2 size={15} /></button>
                  <button className="icon-action reject" title="Reject Aadhaar" onClick={() => aadhaar(String(row.userId), 'reject')}><XCircle size={15} /></button>
                </div></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}

function TradingPage({ data, segment }: { data: Json; segment: string }) {
  const rows = (data.results as Json[]) || []
  const summary = (data.summary as Json) || {}
  const isStock = segment === 'stocks'
  const isCommodity = segment === 'commodities'
  const isOption = segment === 'futures' || segment === 'options'

  return (
    <>
      <SummaryRow summary={summary} />
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>User</th>
              {isStock && <><th>Symbol</th><th>Exchange</th></>}
              {isCommodity && <><th>Contract</th><th>Exchange</th></>}
              {isOption && <><th>Contract</th><th>Exchange</th><th>Type</th><th>Strike</th><th>Expiry</th></>}
              <th>Side</th>
              <th>{isCommodity || isOption ? 'Lots' : 'Qty'}</th>
              <th>Buy price</th>
              <th>Sell price</th>
              <th>Buy time</th>
              <th>Sell time</th>
              <th>Status</th>
              <th>P&L</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={String(row.id)}>
                <td><strong>{String(row.userName || 'Unnamed')}</strong><small>{String(row.userPhone)}</small></td>
                {isStock && <><td className="mono">{String(row.symbol)}</td><td>{String(row.exchange)}</td></>}
                {isCommodity && <><td className="mono">{String(row.contract || row.commodity)}</td><td>{String(row.exchange)}</td></>}
                {isOption && (
                  <>
                    <td className="mono">{String(row.contract)}</td>
                    <td>{String(row.exchange)}</td>
                    <td>{String(row.optionType)}</td>
                    <td>{String(row.strike)}</td>
                    <td>{date(String(row.expiry)).split(',')[0]}</td>
                  </>
                )}
                <td><Status value={String(row.type)} /></td>
                <td>{String(row.lots ?? row.quantity ?? '—')}</td>
                <td className="money">{row.buyPrice ? money(row.buyPrice) : '—'}</td>
                <td className="money">{row.sellPrice ? money(row.sellPrice) : '—'}</td>
                <td>{row.buyTime ? date(String(row.buyTime)) : '—'}</td>
                <td>{row.sellTime ? date(String(row.sellTime)) : '—'}</td>
                <td><Status value={String(row.status)} /></td>
                <td className="money">{row.pnl ? money(row.pnl) : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!rows.length && <Empty text={`No ${segment} trades yet.`} />}
      </div>
    </>
  )
}

function ErrorDetailModal({
  errorId, onClose, onChanged, onOpenUser,
}: {
  errorId: string
  onClose: () => void
  onChanged: () => void
  onOpenUser: (userId: string) => void
}) {
  const [row, setRow] = useState<Json | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    api<Json>(`/errors/${errorId}/`).then(setRow).catch((err) => {
      setError(err instanceof Error ? err.message : 'Could not load error details.')
    })
  }, [errorId])

  async function changeStatus(action: 'resolve' | 'reopen') {
    try {
      await api(`/errors/${errorId}/${action}/`, { method: 'POST', body: {} })
      onChanged()
      onClose()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not update error.')
    }
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal error-modal" onClick={(event) => event.stopPropagation()}>
        <header><h2>Error details</h2><button type="button" className="modal-close" onClick={onClose}>×</button></header>
        {error && <div className="error-banner">{error}</div>}
        {!row ? <div className="loading">Loading…</div> : (
          <>
            <dl className="detail-grid">
              <dt>Source</dt><dd><Status value={String(row.source)} /></dd>
              <dt>Severity</dt><dd><Status value={String(row.severity)} /></dd>
              <dt>Status</dt><dd><Status value={String(row.status)} /></dd>
              <dt>Exception</dt><dd>{String(row.exceptionType || '—')}</dd>
              <dt>Message</dt><dd>{String(row.message)}</dd>
              <dt>Location</dt><dd className="mono">{String(row.location || '—')}</dd>
              <dt>User</dt><dd>{String(row.userPhone || 'Anonymous')} {Boolean(row.userId) && (
                <button className="link-btn inline-link" onClick={() => onOpenUser(String(row.userId))}>View user</button>
              )}</dd>
              <dt>Occurrences</dt><dd>{String(row.occurrenceCount)}</dd>
              <dt>First seen</dt><dd>{date(String(row.firstSeenAt))}</dd>
              <dt>Last seen</dt><dd>{date(String(row.lastSeenAt))}</dd>
            </dl>
            <div className="context-block">
              <strong>Sanitized context</strong>
              <pre>{JSON.stringify(row.context || {}, null, 2)}</pre>
            </div>
            <div className="actions modal-actions">
              {row.status === 'resolved' ? (
                <button className="approve" onClick={() => changeStatus('reopen')}>Reopen</button>
              ) : (
                <button className="approve" onClick={() => changeStatus('resolve')}>Mark resolved</button>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  )
}

function ErrorsPage({ data, reload }: { data: Json; reload: () => void }) {
  const [view, setView] = useState<Json>(data)
  const [selected, setSelected] = useState<string | null>(null)
  const [selectedUser, setSelectedUser] = useState<string | null>(null)
  const [checked, setChecked] = useState<string[]>([])
  const [filters, setFilters] = useState({
    source: '', severity: '', status: 'open', since: '', search: '',
  })
  const [filterError, setFilterError] = useState('')

  useEffect(() => { setView(data) }, [data])

  async function applyFilters() {
    const query = new URLSearchParams()
    Object.entries(filters).forEach(([key, value]) => { if (value) query.set(key, value) })
    try {
      setFilterError('')
      setView(await api<Json>(`/errors/?${query.toString()}`))
      setChecked([])
    } catch (err) {
      setFilterError(err instanceof Error ? err.message : 'Could not filter errors.')
    }
  }

  async function deleteResolved() {
    if (!checked.length || !window.confirm('Delete the selected resolved errors?')) return
    try {
      await api('/errors/bulk-delete/', { method: 'POST', body: { ids: checked } })
      setChecked([])
      await applyFilters()
    } catch (err) {
      setFilterError(err instanceof Error ? err.message : 'Could not delete errors.')
    }
  }

  const summary = (view.summary as Json) || {}
  const rows = (view.results as Json[]) || []
  const failureRows: Json[] = [
    ...(((view.kycFailures as Json[]) || []).map((row) => ({ ...row, kind: 'KYC' }))),
    ...(((view.paymentFailures as Json[]) || []).map((row) => ({ ...row, kind: 'Payment' }))),
    ...(((view.payoutFailures as Json[]) || []).map((row) => ({ ...row, kind: 'Payout' }))),
  ]

  return (
    <>
      <div className="metric-grid compact">
        <Metric label="Open errors" value={Number(summary.open || 0)} tone="danger" />
        <Metric label="Critical" value={Number(summary.critical || 0)} tone="danger" />
        <Metric label="Last 24 hours" value={Number(summary.last24Hours || 0)} tone="warning" />
        <Metric label="Last 7 days" value={Number(summary.last7Days || 0)} />
        <Metric label="Failed KYC" value={Number(summary.failedKyc || 0)} tone="warning" />
        <Metric label="Failed payments" value={Number(summary.failedPayments || 0)} tone="warning" />
        <Metric label="Failed payouts" value={Number(summary.failedPayouts || 0)} tone="warning" />
      </div>

      <section className="panel filter-panel">
        <div className="filter-grid">
          <label>Source<select value={filters.source} onChange={(e) => setFilters({ ...filters, source: e.target.value })}>
            <option value="">All</option><option value="backend">Backend</option><option value="flutter">Flutter</option>
          </select></label>
          <label>Severity<select value={filters.severity} onChange={(e) => setFilters({ ...filters, severity: e.target.value })}>
            <option value="">All</option><option value="warning">Warning</option><option value="error">Error</option><option value="critical">Critical</option>
          </select></label>
          <label>Status<select value={filters.status} onChange={(e) => setFilters({ ...filters, status: e.target.value })}>
            <option value="">All</option><option value="open">Open</option><option value="resolved">Resolved</option>
          </select></label>
          <label>Since<input type="date" value={filters.since} onChange={(e) => setFilters({ ...filters, since: e.target.value })} /></label>
          <label className="filter-search">Search<input placeholder="Message, user, location…" value={filters.search} onChange={(e) => setFilters({ ...filters, search: e.target.value })} /></label>
          <button className="primary" onClick={applyFilters}>Apply filters</button>
        </div>
        {filterError && <div className="error-banner">{filterError}</div>}
      </section>

      <div className="section-title compact"><div><h2>Application errors</h2><p>Sanitized and grouped by fingerprint. Repeated errors increase the occurrence count.</p></div></div>
      <div className="bulk-actions">
        <span>{checked.length} selected</span>
        <button className="reject" disabled={!checked.length} onClick={deleteResolved}><Trash2 size={15} /> Delete resolved</button>
      </div>
      <div className="table-wrap">
        <table>
          <thead><tr><th></th><th>Last seen</th><th>Source</th><th>Severity</th><th>Error</th><th>Location / user</th><th>Count</th><th>Status</th><th>Action</th></tr></thead>
          <tbody>
            {rows.map((row) => (
              <tr key={String(row.id)}>
                <td><input type="checkbox" disabled={row.status !== 'resolved'} checked={checked.includes(String(row.id))} onChange={(e) => {
                  const id = String(row.id)
                  setChecked(e.target.checked ? [...checked, id] : checked.filter((value) => value !== id))
                }} /></td>
                <td>{date(String(row.lastSeenAt))}</td>
                <td><Status value={String(row.source)} /></td>
                <td><Status value={String(row.severity)} /></td>
                <td><strong>{String(row.exceptionType || row.loggerName || 'Application error')}</strong><small>{String(row.message)}</small></td>
                <td><span className="mono">{String(row.location || '—')}</span><small>{String(row.userPhone || 'Anonymous')}</small></td>
                <td>{String(row.occurrenceCount)}</td>
                <td><Status value={String(row.status)} /></td>
                <td><button className="link-btn" onClick={() => setSelected(String(row.id))}>View details</button></td>
              </tr>
            ))}
          </tbody>
        </table>
        {!rows.length && <Empty text="No application errors match these filters." />}
      </div>

      <div className="section-title compact"><div><h2>Business and provider failures</h2><p>Existing KYC, payment, and payout failures.</p></div></div>
      <div className="table-wrap">
        <table>
          <thead><tr><th>Time</th><th>Type</th><th>User</th><th>Step / gateway</th><th>Message</th><th>Amount</th></tr></thead>
          <tbody>
            {failureRows.map((row, index) => (
              <tr key={`${row.kind}-${row.id}-${index}`}>
                <td>{date(String(row.createdAt))}</td>
                <td><Status value={String(row.kind)} /></td>
                <td>{String(row.userPhone || '—')}</td>
                <td>{String(row.step || row.gateway || '—')}</td>
                <td>{String(row.message || '—')}</td>
                <td className="money">{row.amount ? money(row.amount) : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!failureRows.length && <Empty text="No KYC, payment, or payout failures." />}
      </div>
      {selected && <ErrorDetailModal
        errorId={selected}
        onClose={() => setSelected(null)}
        onChanged={() => { reload(); applyFilters() }}
        onOpenUser={(userId) => { setSelected(null); setSelectedUser(userId) }}
      />}
      {selectedUser && <UserModal userId={selectedUser} onClose={() => setSelectedUser(null)} onUpdated={reload} />}
    </>
  )
}

function MoneyReports({ data }: { data: Json }) {
  return (
    <>
      <div className="section-title"><div><h2>Wallet balances</h2><p>Read-only reporting.</p></div></div>
      <div className="table-wrap">
        <table>
          <thead><tr><th>User</th><th>Balance</th><th>Updated</th></tr></thead>
          <tbody>
            {((data.wallets as Json[]) || []).map((row) => (
              <tr key={String(row.userId)}>
                <td><strong>{String(row.name || 'Unnamed')}</strong><small>{String(row.phone)}</small></td>
                <td className="money">{money(row.balance)}</td>
                <td>{date(String(row.updatedAt))}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="section-title compact"><h2>Payment orders</h2></div>
      <div className="table-wrap">
        <table>
          <thead><tr><th>User</th><th>Order</th><th>Gateway</th><th>Amount</th><th>Status</th><th>Date</th></tr></thead>
          <tbody>
            {((data.payments as Json[]) || []).map((row) => (
              <tr key={String(row.id)}>
                <td>{String(row.phone)}</td>
                <td className="mono">{String(row.orderId)}</td>
                <td>{String(row.gateway)}</td>
                <td className="money">{money(row.amount)}</td>
                <td><Status value={String(row.status)} /></td>
                <td>{date(String(row.createdAt))}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="section-title compact"><h2>Payout records</h2></div>
      <div className="table-wrap">
        <table>
          <thead><tr><th>User</th><th>Transfer</th><th>Amount</th><th>Status</th><th>Failure</th><th>Date</th></tr></thead>
          <tbody>
            {((data.payouts as Json[]) || []).map((row) => (
              <tr key={String(row.id)}>
                <td>{String(row.phone)}</td>
                <td className="mono">{String(row.transferId || '—')}</td>
                <td className="money">{money(row.amount)}</td>
                <td><Status value={String(row.status)} /></td>
                <td>{String(row.failureReason || '—')}</td>
                <td>{date(String(row.createdAt))}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}

function SupportTicketModal({
  ticketId, onClose, onUpdated,
}: { ticketId: string; onClose: () => void; onUpdated: () => void }) {
  const [ticket, setTicket] = useState<Json | null>(null)
  const [reply, setReply] = useState('')
  const [resolution, setResolution] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  const loadTicket = useCallback(async () => {
    try {
      setTicket(await api<Json>(`/support/tickets/${ticketId}/`))
      setError('')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load ticket.')
    }
  }, [ticketId])

  useEffect(() => { loadTicket() }, [loadTicket])

  async function sendReply() {
    if (!reply.trim()) return
    setBusy(true)
    try {
      setTicket(await api<Json>(`/support/tickets/${ticketId}/reply/`, {
        method: 'POST',
        body: { message: reply.trim() },
      }))
      setReply('')
      onUpdated()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Reply failed.')
    } finally {
      setBusy(false)
    }
  }

  async function resolveTicket() {
    if (!resolution.trim()) return
    setBusy(true)
    try {
      setTicket(await api<Json>(`/support/tickets/${ticketId}/resolve/`, {
        method: 'POST',
        body: { resolutionNote: resolution.trim(), notifyUser: true },
      }))
      setResolution('')
      onUpdated()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Resolve failed.')
    } finally {
      setBusy(false)
    }
  }

  async function ticketAction(action: string, body: Json = {}) {
    setBusy(true)
    try {
      setTicket(await api<Json>(`/support/tickets/${ticketId}/${action}/`, { method: 'POST', body }))
      onUpdated()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Action failed.')
    } finally {
      setBusy(false)
    }
  }

  const messages = (ticket?.messages as Json[]) || []
  const status = String(ticket?.status || '')
  const isResolved = status.toLowerCase() === 'resolved'

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal support-modal" onClick={(event) => event.stopPropagation()}>
        <header>
          <div>
            <h2>{String(ticket?.subject || 'Support ticket')}</h2>
            {ticket && <p className="muted">{String(ticket.userName)} · {String(ticket.userPhone)} · {String(ticket.userEmail || 'No email')}</p>}
          </div>
          <button type="button" className="modal-close" onClick={onClose}>×</button>
        </header>
        {error && <div className="error-banner">{error}</div>}
        {!ticket ? <div className="loading">Loading ticket…</div> : (
          <>
            <div className="support-meta">
              <Status value={status} />
              <span>Updated {date(String(ticket.updatedAt))}</span>
              {ticket.resolvedAt ? <span>Resolved {date(String(ticket.resolvedAt))}</span> : null}
            </div>
            <div className="support-thread">
              {messages.map((msg) => (
                <article key={String(msg.id)} className={`support-message support-message-${String(msg.authorRole)}`}>
                  <div className="support-message-head">
                    <strong>{String(msg.authorName || msg.authorRole)}</strong>
                    <small>{date(String(msg.createdAt))}</small>
                  </div>
                  <p>{String(msg.body)}</p>
                </article>
              ))}
              {!messages.length && ticket.message ? (
                <article className="support-message support-message-user">
                  <div className="support-message-head"><strong>{String(ticket.userName)}</strong></div>
                  <p>{String(ticket.message)}</p>
                </article>
              ) : null}
            </div>
            {!isResolved && (
              <div className="support-compose">
                <label>Reply to user
                  <textarea rows={3} value={reply} onChange={(e) => setReply(e.target.value)} placeholder="Type your response. User gets an in-app notification." />
                </label>
                <button className="primary" disabled={busy || !reply.trim()} onClick={sendReply}>
                  <Send size={15} /> Send reply
                </button>
              </div>
            )}
            {!isResolved ? (
              <div className="support-compose resolve-box">
                <label>Mark resolved with solution
                  <textarea rows={3} value={resolution} onChange={(e) => setResolution(e.target.value)} placeholder="Explain the fix. User is notified in-app." />
                </label>
                <div className="actions">
                  <button className="approve" disabled={busy || !resolution.trim()} onClick={resolveTicket}>
                    <CheckCircle2 size={15} /> Resolve & notify user
                  </button>
                  <button className="reject" disabled={busy} onClick={() => ticketAction('in-progress')}>Mark in progress</button>
                </div>
              </div>
            ) : (
              <div className="actions modal-actions">
                <button className="reject" disabled={busy} onClick={() => ticketAction('reopen', { note: 'Reopened by admin.' })}>Reopen ticket</button>
              </div>
            )}
            <div className="support-contact">
              <Mail size={15} /> Direct contact: <a href={`mailto:${String(ticket.userEmail || '')}`}>{String(ticket.userEmail || 'No email on file')}</a>
              {' · '}
              <MessageSquare size={15} /> {String(ticket.userPhone)}
            </div>
          </>
        )}
      </div>
    </div>
  )
}

function SupportPage({
  data, reload, initialTicketId, onClearTicket,
}: {
  data: Json
  reload: () => void
  initialTicketId?: string | null
  onClearTicket?: () => void
}) {
  const [selected, setSelected] = useState<string | null>(initialTicketId || null)
  const [statusFilter, setStatusFilter] = useState('')
  const [search, setSearch] = useState('')
  const [view, setView] = useState<Json>(data)

  useEffect(() => { setView(data) }, [data])
  useEffect(() => {
    if (initialTicketId) setSelected(initialTicketId)
  }, [initialTicketId])

  async function applyFilters() {
    const query = new URLSearchParams()
    if (statusFilter) query.set('status', statusFilter)
    if (search.trim()) query.set('search', search.trim())
    setView(await api<Json>(`/support/tickets/?${query.toString()}`))
  }

  const summary = (view.summary as Json) || {}
  const rows = (view.results as Json[]) || []

  return (
    <>
      <div className="metric-grid compact">
        <Metric label="Open tickets" value={Number(summary.open || 0)} tone="warning" />
        <Metric label="In progress" value={Number(summary.inProgress || 0)} />
        <Metric label="Resolved" value={Number(summary.resolved || 0)} tone="positive" />
        <Metric label="Total" value={Number(summary.total || 0)} />
      </div>
      <section className="panel filter-panel">
        <div className="filter-grid support-filter-grid">
          <label>Status
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
              <option value="">All</option>
              <option value="Open">Open</option>
              <option value="In Progress">In Progress</option>
              <option value="Resolved">Resolved</option>
            </select>
          </label>
          <label className="filter-search">Search
            <input placeholder="Subject, phone, name, email…" value={search} onChange={(e) => setSearch(e.target.value)} />
          </label>
          <button className="primary" onClick={applyFilters}>Apply filters</button>
        </div>
      </section>
      <div className="table-wrap">
        <table>
          <thead><tr><th>Updated</th><th>User</th><th>Subject</th><th>Messages</th><th>Status</th><th>Action</th></tr></thead>
          <tbody>
            {rows.map((row) => (
              <tr key={String(row.id)}>
                <td>{date(String(row.updatedAt))}</td>
                <td><strong>{String(row.userName)}</strong><small>{String(row.userPhone)}</small></td>
                <td>{String(row.subject)}</td>
                <td>{String(row.messageCount || 0)}</td>
                <td><Status value={String(row.status)} /></td>
                <td><button className="link-btn" onClick={() => setSelected(String(row.id))}>Open thread</button></td>
              </tr>
            ))}
          </tbody>
        </table>
        {!rows.length && <Empty text="No support tickets match these filters." />}
      </div>
      {selected && <SupportTicketModal ticketId={selected} onClose={() => { setSelected(null); onClearTicket?.() }} onUpdated={() => { reload(); applyFilters() }} />}
    </>
  )
}

function NotificationBell({ onNavigate }: { onNavigate: (tab: Tab, ticketId?: string) => void }) {
  const [open, setOpen] = useState(false)
  const [items, setItems] = useState<Json[]>([])
  const [unread, setUnread] = useState(0)

  const loadNotifications = useCallback(async () => {
    const payload = await api<Json>('/notifications/')
    setItems((payload.results as Json[]) || [])
    setUnread(Number(payload.unreadCount || 0))
  }, [])

  useEffect(() => {
    loadNotifications().catch(() => {})
    const timer = window.setInterval(() => { loadNotifications().catch(() => {}) }, 60000)
    return () => window.clearInterval(timer)
  }, [loadNotifications])

  async function markRead(id: string) {
    await api(`/notifications/${id}/read/`, { method: 'POST' })
    await loadNotifications()
  }

  async function markAllRead() {
    await api('/notifications/read-all/', { method: 'POST' })
    await loadNotifications()
  }

  function openItem(item: Json) {
    void markRead(String(item.id))
    setOpen(false)
    const tabName = String(item.actionTab || '') as Tab
    if (tabName === 'support' && item.referenceId) {
      onNavigate('support', String(item.referenceId))
      return
    }
    if (['kyc', 'money', 'errors', 'support', 'users'].includes(tabName)) {
      onNavigate(tabName as Tab)
    }
  }

  return (
    <div className="notification-wrap">
      <button type="button" className="notification-btn" onClick={() => { setOpen((value) => !value); if (!open) loadNotifications().catch(() => {}) }}>
        <Bell size={18} />
        {unread > 0 && <span className="notification-badge">{unread > 99 ? '99+' : unread}</span>}
      </button>
      {open && (
        <div className="notification-panel">
          <div className="notification-panel-head">
            <strong>Notifications</strong>
            <button type="button" className="link-btn" onClick={() => markAllRead()}>Mark all read</button>
          </div>
          <ul className="notification-list">
            {items.map((item) => (
              <li key={String(item.id)}>
                <button type="button" className={`notification-item${item.isRead ? '' : ' unread'}`} onClick={() => openItem(item)}>
                  <strong>{String(item.title)}</strong>
                  <small>{String(item.message)}</small>
                  <small className="activity-time">{date(String(item.createdAt))}</small>
                </button>
              </li>
            ))}
            {!items.length && <li className="empty-inline">No notifications.</li>}
          </ul>
        </div>
      )}
    </div>
  )
}

function AuditTable({ data }: { data: Json }) {
  return (
    <div className="table-wrap">
      <table>
        <thead><tr><th>Time</th><th>Admin</th><th>Action</th><th>Target</th><th>Summary</th><th>IP</th></tr></thead>
        <tbody>
          {((data.results as Json[]) || []).map((row) => (
            <tr key={String(row.id)}>
              <td>{date(String(row.createdAt))}</td>
              <td>{String(row.actor)}</td>
              <td><Status value={String(row.action)} /></td>
              <td className="mono">{String(row.targetType)}:{String(row.targetId).slice(0, 8)}</td>
              <td>{String(row.summary)}</td>
              <td className="mono">{String(row.ipAddress || '—')}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function AnnouncementsPage({ data, reload }: { data: Json; reload: () => void }) {
  const [title, setTitle] = useState('')
  const [message, setMessage] = useState('')
  const [category, setCategory] = useState('announcement')
  const [audience, setAudience] = useState('customers')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const summary = (data.summary as Json) || {}
  const rows = (data.results as Json[]) || []

  async function sendBroadcast() {
    if (!title.trim() || !message.trim()) {
      setError('Title and message are required.')
      return
    }
    setBusy(true)
    setError('')
    setSuccess('')
    try {
      const result = await api<Json>('/broadcasts/', {
        method: 'POST',
        body: { title: title.trim(), message: message.trim(), category, audience },
      })
      setSuccess(`Sent to ${String(result.recipientCount ?? 0)} users.`)
      setTitle('')
      setMessage('')
      reload()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Broadcast failed.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      <section className="panel broadcast-compose">
        <h2>Push notification to users</h2>
        <p className="muted">Announcements, news, and important alerts appear in every user&apos;s Notifications screen in the app.</p>
        <div className="filter-grid broadcast-grid">
          <label>Category
            <select value={category} onChange={(e) => setCategory(e.target.value)}>
              <option value="announcement">Announcement</option>
              <option value="news">News</option>
              <option value="important">Important</option>
            </select>
          </label>
          <label>Audience
            <select value={audience} onChange={(e) => setAudience(e.target.value)}>
              <option value="customers">All app users (non-staff)</option>
              <option value="all">Everyone including staff</option>
            </select>
          </label>
          <label className="broadcast-title">Title
            <input placeholder="e.g. Market holiday tomorrow" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={200} />
          </label>
          <label className="broadcast-message">Message
            <textarea rows={5} placeholder="Write the message users will see in their notification list…" value={message} onChange={(e) => setMessage(e.target.value)} />
          </label>
        </div>
        {error && <div className="error-banner">{error}</div>}
        {success && <div className="success-banner">{success}</div>}
        <button className="primary" disabled={busy} onClick={sendBroadcast}>
          <Send size={16} /> {busy ? 'Sending…' : 'Send to all users'}
        </button>
      </section>
      <div className="metric-grid compact">
        <Metric label="Total broadcasts" value={Number(summary.total || 0)} />
      </div>
      <div className="table-wrap">
        <table>
          <thead><tr><th>Sent</th><th>Category</th><th>Title</th><th>Recipients</th><th>By</th></tr></thead>
          <tbody>
            {rows.map((row) => (
              <tr key={String(row.id)}>
                <td>{date(String(row.createdAt))}</td>
                <td><Status value={String(row.category)} /></td>
                <td><strong>{String(row.title)}</strong><small>{String(row.message).slice(0, 120)}</small></td>
                <td>{String(row.recipientCount ?? 0)}</td>
                <td>{String(row.createdByName || '—')}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!rows.length && <Empty text="No broadcasts sent yet." />}
      </div>
    </>
  )
}

function App() {
  const [authenticated, setAuthenticated] = useState(DEV_NO_AUTH || Boolean(getToken()))
  const [tab, setTab] = useState<Tab>('dashboard')
  const [data, setData] = useState<Json>({})
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [supportTicketId, setSupportTicketId] = useState<string | null>(null)

  const load = useCallback(async (opts?: { silent?: boolean }) => {
    if (!authenticated) return
    if (!opts?.silent) setLoading(true)
    setError('')
    try {
      setData(await api<Json>(PATHS[tab]))
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load data.')
      if (!DEV_NO_AUTH && !getToken()) setAuthenticated(false)
    } finally {
      if (!opts?.silent) setLoading(false)
    }
  }, [authenticated, tab])

  useEffect(() => { load() }, [load])

  useEffect(() => {
    if (!authenticated || tab !== 'kyc') return
    const timer = window.setInterval(() => { load({ silent: true }).catch(() => {}) }, 8000)
    return () => window.clearInterval(timer)
  }, [authenticated, tab, load])

  useEffect(() => {
    if (!authenticated || tab !== 'users') return
    const timer = window.setInterval(() => { load({ silent: true }).catch(() => {}) }, 8000)
    return () => window.clearInterval(timer)
  }, [authenticated, tab, load])

  if (!authenticated) return <Login onLogin={() => setAuthenticated(true)} />

  const navigateTo = useCallback((nextTab: Tab, ticketId?: string) => {
    setData({})
    setTab(nextTab)
    setSupportTicketId(ticketId || null)
  }, [])

  const content =
    tab === 'dashboard' ? <Dashboard data={data} onNavigate={navigateTo} /> :
    tab === 'users' ? <UsersPage data={data} reload={load} /> :
    tab === 'kyc' ? <KycPage data={data} reload={load} /> :
    tab === 'stocks' ? <TradingPage data={data} segment="stocks" /> :
    tab === 'commodities' ? <TradingPage data={data} segment="commodities" /> :
    tab === 'futures' ? <TradingPage data={data} segment="futures" /> :
    tab === 'options' ? <TradingPage data={data} segment="options" /> :
    tab === 'money' ? <MoneyReports data={data} /> :
    tab === 'support' ? <SupportPage data={data} reload={load} initialTicketId={supportTicketId} onClearTicket={() => setSupportTicketId(null)} /> :
    tab === 'announcements' ? <AnnouncementsPage data={data} reload={load} /> :
    tab === 'errors' ? <ErrorsPage data={data} reload={load} /> :
    <AuditTable data={data} />

  return (
    <div className="shell">
      <aside>
        <div className="brand">
          <div className="brand-mark small"><ShieldCheck size={22} /></div>
          <div><strong>BullWave</strong><span>Admin</span></div>
        </div>
        <nav>
          {NAV.map((item) => (
            <button key={item.id} className={tab === item.id ? 'active' : ''} onClick={() => { setData({}); setTab(item.id) }}>
              {item.icon}{item.label}
            </button>
          ))}
        </nav>
        {!DEV_NO_AUTH && (
          <button className="logout" onClick={() => { clearToken(); setAuthenticated(false) }}>
            <LogOut size={17} /> Sign out
          </button>
        )}
      </aside>
      <main className="content">
        {DEV_NO_AUTH && (
          <div className="dev-banner">
            Development mode — no login required. API: {API_BASE}. Start Django on port 8000 if data fails to load.
          </div>
        )}
        <header>
          <div><p className="eyebrow">OPERATIONS</p><h1>{NAV.find((item) => item.id === tab)?.label}</h1></div>
          <div className="header-actions">
            <NotificationBell onNavigate={navigateTo} />
            <button className="refresh" onClick={load} disabled={loading}>
              <RefreshCw size={16} className={loading ? 'spin' : ''} /> Refresh
            </button>
          </div>
        </header>
        {error && <div className="error-banner">{error}</div>}
        {loading && !Object.keys(data).length ? <div className="loading">Loading secure admin data…</div> : content}
      </main>
    </div>
  )
}

export default App
