#!/usr/bin/env python3
"""Generate Capital BullWave Play Store Roadmap PDF."""

from pathlib import Path

from fpdf import FPDF

OUT = Path(__file__).resolve().parent / "Capital-BullWave-Play-Store-Roadmap.pdf"


class RoadmapPDF(FPDF):
    def header(self):
        self.set_font("Helvetica", "B", 10)
        self.set_text_color(100, 100, 100)
        self.cell(0, 8, "Capital BullWave - Play Store Strategy & Roadmap", align="C", new_x="LMARGIN", new_y="NEXT")
        self.ln(2)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(120, 120, 120)
        self.cell(0, 10, f"Page {self.page_no()} | Confidential - Internal Use", align="C")

    def section_title(self, num: str, title: str):
        self.ln(4)
        self.set_x(self.l_margin)
        self.set_font("Helvetica", "B", 14)
        self.set_text_color(30, 80, 160)
        self.multi_cell(self.epw, 8, f"{num}. {title}")
        self.ln(2)

    def sub_title(self, title: str):
        self.set_x(self.l_margin)
        self.set_font("Helvetica", "B", 11)
        self.set_text_color(40, 40, 40)
        self.multi_cell(self.epw, 7, title)
        self.ln(1)

    def body(self, text: str):
        self.set_x(self.l_margin)
        self.set_font("Helvetica", "", 10)
        self.set_text_color(30, 30, 30)
        self.multi_cell(self.epw, 5.5, text)
        self.ln(2)

    def bullet(self, text: str):
        self.set_x(self.l_margin)
        self.set_font("Helvetica", "", 10)
        self.set_text_color(30, 30, 30)
        self.multi_cell(self.epw, 5.5, f"  - {text}")

    def table_row(self, cols, bold=False, fill=False):
        widths = [62, 118]
        self.set_font("Helvetica", "B" if bold else "", 9)
        if fill:
            self.set_fill_color(232, 242, 253)
        for i, col in enumerate(cols):
            self.cell(widths[i], 7, col[:80], border=1, fill=fill)
        self.ln(7)
        self.set_x(self.l_margin)


def build():
    pdf = RoadmapPDF()
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.add_page()

    # Cover
    pdf.set_font("Helvetica", "B", 22)
    pdf.set_text_color(30, 80, 160)
    pdf.ln(20)
    pdf.multi_cell(0, 12, "Capital BullWave\nPlay Store Strategy & Roadmap", align="C")
    pdf.ln(8)
    pdf.set_font("Helvetica", "", 12)
    pdf.set_text_color(60, 60, 60)
    pdf.multi_cell(0, 7, "Paper Trading Launch (Now)\n+ Real Trading (After License)", align="C")
    pdf.ln(15)
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, "Version 1.0  |  19 August 2026\nApp: bullwave_investing (Flutter)\nAPI: api.capitalbullwave.com", align="C")

    pdf.add_page()
    pdf.section_title("1", "Executive Summary")
    pdf.body(
        "Publish on Google Play NOW as a paper trading / market research simulator while your "
        "real trading license is pending. The current app still shows Featured Plans (36-48% returns), "
        "Wallet deposits, payment methods, and Copy Trading. That is the main reason Play Store rejects."
    )
    pdf.table_row(["Phase", "What to ship"], bold=True, fill=True)
    pdf.table_row(["Now (no license)", "Paper simulator + charts. NO deposits, NO return promises"])
    pdf.table_row(["After license", "Full wallet, plans, Cashfree payments, KYC-gated trading"])
    pdf.ln(4)

    pdf.section_title("2", "Why Google Play Keeps Rejecting")
    pdf.sub_title("HIGH RISK issues in current app:")
    for item in [
        "Featured Plans: 3%, 36%, 48% p.a. fixed returns (Premier/Reserve/Crown)",
        "Payment methods on plan screen (UPI/Card) when not active for public",
        "Wallet Add Money / Withdraw with Cashfree integration",
        "Onboarding: 'Up to 4% monthly returns', 'encrypted payouts'",
        "Copy Trading: allocate capital to verified traders",
        "Goal Plans: Earn 8-16% p.a. with payment",
        "Markets Buy/Sell looks live but backend is paper-only",
    ]:
        pdf.bullet(item)
    pdf.ln(3)
    pdf.body(
        "Google reviews the installed APK, not only listing text. Financial Services policy "
        "requires licensed products for fixed returns and real-money flows."
    )

    pdf.section_title("3", "Current App Analysis")
    pdf.sub_title("SAFE to keep (paper launch):")
    for item in [
        "Paper Trading hub with virtual funds",
        "Paper Buy/Sell via placePaperTrade API",
        "Live charts, watchlist, screener, news, IPO calendar",
        "Investment calculator and education documents",
        "Paper competitions and risk meter",
    ]:
        pdf.bullet(item)
    pdf.ln(2)
    pdf.sub_title("MUST HIDE for paper-only launch:")
    for item in [
        "Featured Plans carousel and plan detail + payment UI",
        "Wallet deposit/withdraw and Cashfree checkout",
        "Goal Plans with returns and Pay Now",
        "Copy Trading screen",
        "Full KYC flow (optional: phone OTP only)",
        "Onboarding slides mentioning returns/payouts",
    ]:
        pdf.bullet(item)
    pdf.ln(2)
    pdf.sub_title("RELABEL:")
    for item in [
        "Portfolio tab -> Paper Portfolio + disclaimer banner",
        "Buy/Sell -> Paper Buy / Paper Sell",
        "Wallet tab -> hide OR Practice Balance only",
    ]:
        pdf.bullet(item)

    pdf.add_page()
    pdf.section_title("4", "Phase 1 - Paper Trading Play Store Launch")
    pdf.body("Goal: Live on Play as 'Capital BullWave - Paper Trading Simulator'. Timeline: 2-4 weeks.")
    pdf.sub_title("A. App development")
    for item in [
        "Add PAPER_ONLY=true dart-define build flag",
        "Hide Featured Plans, Goals payments, Copy Trading, Wallet deposit/withdraw",
        "Rewrite onboarding/splash/about - no return percentages",
        "Add disclaimer: Simulated trading only. No real money. Not SEBI-registered.",
        "Optional: remove Cashfree SDK from paper-only build",
        "Version 1.1.0+6",
    ]:
        pdf.bullet(item)
    pdf.ln(2)
    pdf.sub_title("B. Play Console listing")
    for item in [
        "Title: Capital BullWave - Paper Trading",
        "Description: simulator with virtual money, live charts - NO deposits",
        "Screenshots: charts, paper trade ONLY - no plans/payments",
        "Financial Services: declare simulation only if no real money in APK",
        "Category: Finance (educational/simulation)",
    ]:
        pdf.bullet(item)
    pdf.ln(2)
    pdf.sub_title("C. Submit process")
    for item in [
        "Upload signed AAB",
        "Internal test -> Closed test (recommended) -> Production",
        "If rejected: read exact policy, fix, resubmit with explanation",
    ]:
        pdf.bullet(item)

    pdf.section_title("5", "Phase 2 - After License Approval")
    pdf.sub_title("Prerequisites:")
    for item in [
        "SEBI registration (broker/IA/PMS as applicable)",
        "Cashfree production KYC + Payment Gateway live",
        "Updated Terms and risk disclosures",
        "Real broker API integration (when ready)",
    ]:
        pdf.bullet(item)
    pdf.ln(2)
    pdf.sub_title("App + Play updates:")
    for item in [
        "Disable PAPER_ONLY flag in production build",
        "Re-enable Wallet, Plans, Goals, Copy Trading (if licensed)",
        "Update store listing with license numbers",
        "Upload license proof in Play Console Financial Services section",
        "Staged rollout 5% to 100%",
    ]:
        pdf.bullet(item)

    pdf.add_page()
    pdf.section_title("6", "User Journey Flows")
    pdf.sub_title("Phase 1 (Paper only):")
    pdf.body("Install -> Splash -> Onboarding -> Login OTP -> Home -> Markets/Paper Trade -> Virtual portfolio + live charts. NO deposit, NO plans, NO payments.")
    pdf.sub_title("Phase 2 (After license):")
    pdf.body("Install -> Login -> Full KYC -> Home + Wallet -> Real trade OR Featured Plan OR Goals -> Cashfree payment.")

    pdf.section_title("7", "Rejection Response Template")
    pdf.body(
        'If rejected, reply in Play Console Policy status:\n\n'
        '"We updated the app to paper trading simulation only. All investment plan screens, '
        'payment methods, wallet deposit/withdraw, and fixed return marketing are REMOVED. '
        'The app does not accept real money. Users practice with virtual funds only. '
        'We are not a SEBI-registered broker. Store listing and screenshots updated to match."'
    )

    pdf.section_title("8", "Action Checklist")
    pdf.sub_title("Before next Play upload:")
    for item in [
        "PAPER_ONLY flag implemented",
        "Featured Plans hidden from Home and routes",
        "Wallet deposit/withdraw hidden",
        "Payment UI removed from plan screens",
        "Onboarding copy fixed",
        "Paper disclaimer on trade screens",
        "Store listing + screenshots updated",
        "Play Financial Services form updated",
        "Device test: no payment path reachable",
    ]:
        pdf.bullet(item)
    pdf.ln(2)
    pdf.sub_title("After license:")
    for item in [
        "Legal review of Terms",
        "Cashfree production go-live",
        "KYC production verified",
        "Enable real-money features",
        "Play update v2.0 + license upload",
    ]:
        pdf.bullet(item)

    pdf.section_title("9", "Recommended Timeline")
    pdf.table_row(["Week", "Phase 1 tasks"], bold=True, fill=True)
    pdf.table_row(["Week 1", "PAPER_ONLY flag, hide plans/wallet/payments"])
    pdf.table_row(["Week 2", "Copy, disclaimers, QA on device"])
    pdf.table_row(["Week 3", "Store listing, screenshots, internal test"])
    pdf.table_row(["Week 4", "Production submit (review 3-7 days)"])
    pdf.ln(4)
    pdf.table_row(["Phase 2", "After license"], bold=True, fill=True)
    pdf.table_row(["License pending", "Keep paper app live, gather feedback"])
    pdf.table_row(["License received", "2-4 weeks dev + Cashfree prod + compliance"])
    pdf.table_row(["Go live", "Play update v2.0"])

    pdf.ln(8)
    pdf.set_font("Helvetica", "I", 9)
    pdf.set_text_color(100, 100, 100)
    pdf.multi_cell(
        0,
        5,
        "Disclaimer: This document is for internal planning only. Not legal advice. "
        "Consult your compliance advisor before enabling real-money features.",
    )

    pdf.output(OUT)
    print(f"PDF written to {OUT}")


if __name__ == "__main__":
    build()
