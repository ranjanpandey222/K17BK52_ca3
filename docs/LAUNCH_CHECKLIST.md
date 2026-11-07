# Ebb launch checklist

Everything between "the app runs in the Simulator" and "live on the App Store", in order. Items marked 👤 need you (accounts, money, legal decisions). Claude can help with the rest.

## 1. Accounts & legal (start now: some take days)
- [ ] 👤 **Apple Developer Program** ($99/year): https://developer.apple.com/programs/enroll/. Enroll as an *individual* (fastest) or as a *company* (needs a D-U-N-S number, takes longer; your company name shows on the App Store).
- [ ] 👤 In App Store Connect → **Business**: sign the **Paid Apps Agreement** and add **bank and tax info**. Subscriptions can't be sold until this is done.
- [ ] 👤 Decide whether to make the GitHub repo **private** (it's currently public, so anyone can see the code). Settings → General → Danger Zone → Change visibility. *Note: private repos have limited free macOS build minutes for the automatic build check.*
- [ ] 👤 Quick trademark check for "Ebb" in health/software (USPTO search: https://tmsearch.uspto.gov) and check the App Store name is free. The name can be "Ebb: Menopause Tracker" even if plain "Ebb" is taken.

## 2. Make the app yours
- [ ] Choose a final **bundle ID** (e.g. `com.yourcompany.ebb`) and set it in `project.yml` → `PRODUCT_BUNDLE_IDENTIFIER`, then run `xcodegen generate`.
- [ ] In Xcode → target **Ebb** → **Signing & Capabilities** → choose your **Team** (appears after enrolling).
- [ ] Host the **privacy policy** (`docs/PRIVACY_POLICY.md`) at a public URL. Easiest is GitHub Pages or a free Notion page. Put the URL in `Ebb/App/AppConfig.swift` → `privacyPolicyURL`.
- [ ] Set a real **support email** in `AppConfig.swift` → `supportEmail`.
- [ ] Optional: host `docs/TERMS.md` and set `termsURL` (Apple's standard EULA is already set as a fallback).

## 3. Medical content review (strongly recommended)
- [ ] 👤 Have a qualified clinician, ideally a **Menopause Society Certified Practitioner (MSCP)**, review the Learn articles (`Ebb/Features/Learn/LearnContent.swift`), the stage text (`Packages/EbbCore/Sources/EbbCore/StageEstimator.swift`) and the doctor-report questions (`ReportBuilder.swift`). Budget a few hundred dollars. It protects users and you, and is good marketing ("reviewed by…").
- [ ] Keep all wording as **wellness/education**: no diagnosing, no treatment recommendations. The app is built this way; keep it that way in marketing too.

## 4. Subscriptions in App Store Connect
Create the app (My Apps → +), then **Monetization → Subscriptions**:
- [ ] Subscription group: **Ebb Premium**
- [ ] Product **`ebb.premium.yearly`**: 1 year, **$59.99**, introductory offer **1 week free** (new subscribers)
- [ ] Product **`ebb.premium.monthly`**: 1 month, **$9.99**, introductory offer **1 week free**
- [ ] Add display name, description and a review screenshot (a screenshot of the paywall) for each
- [ ] Product IDs **must match exactly** what's in `StoreService.swift` and `StoreKit/Ebb.storekit`
- [ ] Apply for the **App Store Small Business Program** (15% commission instead of 30%): https://developer.apple.com/app-store/small-business-program/

## 5. App Store listing
- [ ] Text: see [APP_STORE_LISTING.md](APP_STORE_LISTING.md) (name, subtitle, description, keywords, review notes)
- [ ] Category: **Health & Fitness** (secondary: Medical is *not* recommended; it invites stricter review)
- [ ] Age rating questionnaire: answer honestly. "Medical/Treatment Information: Infrequent/Mild" fits the Learn section.
- [ ] **App Privacy** ("nutrition label"): select **Data Not Collected**. This is accurate: everything stays on the device and Ebb has no analytics or ad SDKs. (Purchases are handled by Apple and don't count.) If you ever add analytics, update this.
- [ ] Screenshots: 6.9" iPhone (1320 × 2868) and 6.5" (1284 × 2778). Take them in the Simulator (⌘ + S) on iPhone 16 Pro Max / iPhone 11 Pro Max. Suggested set: Today · Check-in · Insights · Treatment "Is it working?" · Doctor report · Privacy promise.

## 6. Test on a real iPhone (TestFlight)
- [ ] In Xcode: select **Any iOS Device** → menu **Product → Archive** → **Distribute App** → **TestFlight & App Store**
- [ ] In App Store Connect → TestFlight: add yourself and 5–20 beta testers (ideally women 40–55)
- [ ] Test on a real phone: Apple Health (with real sleep data), Face ID lock, reminders, a sandbox purchase, PDF sharing/printing
- [ ] Fix anything found, bump the build number (`CURRENT_PROJECT_VERSION` in `project.yml`), archive again

## 7. Submit for review
- [ ] Fill in **App Review notes** (template in APP_STORE_LISTING.md). Explain the subscription and that health data stays on device.
- [ ] Submit. Review usually takes 1–3 days. Common rejection reasons for this kind of app, and how Ebb handles them:
  - *Paywall missing terms/privacy links or restore*: handled by Apple's subscription view and the Settings screen
  - *Medical claims*: wording is wellness-only; keep marketing the same
  - *HealthKit purpose unclear*: purpose strings are in `project.yml`; the review notes explain it

## 8. Launch week
- [ ] Line up 1–2 menopause creators (Instagram/TikTok) to post on launch day
- [ ] Start Meta/TikTok ads at a small daily budget with creator-style videos. **No health claims in ads.**
- [ ] Ask happy beta testers for App Store reviews
- [ ] Watch App Store Connect → Trends / Subscriptions daily: trial starts, trial → paid conversion, refunds
