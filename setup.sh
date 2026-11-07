#!/bin/bash
# One-step setup for Ebb on a Mac.
# Usage (in Terminal, inside this folder):   ./setup.sh
set -e

cd "$(dirname "$0")"

echo "==> Checking for Xcode..."
if ! xcode-select -p >/dev/null 2>&1 || [ ! -d "/Applications/Xcode.app" ]; then
  echo "Xcode isn't installed yet. Install it from the Mac App Store, open it once, then run this script again."
  open "macappstore://apps.apple.com/app/xcode/id497799835" || true
  exit 1
fi

echo "==> Checking for Homebrew..."
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew (you'll be asked for your Mac password)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Make brew available in this session (Apple Silicon and Intel paths).
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
fi

echo "==> Installing XcodeGen..."
brew list xcodegen >/dev/null 2>&1 || brew install xcodegen

echo "==> Generating the Xcode project..."
xcodegen generate

echo "==> Opening Ebb in Xcode..."
open Ebb.xcodeproj

echo ""
echo "Done! In Xcode: pick an iPhone simulator at the top, then press ▶ (Run)."
