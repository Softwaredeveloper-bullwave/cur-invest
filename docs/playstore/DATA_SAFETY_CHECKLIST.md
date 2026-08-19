# Play Console — Data Safety Form Checklist

Fill this honestly in Play Console → **App content → Data safety**.

---

## Data collected

| Data type | Collected? | Purpose | Shared? |
|-----------|------------|---------|---------|
| Phone number | Yes | Account login (OTP) | No |
| Email | Yes | Account verification | No |
| Name | Yes | Profile | No |
| Date of birth | Yes | Identity verification | No |
| Government ID (PAN) | Yes | KYC / fraud prevention | Verification provider only |
| Aadhaar (via DigiLocker) | Yes | Identity verification | Verification provider only |
| Bank account (masked) | Yes | Identity verification | Verification provider only |
| Photos (selfie) | Optional / Phase 2 | Identity | No |
| App activity (trades) | Yes | Paper trading simulation | No |
| Crash logs | Yes | App stability | No |

---

## Security

- [x] Data encrypted in transit (HTTPS)
- [x] Users can request account deletion (link in privacy policy)
- [x] Privacy policy URL: https://capitalbullwave.com/privacy

---

## Financial features declaration

For **Phase 1 (this build)**:

- [ ] Does your app facilitate financial products? → **No** (simulation only)
- [ ] Does your app process payments? → **No**
- [ ] Cryptocurrency? → **No**

If asked about "financial features":
> The app provides market education and simulated paper trading only. No real-money transactions.

---

## Permissions justification

| Permission | Why |
|------------|-----|
| INTERNET | API, charts, market data |
| CAMERA | Optional KYC selfie (Phase 2) / profile photo |
| RECORD_AUDIO | Voice search / AI assistant (optional) |

---

## Target age

- **18+** recommended for finance-related apps
