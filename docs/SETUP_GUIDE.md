# Run Ebb on your Mac: a guide for non-coders

You'll go from nothing to Ebb running in the iPhone Simulator in about 30–45 minutes. Most of that time is waiting for Xcode to download.

You don't need a paid Apple Developer account for any of this. Simulator builds are set up to sign themselves. You'll need one later to put Ebb on your own iPhone and in the App Store (see [LAUNCH_CHECKLIST.md](LAUNCH_CHECKLIST.md)).

---

## Step 1: Install Xcode (one time, ~20–40 min)

1. Open the **App Store** on your Mac and search for **Xcode**.
2. Click **Get**, then **Install**. It's large (several GB), so let it finish.
3. Open **Xcode** once. Accept the license, and if it asks to install extra components (including the **iOS** platform/simulator), say yes and let it finish.
4. Quit Xcode.

## Step 2: Download the Ebb code

1. Go to the repository on GitHub: https://github.com/ranjanpandey222/K17BK52_ca3
2. Switch to the branch **`claude/adoring-fermi-hkcpax`** (branch drop-down at the top left of the file list).
3. Click the green **Code** button → **Download ZIP**.
4. Double-click the ZIP in your Downloads folder to unzip it. You'll get a folder such as `K17BK52_ca3-claude-adoring-fermi-hkcpax`.

## Step 3: Run the setup script (one time)

1. Open the **Terminal** app (press ⌘ + Space, type *Terminal*, press Enter).
2. Type `cd ` (with a space after it). Don't press Enter yet.
3. Drag the unzipped Ebb folder from Finder into the Terminal window. Its path appears. Now press **Enter**.
4. Copy and paste this line, then press **Enter**:

   ```
   chmod +x setup.sh && ./setup.sh
   ```

5. If it asks for your Mac password (to install Homebrew), type it. You won't see the characters, which is normal. Press Enter.
6. When it finishes, **Xcode opens with the Ebb project**.

> If you see "Xcode isn't installed yet", finish Step 1 first.

## Step 4: Run the app

1. At the top of the Xcode window, next to the ▶ button, click the device name and pick an **iPhone** simulator (for example *iPhone 16*).
2. Press **▶** (or ⌘ + R). The first build takes a minute or two.
3. The Simulator opens and Ebb starts with onboarding. 🎉

## Step 5: Try everything

- **Subscriptions** work in a local test mode: no real money and no Apple account needed. On the paywall, pick a plan and tap the button. The test purchase goes through instantly.
  - To reset test purchases: in Xcode, menu **Debug → StoreKit → Manage Transactions…** and delete them.
  - In this test build there's also a **"Skip (debug)"** button on the paywall and a **Debug: unlock** switch in Settings. These only exist in test builds, never in the App Store version.
  - **If the paywall says "Subscription Unavailable":** Apple has a known bug in StoreKit testing on iOS 26.3–26.5 simulators. Just tap **Skip (debug)**, or choose an iPhone simulator running iOS 26.2 or 26.6+. The real purchase flow is checked automatically on every change (see "Automatic checks" below).
- **See a full app instantly:** go to **More → Settings → Subscription → "Debug: load 10 weeks of sample data"**. You'll get realistic check-ins, an HRT patch and patterns to explore (test builds only).
- **Or build up data by hand:** patterns need at least 7 check-ins. In the **History** tab, tap past days to add check-ins for them.
- **Apple Health** works in the Simulator, but it has no sleep or Apple Watch data, so those cards show "–". That's expected.
- **Face ID lock:** in the Simulator use menu **Features → Face ID → Enrolled**, then **Matching Face** when asked.

## Automatic checks (already set up)

Every time code changes on GitHub, Apple's tools on a GitHub Mac automatically:
- build the app (test and App Store versions, simulator and real iPhone),
- run 33 logic tests (pattern finder, report, stage),
- run the app in an iPhone simulator: onboarding → paywall → first check-in, then every main screen with sample data, taking screenshots,
- run the subscription tests: products, prices, free trial, purchase unlocks, expiry relocks.

See them under the repository's **Actions** tab. Green ✓ = all good.

## If something goes wrong

- **Build errors (red messages in Xcode):** click the red ⛔ icon in the left sidebar, copy the error text, and paste it to Claude. It's usually a quick fix.
- **"No such module 'EbbCore'":** use the menu **File → Packages → Reset Package Caches**, then press ▶ again.
- **The paywall shows no prices:** the scheme should already use `StoreKit/Ebb.storekit`. If not: menu **Product → Scheme → Edit Scheme… → Run → Options → StoreKit Configuration** and select `Ebb.storekit`.
- **Changed `project.yml`?** Run `xcodegen generate` in Terminal (inside the folder) again.

## How the project is organized (for later)

| Folder | What's inside |
|---|---|
| `Ebb/` | The iPhone app (screens, data, services) |
| `Packages/EbbCore/` | The app's "brain": pattern finder, report builder, stage estimate. Fully unit-tested |
| `StoreKit/Ebb.storekit` | Local test version of the subscriptions |
| `project.yml` | Recipe XcodeGen uses to create `Ebb.xcodeproj` |
| `docs/` | Guides, App Store text, privacy policy |
| `.github/workflows/` | Automatic build check on GitHub's Macs for every change |
