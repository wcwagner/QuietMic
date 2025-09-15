#!/bin/bash
# Setup script for QuietMic sudo wrapper
# Run this script to configure passwordless log collection

set -e

echo "🔧 Setting up QuietMic sudo wrapper for passwordless log collection..."

# Get current user
USER=$(whoami)
echo "📝 Current user: $USER"

echo ""
echo "⚠️  This script requires sudo access. You'll be prompted for your password."
echo ""

# Create the wrapper directory
echo "1️⃣ Creating /usr/local/sbin directory..."
sudo mkdir -p /usr/local/sbin

# Create the wrapper script
echo "2️⃣ Creating secure log collection wrapper..."
sudo tee /usr/local/sbin/quietmic-log-collect >/dev/null <<'EOF'
#!/bin/sh
# Root-owned shim so sudoers can allow *only* `log collect`.
# This follows security best practices by limiting sudo access to exactly one command.
exec /usr/bin/log collect "$@"
EOF

# Set proper ownership and permissions
echo "3️⃣ Setting secure permissions (root:wheel, 755)..."
sudo chown root:wheel /usr/local/sbin/quietmic-log-collect
sudo chmod 755 /usr/local/sbin/quietmic-log-collect

# Create sudoers configuration
echo "4️⃣ Configuring sudoers for passwordless access..."
echo "    Adding NOPASSWD rule for user: $USER"
sudo tee /etc/sudoers.d/quietmic-logs >/dev/null <<EOF
# QuietMic passwordless log collection
# Allows $USER to run log collection without password prompts
# This follows least-privilege principle - only one specific command is allowed
$USER ALL=(root) NOPASSWD: /usr/local/sbin/quietmic-log-collect
EOF

# Validate sudoers syntax
echo "5️⃣ Validating sudoers configuration..."
sudo visudo -c -f /etc/sudoers.d/quietmic-logs

# Test the configuration
echo "6️⃣ Testing passwordless sudo access..."
if sudo -n /usr/local/sbin/quietmic-log-collect --help >/dev/null 2>&1; then
    echo "✅ SUCCESS: Passwordless sudo is working correctly!"
else
    echo "❌ ERROR: Passwordless sudo test failed"
    echo "   This might be due to sudoers caching. Try running:"
    echo "   sudo -k && sudo -n /usr/local/sbin/quietmic-log-collect --help"
    exit 1
fi

echo ""
echo "🎉 Setup complete! QuietMic can now collect logs without password prompts."
echo ""
echo "To test manually:"
echo "  sudo -n /usr/local/sbin/quietmic-log-collect --help"
echo ""
echo "The agent can now run 'make collect' without any password prompts."