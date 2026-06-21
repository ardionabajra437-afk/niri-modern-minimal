#!/usr/bin/env bash
#
# install.sh — Fresh Arch Linux installer untuk dotfiles Niri desktop
# -----------------------------------------------------------------------------
# Cara pakai (dari Arch yang sudah terinstall base + user sudo):
#   1. Copy/extract folder dotfiles ini ke ~/arch-niri-public-main
#   2. cd ~/arch-niri-public-main
#   3. ./install.sh
# -----------------------------------------------------------------------------

set -euo pipefail

# Lokasi folder dotfiles (di mana install.sh berada)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Warna output
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[0;36m'
C_NC='\033[0m'

log()  { echo -e "${C_CYAN}[install]${C_NC} $*"; }
warn() { echo -e "${C_YELLOW}[warn]${C_NC} $*"; }
err()  { echo -e "${C_RED}[error]${C_NC} $*" >&2; }
ok()   { echo -e "${C_GREEN}[ok]${C_NC} $*"; }

# -----------------------------------------------------------------------------
# Cek environment
# -----------------------------------------------------------------------------
if [[ "$EUID" -eq 0 ]]; then
    err "Jangan jalankan script ini sebagai root. Pakai user biasa yang punya sudo."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    err "sudo belum terinstall. Install dulu: pacman -S sudo"
    exit 1
fi

if ! sudo -n true 2>/dev/null; then
    warn "Kamu akan diminta password sudo beberapa kali selama proses install."
fi

# -----------------------------------------------------------------------------
# Konfirmasi
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  Install Niri desktop dari:"
echo "    $DOTFILES_DIR"
echo "============================================================"
echo ""
read -rp "Lanjutkan install? [Y/n]: " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    log "Dibatalkan."
    exit 0
fi

# -----------------------------------------------------------------------------
# Update sistem + install base tools
# -----------------------------------------------------------------------------
log "Updating sistem..."
sudo pacman -Syu --noconfirm

log "Installing base tools..."
sudo pacman -S --needed --noconfirm base-devel git curl wget jq

# -----------------------------------------------------------------------------
# Install AUR helper (paru)
# -----------------------------------------------------------------------------
install_paru() {
    # Cek apakah paru sudah ada DAN bisa jalan (jangan cuma command -v)
    if command -v paru >/dev/null 2>&1 && paru -V >/dev/null 2>&1; then
        ok "paru sudah terinstall dan berfungsi."
        return 0
    fi

    warn "paru rusak/belum terinstall, rebuild dari source AUR..."

    # Build paru butuh Rust/Cargo
    sudo pacman -S --needed --noconfirm rust

    # Hapus paru/paru-bin lama yang mungkin broken (termasuk paket debug-nya)
    for pkg in paru paru-debug paru-bin paru-bin-debug; do
        if pacman -Qq "$pkg" >/dev/null 2>&1; then
            sudo pacman -Rns --noconfirm "$pkg" || true
        fi
    done

    log "Menginstall paru dari source AUR..."
    local tmpdir
    tmpdir="$(mktemp -d -p /var/tmp)"
    git clone --depth 1 https://aur.archlinux.org/paru.git "$tmpdir/paru"
    (cd "$tmpdir/paru" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"

    if ! paru -V >/dev/null 2>&1; then
        err "Gagal menginstall paru."
        exit 1
    fi
    ok "paru terinstall dari source."
}
install_paru

# -----------------------------------------------------------------------------
# Daftar paket
# -----------------------------------------------------------------------------
official_pkgs=(
    # --- Core Niri / Wayland ---
    niri
    waybar
    xwayland-satellite
    xorg-xwayland

    # --- Notification / Lock / Idle ---
    dunst
    gtklock
    swayidle

    # --- Launcher / Bar / Power menu ---
    fuzzel

    # --- Wallpaper / Screenshot / Clipboard ---
    swaybg
    grim
    slurp
    wl-clipboard

    # --- Audio / Brightness / Media ---
    brightnessctl
    pamixer
    playerctl
    libnotify
    psmisc

    # --- PipeWire audio stack ---
    pipewire
    pipewire-alsa
    pipewire-audio
    pipewire-jack
    pipewire-pulse
    wireplumber
    alsa-utils
    alsa-firmware
    sof-firmware

    # --- Network / Bluetooth ---
    networkmanager
    network-manager-applet
    iwd
    wpa_supplicant
    bluez
    bluez-utils
    blueman

    # --- Terminal / Shell / Tools ---
    foot
    fish
    helix
    yazi
    eza
    fzf
    fastfetch
    imagemagick
    pacman-contrib

    # --- GUI apps ---
    firefox
    pavucontrol
    nautilus
    mousepad
    vlc
    file-roller
    p7zip
    unzip
    zip

    # --- Theming / Fonts ---
    adwaita-fonts
    adwaita-cursors
    adwaita-icon-theme
    adwaita-icon-theme-legacy
    cantarell-fonts
    adobe-source-code-pro-fonts
    gnu-free-fonts
    ttf-nerd-fonts-symbols
    papirus-icon-theme

    # --- Graphics / QT ---
    mesa
    vulkan-icd-loader
    qt5-wayland
    qt6-wayland

    # --- Portals / Polkit / Keyring ---
    polkit-gnome
    gnome-keyring
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gnome

    # --- XDG / Dirs ---
    xdg-user-dirs
    xdg-user-dirs-gtk
    xdg-utils

    # --- Display manager ---
    ly

    # --- Power profile ---
    tuned
    tuned-ppd
)

aur_pkgs=(
    tokyonight-gtk-theme-git
    wlogout
    fisher-git
    fish-tide-git
)

# -----------------------------------------------------------------------------
# Install paket official
# -----------------------------------------------------------------------------
log "Installing paket dari repository Arch..."
sudo pacman -S --needed --noconfirm "${official_pkgs[@]}"
ok "Paket official selesai."

# Set NetworkManager pakai iwd supaya Wi-Fi lebih cepat
log "Mengatur NetworkManager menggunakan iwd..."
sudo mkdir -p /etc/NetworkManager
sudo tee /etc/NetworkManager/NetworkManager.conf >/dev/null <<'EOF'
[device]
wifi.backend=iwd
EOF

# -----------------------------------------------------------------------------
# Install paket AUR
# -----------------------------------------------------------------------------
log "Installing paket dari AUR..."
paru -S --needed --noconfirm --skipreview --noprovides "${aur_pkgs[@]}"
ok "Paket AUR selesai."

# -----------------------------------------------------------------------------
# Copy dotfiles ke ~/.config
# -----------------------------------------------------------------------------
log "Menyalin konfigurasi ke ~/.config..."
mkdir -p "$HOME/.config"
cp -aT "$DOTFILES_DIR/.config" "$HOME/.config"
ok "Konfigurasi disalin."

# Bersihkan kemungkinan CRLF kalau file diekstrak dari Windows
log "Membersihkan line-ending Windows (CRLF)..."
find "$HOME/.config" -type f \( \
    -name "*.sh" -o -name "*.kdl" -o -name "*.ini" -o -name "*.toml" \
    -o -name "*.jsonc" -o -name "*.conf" -o -name "*.css" -o -name "*.fish" \
    -o -name "*.list" -o -name "layout" \
\) -exec sed -i 's/\r$//' {} +

# Wrapper checkupdates-with-aur (paket asli tidak ada lagi di AUR)
log "Membuat wrapper checkupdates-with-aur..."
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/checkupdates-with-aur" <<'EOF'
#!/usr/bin/env bash
# Fallback karena paket checkupdates-with-aur sudah tidak tersedia di AUR
# Output digabung dari repo official + AUR, cocok untuk waybar-updates.sh
checkupdates 2>/dev/null
paru -Qua 2>/dev/null
EOF
chmod +x "$HOME/.local/bin/checkupdates-with-aur"

# -----------------------------------------------------------------------------
# Buat symlink tema (dark sebagai default)
# -----------------------------------------------------------------------------
log "Setup symlink tema..."
cd "$HOME/.config"

# Hapus file placeholder kalau ada (misal hasil extract di Windows yang rusin symlinknya)
[[ -e "dunst/dunstrc" ]] && rm -f "dunst/dunstrc"
[[ -e "gtk-3.0/settings.ini" ]] && rm -f "gtk-3.0/settings.ini"
for f in colors-foot.ini colors-fuzzel.ini colors-waybar.css; do
    [[ -e "themes/$f" ]] && rm -f "themes/$f"
done
[[ -e "themes/wlogout-icons" ]] && rm -rf "themes/wlogout-icons"

# Buat symlink
ln -sf ../themes/dark/dunstrc dunst/dunstrc
ln -sf ../themes/dark/settings.ini gtk-3.0/settings.ini
ln -sf dark/colors-foot.ini themes/colors-foot.ini
ln -sf dark/colors-fuzzel.ini themes/colors-fuzzel.ini
ln -sf dark/colors-waybar.css themes/colors-waybar.css
ln -sf dark/wlogout-icons themes/wlogout-icons

ok "Symlink tema selesai."

# -----------------------------------------------------------------------------
# Buat direktori yang dibutuhkan
# -----------------------------------------------------------------------------
log "Membuat direktori user..."
mkdir -p "$HOME/.config/current"
mkdir -p "$HOME/Pictures/wallpapers/active"
mkdir -p "$HOME/Pictures/Screenshots"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/bin"

# Update XDG user dirs
xdg-user-dirs-update

# -----------------------------------------------------------------------------
# Wallpaper default (agar set-random-wallpaper.sh tidak error)
# -----------------------------------------------------------------------------
if [[ ! -f "$HOME/Pictures/wallpapers/active/default.jpg" ]]; then
    log "Membuat wallpaper default..."
    convert -size 1920x1080 "xc:#1A1B26" "$HOME/Pictures/wallpapers/active/default.jpg" || \
        warn "Gagal membuat wallpaper default."
fi

# -----------------------------------------------------------------------------
# Executable bit untuk scripts
# -----------------------------------------------------------------------------
log "Mengatur permission scripts..."
chmod +x "$HOME/.config/scripts/"*.sh

# -----------------------------------------------------------------------------
# GSettings (theme, icon, font, cursor)
# -----------------------------------------------------------------------------
log "Mengatur tema GTK / icon / font / cursor..."

# Wrapper supaya gsettings tetap jalan walau belum ada sesi D-Bus
run_with_dbus() {
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        "$@"
    else
        dbus-run-session -- "$@"
    fi
}

run_with_dbus gsettings set org.gnome.desktop.interface gtk-theme 'Tokyonight-Dark'
run_with_dbus gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
run_with_dbus gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
run_with_dbus gsettings set org.gnome.desktop.interface cursor-size 24
run_with_dbus gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 10'
run_with_dbus gsettings set org.gnome.desktop.interface document-font-name 'Adwaita Sans 10'
run_with_dbus gsettings set org.gnome.desktop.interface monospace-font-name 'Adwaita Mono 10'
run_with_dbus gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

ok "Tema GTK diset ke Tokyonight-Dark."

# -----------------------------------------------------------------------------
# Portal config untuk Niri
# -----------------------------------------------------------------------------
log "Membuat config xdg-desktop-portal untuk Niri..."
mkdir -p "$HOME/.config/xdg-desktop-portal"
cat > "$HOME/.config/xdg-desktop-portal/portals.conf" <<'EOF'
[preferred]
default=gtk
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.ScreenCast=wlr
EOF

# -----------------------------------------------------------------------------
# Fish shell default (opsional)
# -----------------------------------------------------------------------------
echo ""
read -rp "Jadikan fish sebagai shell default? [Y/n]: " setfish
if [[ ! "$setfish" =~ ^[Nn]$ ]]; then
    if command -v fish >/dev/null 2>&1; then
        log "Mengubah shell default ke fish..."
        if chsh -s /usr/bin/fish; then
            ok "Shell default diubah ke fish (aktif setelah login ulang)."
        else
            warn "Gagal mengubah shell default. Ubah manual nanti dengan: chsh -s /usr/bin/fish"
        fi
    else
        warn "fish tidak ditemukan, skip mengubah shell."
    fi
else
    log "Shell default tidak diubah."
fi

# -----------------------------------------------------------------------------
# Enable systemd services
# -----------------------------------------------------------------------------
log "Mengaktifkan service sistem..."
sudo systemctl enable NetworkManager.service
sudo systemctl enable bluetooth.service
sudo systemctl enable tuned.service
sudo systemctl enable ly@tty2.service
sudo systemctl disable getty@tty2.service || true

log "Mengaktifkan service user (pipewire, wireplumber, dunst)..."
systemctl --user enable pipewire.socket
systemctl --user enable pipewire.service
systemctl --user enable pipewire-pulse.socket
systemctl --user enable wireplumber.service
systemctl --user enable dunst.service

# Start service yang aman di-start sekarang
sudo systemctl start NetworkManager.service || true
sudo systemctl start bluetooth.service || true
sudo systemctl start tuned.service || true
systemctl --user start pipewire.socket pipewire.service pipewire-pulse.socket wireplumber.service || true
systemctl --user start dunst.service || true

ok "Service diaktifkan."

# -----------------------------------------------------------------------------
# Install Flatpak + aplikasi dari flatpaks.list
# -----------------------------------------------------------------------------
log "Setup Flatpak..."
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

log "Installing Flatpak apps..."
flatpak install -y --user flathub \
    app.zen_browser.zen \
    com.belmoussaoui.Authenticator \
    com.bitwarden.desktop \
    com.discordapp.Discord \
    com.github.tchx84.Flatseal \
    com.obsproject.Studio \
    com.spotify.Client \
    com.vscodium.codium \
    de.haeckerfelix.Shortwave \
    md.obsidian.Obsidian \
    net.nokyan.Resources \
    org.gabmus.gfeeds \
    org.gnome.Calculator \
    org.gnome.seahorse.Application \
    org.inkscape.Inkscape \
    org.kde.krita

ok "Flatpak selesai."

# -----------------------------------------------------------------------------
# Selesai
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo -e "  ${C_GREEN}Install selesai!${C_NC}"
echo "============================================================"
echo ""
echo "Langkah selanjutnya:"
echo "  1. Edit monitor di ~/.config/niri/config.kdl (bagian output)."
echo "  2. Taruh wallpaper favorit di ~/Pictures/wallpapers/active/."
echo "  3. Jika pakai fish, jalankan:  tide configure"
echo "  4. Reboot, lalu login lewat ly (pilih Niri)."
echo ""
echo "Keyboard shortcuts penting:"
echo "  Mod+Return  -> Foot terminal"
echo "  Mod+D       -> Fuzzel launcher"
echo "  Mod+E       -> Nautilus file manager"
echo "  Mod+Esc     -> Wlogout power menu"
echo "  Ctrl+Alt+T  -> Switch dark/light theme"
echo ""
