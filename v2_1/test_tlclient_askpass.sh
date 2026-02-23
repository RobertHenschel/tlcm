#!/bin/bash
# ============================================================================
# Test: tlclient -P (askpass) integration
#
# This script tests whether tlclient actually uses the askpass script to
# auto-login, by launching it directly against a real server.
#
# Usage:
#   chmod +x test_tlclient_askpass.sh
#   ./test_tlclient_askpass.sh <server> <username> <password>
#
# Example:
#   ./test_tlclient_askpass.sh myserver.example.com alice MyP@ssw0rd
#
# The script will:
#   1. Store the password in Keychain
#   2. Create an askpass script
#   3. Create a tlclient config file
#   4. Verify the askpass script works standalone
#   5. Launch tlclient DIRECTLY (binary, not via 'open') with -C and -P
#   6. Also show the equivalent 'open -a' command for comparison
#   7. Clean up Keychain entry on exit
# ============================================================================

set -e

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <server> <username> <password>"
    echo ""
    echo "Example:"
    echo "  $0 myserver.example.com alice MyP@ssw0rd"
    exit 1
fi

SERVER="$1"
USERNAME="$2"
PASSWORD="$3"
SERVICE="ThinLincConnectionManager"
CONN_ID="$(uuidgen)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASKPASS_SCRIPT="$SCRIPT_DIR/askpass_live_test.sh"
CONFIG_FILE="$SCRIPT_DIR/tlclient_live_test.conf"
TLCLIENT_APP="/Applications/ThinLinc Client.app"
TLCLIENT_BIN="$TLCLIENT_APP/Contents/MacOS/tlclient"

echo "=== tlclient askpass live test ==="
echo "  Server:    $SERVER"
echo "  Username:  $USERNAME"
echo "  Password:  (${#PASSWORD} chars, not shown)"
echo "  ConnID:    $CONN_ID"
echo ""

cleanup() {
    echo ""
    echo "=== Cleanup ==="
    security delete-generic-password -s "$SERVICE" -a "$CONN_ID" 2>/dev/null && echo "  Removed Keychain entry" || echo "  Keychain entry already gone"
    rm -f "$ASKPASS_SCRIPT" && echo "  Removed askpass script"
    rm -f "$CONFIG_FILE" && echo "  Removed config file"
}
trap cleanup EXIT

# ── Step 1: Verify tlclient exists ──────────────────────────────────────────
echo "--- Step 1: Check tlclient ---"
if [[ ! -x "$TLCLIENT_BIN" ]]; then
    echo "  ERROR: tlclient not found at $TLCLIENT_BIN"
    exit 1
fi
echo "  Found: $TLCLIENT_BIN"
echo "  Version: $("$TLCLIENT_BIN" --version 2>/dev/null || echo '(could not read version)')"

# ── Step 2: Store password in Keychain ──────────────────────────────────────
echo ""
echo "--- Step 2: Store password in Keychain ---"
security add-generic-password \
    -s "$SERVICE" \
    -a "$CONN_ID" \
    -w "$PASSWORD" \
    -U

RETRIEVED=$(security find-generic-password -s "$SERVICE" -a "$CONN_ID" -w 2>/dev/null)
if [[ "$RETRIEVED" == "$PASSWORD" ]]; then
    echo "  PASS: Password stored and retrieved correctly"
else
    echo "  FAIL: Password mismatch"
    exit 1
fi

# ── Step 3: Write askpass script ─────────────────────────────────────────────
echo ""
echo "--- Step 3: Write askpass script ---"
cat > "$ASKPASS_SCRIPT" <<ASKEOF
#!/bin/bash
security find-generic-password -s "$SERVICE" -a "$CONN_ID" -w
ASKEOF
chmod 700 "$ASKPASS_SCRIPT"
echo "  Written: $ASKPASS_SCRIPT"
echo "  Permissions: $(stat -f '%Sp' "$ASKPASS_SCRIPT")"

# ── Step 4: Verify askpass script output ────────────────────────────────────
echo ""
echo "--- Step 4: Verify askpass script ---"
ASKPASS_OUT=$("$ASKPASS_SCRIPT")
if [[ "$ASKPASS_OUT" == "$PASSWORD" ]]; then
    echo "  PASS: askpass script returns correct password"
else
    echo "  FAIL: askpass returned: '$ASKPASS_OUT'"
    exit 1
fi

# ── Step 5: Write tlclient config file ──────────────────────────────────────
echo ""
echo "--- Step 5: Write tlclient config ---"
cat > "$CONFIG_FILE" <<CONFEOF
SERVER_NAME=$SERVER
LOGIN_NAME=$USERNAME
AUTHENTICATION_METHOD=password
CONFEOF
echo "  Written: $CONFIG_FILE"
cat "$CONFIG_FILE"

# ── Step 6: Launch methods ───────────────────────────────────────────────────
echo ""
echo "--- Step 6: Launch ---"
echo ""
echo "  Choose how to launch tlclient:"
echo "    1) Direct binary:  tlclient -C <config> -P <askpass>"
echo "    2) Via 'open -a':  open -n -a <app> --args -C <config> -P <askpass>"
echo ""
echo -n "  Enter 1 or 2 [default: 1]: "
read -r CHOICE
CHOICE="${CHOICE:-1}"

echo ""
if [[ "$CHOICE" == "1" ]]; then
    echo "  Launching directly: $TLCLIENT_BIN"
    echo "    Args: -C \"$CONFIG_FILE\" -P \"$ASKPASS_SCRIPT\""
    echo ""
    echo "  >> tlclient should open and auto-login WITHOUT showing a password prompt."
    echo "  >> If it shows the password field empty, -P is not being used."
    echo "  >> Close tlclient when done, then press Enter here."
    echo ""
    "$TLCLIENT_BIN" -C "$CONFIG_FILE" -P "$ASKPASS_SCRIPT" &
    TLCLIENT_PID=$!
    echo "  Launched with PID $TLCLIENT_PID"
    read -r
    kill "$TLCLIENT_PID" 2>/dev/null || true
else
    echo "  Launching via 'open -a':"
    echo "    open -n -a \"$TLCLIENT_APP\" --args -C \"$CONFIG_FILE\" -P \"$ASKPASS_SCRIPT\""
    echo ""
    echo "  >> tlclient should open and auto-login WITHOUT showing a password prompt."
    echo "  >> If it shows the password field empty, -P is not being passed by 'open'."
    echo "  >> Close tlclient when done, then press Enter here."
    echo ""
    open -n -a "$TLCLIENT_APP" --args -C "$CONFIG_FILE" -P "$ASKPASS_SCRIPT"
    read -r
fi

echo ""
echo "  Did tlclient auto-login without showing a password prompt? (y/n)"
read -r RESULT
if [[ "$RESULT" == "y" ]]; then
    echo "  PASS: askpass integration works with this launch method"
else
    echo "  FAIL: tlclient did not auto-login (password prompt was shown or field was empty)"
    echo ""
    echo "  Diagnostic info:"
    echo "    askpass script path: $ASKPASS_SCRIPT"
    echo "    askpass script output when run manually:"
    "$ASKPASS_SCRIPT"
fi
