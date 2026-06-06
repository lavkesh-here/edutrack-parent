#!/usr/bin/env bash
# Install git pre-push hook for parent_app
set -e
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
HOOK="$REPO_ROOT/.git/hooks/pre-push"

cat > "$HOOK" <<'HOOK_BODY'
#!/usr/bin/env bash
# Pre-push: run dart analyze to catch type errors before CI does
FLUTTER=$(command -v flutter 2>/dev/null)
if [ -z "$FLUTTER" ]; then
  echo "[pre-push] flutter not in PATH — skipping analyze (CI will catch errors)"
  exit 0
fi
echo "[pre-push] Running flutter analyze..."
cd "$(git rev-parse --show-toplevel)"
flutter analyze --no-fatal-infos
STATUS=$?
if [ $STATUS -ne 0 ]; then
  echo ""
  echo "[pre-push] ❌ Dart analysis failed. Fix errors above before pushing."
  echo "           To skip (emergency only): git push --no-verify"
  exit 1
fi
echo "[pre-push] ✓ Dart analysis passed."
HOOK_BODY

chmod +x "$HOOK"
echo "✓ pre-push hook installed at $HOOK"
