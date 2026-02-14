#!/usr/bin/env bash
###############################################################################
# setup-ubuntu-vnc.sh
#
# Complete startup script for a fresh Ubuntu 24.04 VM on Google Cloud.
# Replicates the GitHub Actions VNC runner environment:
#   - Creates user 'ubuntu' with password 'mike1969@'
#   - Installs GNOME minimal desktop + TigerVNC
#   - Configures VNC as a systemd service (auto-start on boot)
#   - Installs Tailscale and connects with the provided auth key
#
# Usage:
#   chmod +x setup-ubuntu-vnc.sh
#   sudo ./setup-ubuntu-vnc.sh
#
# After completion, connect via VNC at <tailscale-ip>:5901
###############################################################################
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
TARGET_USER="ubuntu"
TARGET_PASS="mike1969@"
TAILSCALE_AUTH_KEY="tskey-auth-kbKQ7E8qem11CNTRL-DihsruQFFZKRRxd9qToEZKxRMELyZv7J"
VNC_DISPLAY=":1"
VNC_PORT="5901"
VNC_GEOMETRY="1280x800"
VNC_DEPTH="24"
HOSTNAME_TAG="gcloud-ubuntu-vnc"

# ─── Helpers ─────────────────────────────────────────────────────────────────
log()  { echo -e "\n\033[1;32m[✓]\033[0m $*"; }
warn() { echo -e "\n\033[1;33m[!]\033[0m $*"; }
fail() { echo -e "\n\033[1;31m[✗]\033[0m $*"; exit 1; }

# Must run as root
[[ $EUID -eq 0 ]] || fail "Please run this script as root (sudo)."

###############################################################################
# 1. CREATE / CONFIGURE THE TARGET USER
###############################################################################
log "Creating user '${TARGET_USER}' ..."

if ! id -u "${TARGET_USER}" &>/dev/null; then
    adduser --disabled-password --gecos "Ubuntu Desktop User" "${TARGET_USER}"
fi

echo "${TARGET_USER}:${TARGET_PASS}" | chpasswd
usermod -aG sudo "${TARGET_USER}"

# Allow passwordless sudo (optional, convenient for admin)
echo "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${TARGET_USER}"
chmod 0440 "/etc/sudoers.d/${TARGET_USER}"

log "User '${TARGET_USER}' is ready."

###############################################################################
# 2. UPDATE APT & PREVENT SERVICE AUTO-START DURING INSTALL
###############################################################################
log "Updating APT package lists ..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# Prevent services from starting during installation (same as workflow)
echo -e '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

###############################################################################
# 3. PRE-CREATE SYSTEM USERS & DIRECTORIES
###############################################################################
log "Pre-creating system users and directories ..."

for svc in colord gnome-remote-desktop speech-dispatcher; do
    getent group "$svc" >/dev/null || groupadd --system "$svc"
    id -u "$svc" &>/dev/null || adduser --system --home "/var/lib/$svc" --shell /usr/sbin/nologin --ingroup "$svc" "$svc"
    mkdir -p "/var/lib/$svc"
    chown "$svc:$svc" "/var/lib/$svc" || true
    chmod 0755 "/var/lib/$svc" || true
done

mkdir -p /etc/NetworkManager/system-connections
chmod 700 /etc/NetworkManager/system-connections

###############################################################################
# 4. INSTALL GNOME DESKTOP + TIGERVNC + UTILITIES
###############################################################################
log "Installing GNOME desktop, TigerVNC, and utilities (this will take a while) ..."

apt-get -yq install \
    ubuntu-desktop-minimal \
    gnome-session \
    gnome-shell \
    ubuntu-session \
    gnome-terminal \
    tigervnc-standalone-server \
    netcat-openbsd \
    curl \
    x11-xserver-utils \
    xauth \
    dbus-x11 \
    xorg \
    xserver-xorg-core \
    xserver-xorg-input-all \
    xserver-xorg-video-dummy \
    x11-apps \
    policykit-1 \
    colord \
    speech-dispatcher

###############################################################################
# 5. VALIDATE SYSTEM USERS & TMPFILES
###############################################################################
log "Validating system users and tmpfiles ..."
systemd-sysusers  || true
systemd-tmpfiles --create || true

###############################################################################
# 6. RE-ENABLE SERVICE STARTUP
###############################################################################
log "Re-enabling service startup ..."
rm -f /usr/sbin/policy-rc.d

###############################################################################
# 7. CONFIGURE VNC FOR THE TARGET USER
###############################################################################
log "Configuring VNC server for '${TARGET_USER}' ..."

TARGET_HOME=$(eval echo "~${TARGET_USER}")

# Create VNC directory
sudo -u "${TARGET_USER}" mkdir -p "${TARGET_HOME}/.vnc"

# Set VNC password (same as user password for convenience)
echo "${TARGET_PASS}" | sudo -u "${TARGET_USER}" vncpasswd -f > "${TARGET_HOME}/.vnc/passwd"
chmod 600 "${TARGET_HOME}/.vnc/passwd"
chown "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.vnc/passwd"

# Create xstartup
cat > "${TARGET_HOME}/.vnc/xstartup" << 'XSTARTUP'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -r "$HOME/.Xresources" ] && xrdb "$HOME/.Xresources"
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
exec dbus-launch /usr/bin/gnome-session --session=gnome
XSTARTUP
chmod +x "${TARGET_HOME}/.vnc/xstartup"
chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.vnc"

###############################################################################
# 8. CREATE SYSTEMD SERVICE FOR VNC (auto-start on boot)
###############################################################################
log "Creating systemd service for VNC ..."

cat > /etc/systemd/system/vncserver@.service << EOF
[Unit]
Description=TigerVNC Server for display %i
After=syslog.target network.target

[Service]
Type=forking
User=${TARGET_USER}
Group=${TARGET_USER}
WorkingDirectory=${TARGET_HOME}

ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'
ExecStart=/usr/bin/vncserver %i -localhost no -geometry ${VNC_GEOMETRY} -depth ${VNC_DEPTH} -SecurityTypes VncAuth -xstartup ${TARGET_HOME}/.vnc/xstartup
ExecStop=/usr/bin/vncserver -kill %i

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "vncserver@${VNC_DISPLAY}.service"
systemctl start  "vncserver@${VNC_DISPLAY}.service"

log "VNC server started on display ${VNC_DISPLAY} (port ${VNC_PORT})."

###############################################################################
# 9. INSTALL TAILSCALE
###############################################################################
log "Installing Tailscale ..."
curl -fsSL https://tailscale.com/install.sh | sh

###############################################################################
# 10. CONNECT TO TAILSCALE
###############################################################################
log "Connecting to Tailscale ..."
systemctl enable tailscaled
systemctl start  tailscaled
sleep 3

tailscale up --authkey="${TAILSCALE_AUTH_KEY}" --hostname="${HOSTNAME_TAG}"

TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "pending")

###############################################################################
# 11. CONFIGURE FIREWALL (allow VNC through)
###############################################################################
log "Configuring firewall rules ..."
if command -v ufw &>/dev/null; then
    ufw allow "${VNC_PORT}/tcp" || true
    ufw allow in on tailscale0 || true
fi

###############################################################################
# 12. ENABLE SSH PASSWORD AUTH (for convenience)
###############################################################################
log "Enabling SSH password authentication ..."
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config

# Also check sshd_config.d overrides (GCP often puts configs here)
if [ -d /etc/ssh/sshd_config.d ]; then
    for f in /etc/ssh/sshd_config.d/*.conf; do
        [ -f "$f" ] && sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' "$f"
    done
fi

systemctl restart sshd || systemctl restart ssh || true

###############################################################################
# 13. VERIFY
###############################################################################
log "Verifying VNC server ..."
sleep 2
if nc -z -w3 127.0.0.1 "${VNC_PORT}"; then
    log "VNC is listening on port ${VNC_PORT}."
else
    warn "VNC port ${VNC_PORT} is not responding yet. It may need a moment to start."
fi

###############################################################################
# DONE — Print Summary
###############################################################################
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║               SETUP COMPLETE                               ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  SSH Access:                                                ║"
echo "║    User:     ${TARGET_USER}                                 ║"
echo "║    Password: ${TARGET_PASS}                                 ║"
echo "║                                                            ║"
echo "║  VNC Access:                                                ║"
echo "║    Address:  ${TAILSCALE_IP}:${VNC_PORT}                    ║"
echo "║    Password: ${TARGET_PASS}                                 ║"
echo "║    Desktop:  GNOME                                          ║"
echo "║                                                            ║"
echo "║  Tailscale:                                                 ║"
echo "║    Hostname: ${HOSTNAME_TAG}                                ║"
echo "║    IP:       ${TAILSCALE_IP}                                ║"
echo "║                                                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
log "You can now connect via VNC to ${TAILSCALE_IP}:${VNC_PORT}"
log "Or SSH: ssh ${TARGET_USER}@${TAILSCALE_IP}"
