#!/usr/bin/env bash

# Exit on error
set -e

# Check if run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo."
  exit 1
fi

CMDLINE_FILE="/etc/kernel/cmdline"
CMDLINE_BAK="/etc/kernel/cmdline.bak"

if [ ! -f "$CMDLINE_FILE" ]; then
  echo "Error: $CMDLINE_FILE not found."
  exit 1
fi

echo "Step 1: Backing up $CMDLINE_FILE to $CMDLINE_BAK..."
cp "$CMDLINE_FILE" "$CMDLINE_BAK"

echo "Step 2: Updating kernel parameters (switching to s2idle + i915 PSR fix)..."
python3 -c "
import sys

filepath = '$CMDLINE_FILE'
with open(filepath, 'r') as f:
    content = f.read().strip()

parts = content.split()
# Remove xe / i915 force_probe parameters
filtered = [p for p in parts if not ('i915.force_probe' in p or 'xe.force_probe' in p)]

# Remove mem_sleep_default parameter so it defaults to s2idle (or set it to s2idle)
filtered = [p for p in filtered if not 'mem_sleep_default' in p]

# Add i915.enable_psr=0 (disables Panel Self Refresh, preventing black screens on wake)
if not any('i915.enable_psr' in p for p in filtered):
    filtered.append('i915.enable_psr=0')
else:
    filtered = [p if not 'i915.enable_psr' in p else 'i915.enable_psr=0' for p in filtered]

# Add i915.enable_dc=0 (disables Display C-states, preventing freezes on wake)
if not any('i915.enable_dc' in p for p in filtered):
    filtered.append('i915.enable_dc=0')
else:
    filtered = [p if not 'i915.enable_dc' in p else 'i915.enable_dc=0' for p in filtered]

new_line = ' '.join(filtered)

with open(filepath, 'w') as f:
    f.write(new_line + '\n')

print('Old command line:', content)
print('New command line:', new_line)
"

echo "Step 3: Rebuilding initramfs / Unified Kernel Image..."
mkinitcpio -P

echo "Step 4: Clearing kwin display cache..."
if [ -n "$SUDO_USER" ]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  KWIN_CONFIG="$USER_HOME/.config/kwinoutputconfig.json"
  if [ -f "$KWIN_CONFIG" ]; then
    echo "Backing up $KWIN_CONFIG..."
    mv "$KWIN_CONFIG" "$KWIN_CONFIG.bak"
    chown "$SUDO_USER:$SUDO_USER" "$KWIN_CONFIG.bak"
    echo "Removed active $KWIN_CONFIG (backup saved as $KWIN_CONFIG.bak)"
  else
    echo "No kwin output configuration found at $KWIN_CONFIG."
  fi
else
  echo "Warning: SUDO_USER not set, skipping kwin display cache cleanup."
fi

echo "========================================="
echo "Success! The configurations have been updated."
echo "Please reboot your system to apply the new settings."
echo "========================================="
