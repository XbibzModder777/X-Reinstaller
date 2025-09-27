#!/bin/bash
# ============================================
# Author :           Xbibz Official
# YT     :           @XbibzOfficial
# TikTok :           @xbibzofficiall
# Github :           github.com/XbibzOfficial
#
# Versi  :           3.4
# 
# ============================================


set -euo pipefail
shopt -s lastpipe


ISO_URL="https://cdimage.kali.org/kali-2024.3/kali-linux-2024.3-installer-amd64.iso"
ISO_SUM_URL="https://cdimage.kali.org/kali-2024.3/SHA256SUMS"
ISO_NAME="${ISO_URL##*/}"
LOG_FILE="/var/log/xreinstaller.log"


C_RESET='\033[0m'
C_BOLD='\033[1m'

C_RED='\033[0;31m';   C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m';
C_BLUE='\033[0;34m';  C_PURPLE='\033[0;35m';C_CYAN='\033[0;36m';

C_B_RED='\033[1;31m'; C_B_GREEN='\033[1;32m';C_B_YELLOW='\033[1;33m';
C_B_BLUE='\033[1;34m';C_B_PURPLE='\033[1;35m';C_B_CYAN='\033[1;36m';

log_info()  { echo -e "${C_B_BLUE}[INFO]${C_RESET}  $*" | tee -a "$LOG_FILE"; }
log_sukses(){ echo -e "${C_B_GREEN}[SUKSES]${C_RESET} $*" | tee -a "$LOG_FILE"; }
log_gagal() { echo -e "${C_B_RED}[GAGAL]${C_RESET} $*" | tee -a "$LOG_FILE"; exit 1; }
log_warn()  { echo -e "${C_B_YELLOW}[PERINGATAN]${C_RESET} $*" | tee -a "$LOG_FILE"; }


cek_root() {
    [[ $EUID -eq 0 ]] || log_gagal "Skrip ini harus dijalankan dengan sudo atau sebagai root."
}

cek_lingkungan() {
    log_info "Memeriksa lingkungan eksekusi..."
    
    if ! (ls /dev/sd* >/dev/null 2>&1 || ls /dev/nvme* >/dev/null 2>&1); then
        log_warn "Lingkungan tidak didukung terdeteksi (misalnya Termux, UserLAnd)."
        echo -e "\n${C_B_RED}SKRIP INI TIDAK BISA DIJALANKAN DI SINI!${C_RESET}" >&2
        echo -e "Skrip ini dirancang untuk mengelola partisi dan bootloader pada ${C_BOLD}PC atau Laptop${C_RESET}." >&2
        echo -e "Lingkungan seperti UserLAnd atau Termux di Android tidak memiliki akses ke perangkat keras tersebut." >&2
        echo -e "Silakan jalankan skrip ini dari sistem Linux di PC/Laptop Anda (misalnya dari Live USB)." >&2
        exit 1
    fi
    log_sukses "Lingkungan PC/Laptop terdeteksi. Melanjutkan..."
}


cek_dependensi() {
    log_info "Memeriksa dependensi yang diperlukan..."
    local missing_deps=()
    local deps=("wget" "sha256sum" "lsblk" "dd" "wipefs" "grub-mkconfig" "update-grub" "rsync" "awk" "grep" "parted" "lscpu" "free")
    for cmd in "${deps[@]}"; do
        command -v "$cmd" &>/dev/null || missing_deps+=("$cmd")
    done
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_gagal "Perintah berikut tidak ditemukan: ${missing_deps[*]}. Harap install terlebih dahulu."
    fi
    log_sukses "Semua dependensi terpenuhi."
}


konfirmasi_aksi() {
    local prompt_msg="$1"
    local device_info="$2"
    echo -e "${C_B_YELLOW}PERINGATAN:${C_RESET} Aksi ini berisiko dan dapat ${C_B_RED}MENGHAPUS DATA${C_RESET} secara permanen."
    echo -e "Target: ${C_B_CYAN}${device_info}${C_RESET}"
    read -p "$(echo -e "${prompt_msg} (ketik '${C_B_RED}YA${C_RESET}' untuk melanjutkan): ")" konfirmasi
    if [[ "$konfirmasi" != "YA" ]]; then
        log_info "Aksi dibatalkan oleh pengguna."
        return 1
    fi
    return 0
}


menu_utama() {
  clear
  cat << "EOF"
  
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣀⣀⣀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠻⣿⣿⣿⣿⣦⣄⠀⠀⠠⠰⠶⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣤⣤⡤⢀⣴⣿⣿⣿⠏⠀⠋⢉⣠⣿⣿⣿⣿⣿⣿⣿⣤⣄⡀⠈⠙⢿⣿⣿⣿⣧⡀⠐⠻⣶⣶⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⠟⠁⠉⢠⣾⣿⣿⡿⠁⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣄⠈⠻⣿⣿⣿⣷⡄⠀⢀⠙⢿⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⠟⢁⡔⠀⣠⣿⣿⣿⡿⠁⣠⣾⣿⣿⠛⣻⣿⣿⡿⠁⠹⣿⣿⣿⣿⣿⣿⣿⣦⡀⠹⣿⣿⣿⣿⡀⠈⢧⡈⢳⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡟⢠⡿⠀⢰⣿⣿⣿⡿⠁⣼⣿⣿⡿⠃⣼⣿⠏⠀⠁⣴⣆⠈⠉⠙⢿⣿⣿⣿⣿⣷⡄⢹⣿⣿⣿⣷⠀⠀⢷⡈⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠐⢠⣿⠃⠀⣿⣿⣿⣿⠃⣸⣿⣿⠟⢀⣾⠿⠋⠀⢠⣾⣿⣿⣷⣄⠀⠀⠙⢿⣿⣿⣿⣷⠀⣿⣿⣿⣿⡄⢣⠘⣇⠘⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⡟⠀⢰⣿⣿⣿⡟⢀⣿⠟⠀⠰⠛⠋⠀⢠⣾⣿⣿⣿⣿⣿⡿⠟⠂⣀⠀⠉⠙⢿⣿⡇⢸⣿⣿⣿⣇⠘⡄⢹⡀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣿⡇⠀⠸⣿⣿⣿⡇⠈⠁⠀⠀⡀⠀⢀⣀⣤⣿⣿⣿⣿⣿⣿⣷⣤⣍⣉⣁⣤⣤⣀⠙⠓⠘⣿⣿⣿⣿⠀⣇⢸⣿⣿⡆⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣾⣿⠁⠀⠀⣿⣿⣿⡇⢠⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⠀⣿⠻⣿⠛⡆⢻⠸⣿⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⠀⡆⠀⣿⣿⠙⡇⢸⣿⣿⡿⠿⠟⠋⠙⢻⣿⣿⣿⣿⣿⣿⣿⣿⠛⠙⠛⠿⢿⣿⣿⣿⠀⡟⠀⣿⠀⡇⢈⣀⠛⠛⠻⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⡀⠀⠀⠀⠀⠀⠀⠀⣀⣀⡀⠀⠀⢻⣿⡆⢁⠘⣿⣿⣇⣀⣀⣀⣠⣼⣿⣿⣿⣿⣿⣿⣿⣿⣦⣀⣀⠀⢠⣿⣿⣿⠀⠇⢰⣿⠀⡇⢠⣌⣉⣉⠓⠒⠶⠶⠤⠤⣤⣀⠀
⠀⠈⠓⠶⢄⠐⠲⠀⡄⢾⣿⣿⣿⣧⠀⠘⣿⡇⠘⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⢸⣿⠀⠁⢸⣿⣿⣿⠇⢰⣀⣄⠠⠒⠉⠀⠀
⠀⠀⠀⠀⠀⠀⠘⠛⠇⠀⠹⣿⣿⣿⡄⠀⠹⣷⠀⠁⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⣿⡏⠀⠀⣾⡿⠟⠋⠀⠀⠉⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡀⠀⠉⣙⠛⠀⠀⠙⡆⠀⠀⢻⣿⣿⣿⣿⣿⣿⡿⠿⣿⠿⠿⣿⠿⣿⣿⣿⣿⣿⣿⣿⣇⢀⡾⠀⠇⠀⠀⢀⡠⠄⢀⣠⣶⡇⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣷⡆⠉⠀⠀⠀⠀⠀⠀⠀⢺⣿⣿⣿⣿⣿⣿⣿⣶⣶⣶⣶⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⡿⠁⠀⠀⠀⠀⠈⢠⣶⣿⣿⣿⣷⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⡄⠀⠀⠸⣿⠀⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠟⠀⠀⠀⣾⠁⠀⣠⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣷⠀⠘⡀⢻⡀⠀⠀⠀⠈⠙⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠟⠉⠀⠀⠀⠀⠀⠃⠀⢰⣿⣿⣿⠀⣿⣿⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⠸⣿⣿⡀⠀⣧⠘⡇⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⠿⠿⢿⣿⠿⠿⠛⠋⠁⠀⠀⠀⠀⣀⣀⡀⠀⠀⠀⢸⣿⣿⡿⢰⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⡀⣿⣿⣇⠀⢿⡄⠃⢸⣿⣿⠀⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⣤⣾⡇⠈⣿⣿⣿⠀⠀⠀⢸⣿⣿⡇⢸⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠘⠀⣿⡇⣿⣿⣿⡆⠸⣧⠀⠀⣿⡇⠀⠀⠀⠀⠀⠀⠀⠐⣶⣶⣶⣿⣿⣿⣿⣿⡿⠋⠁⠀⣿⣿⡇⠀⠀⠀⣼⣿⣿⡇⠈⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠘⠀⣿⡇⣿⣿⣿⣷⠀⢿⡀⠀⣿⣇⠀⠱⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⠿⠛⢉⡠⠚⠀⢰⣿⣿⡇⠀⠀⠀⣿⣿⣿⡇⠀⠀⣠⡀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢰⡆⠀⢹⡇⢹⣿⣿⣿⡇⠸⡇⠀⢸⣿⡄⠀⢄⣉⠛⠒⠒⠦⠤⠤⠤⠤⠒⠒⠉⣁⣤⠂⠀⣸⣿⣿⠇⢨⡰⢀⣿⣿⣿⡇⠀⣰⣿⣷⡀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢠⣿⡇⠀⠸⡇⢸⣿⣿⣿⣿⠀⣿⠀⢸⣿⣷⠀⠘⣿⣿⡏⡠⠀⣴⠂⣤⠀⣶⠈⣆⠸⠃⠈⢠⣿⣿⣿⠀⣿⡇⢸⣿⣿⣿⡇⢠⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢠⣿⣿⣿⠀⠀⣧⠸⣿⣿⣿⣿⡇⢸⡇⠀⣿⣿⣇⠀⠘⣿⡇⡇⢸⣿⢠⣿⠄⢿⠀⣿⠀⠀⣠⣿⣿⣿⡟⢠⣿⠃⣼⣿⣿⣿⡇⣾⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⣼⣿⣿⣿⡇⠀⢸⠀⣿⣿⣿⣿⣿⠈⣿⠀⢿⣿⣿⣄⠁⢘⠀⡄⢸⣿⠈⢀⠀⢘⡀⢻⠀⣴⣿⣿⣿⣿⡇⢸⣿⣤⣿⣿⣿⣿⡇⣿⣿⠛⣿⣿⣿⣆⠀⠀⠀⠀
⠀⠀⠀⠀⢠⣿⣿⠃⣸⣿⠀⠸⡄⢻⣿⣿⣿⣿⡄⢻⡆⢸⣿⣿⣿⣿⣿⠀⠃⢈⡇⠀⢸⡄⠈⣇⠘⡆⢻⣿⣿⣿⣿⠁⣾⠇⣼⣿⣿⣿⣿⡇⣿⣿⡆⠘⣿⣿⣿⡆⠀⠀⠀
⠀⠀⠀⢀⣾⣿⡏⢀⣿⣿⡇⠀⡇⠸⣿⣿⣿⣿⣇⠸⣧⢸⣿⣿⣿⣿⡇⢸⠀⣿⠇⠀⠉⠉⠀⢿⡀⢳⠸⣿⣿⣿⣿⠀⡿⠀⣿⣿⣿⡏⢹⡇⣿⣿⣧⠀⠸⣿⣿⣿⡄⠀⠀
⠀⠀⠀⣼⣿⡿⠀⣼⣿⣿⣿⠀⢱⣶⣿⣿⣿⣿⣿⠀⣿⠈⣿⣿⣿⣿⡇⠈⠀⣿⠀⠀⠀⠀⠀⠸⡇⠸⡀⢿⣿⣿⡏⢰⠃⠀⣿⣿⣿⣧⢸⡇⣿⣿⣿⡆⠀⢹⣿⣿⣿⡀⠀
⠀⠀⢠⣿⣿⠁⢠⣿⣿⣿⣿⡄⢸⡇⢻⣿⣿⣿⣿⡆⠀⠃⣿⣿⣿⣿⠀⣾⢸⡿⢀⣤⣤⣤⣤⠀⢿⠀⡇⠸⣿⣿⡇⠘⢠⠀⣿⣿⣿⣿⢸⡇⢹⣿⣿⣷ ⠀⢿⣿⣿⣧⠀
⠀⠀⣾⣿⠏⠀⣼⣿⣿⣿⣿⡇⢸⡇⢸⣿⣿⣿⣿⡇⠀⠀⢻⣿⣿⣿⠀⠉⢸⡇⢸⣿⣿⣿⣿⡇⠸⡇⢻⡀⢿⣿⡇⠀⠀⠀⣿⣿⣿⡇⢸⡇⣼⣿⣿⣿⣿⣇⠀⠘⣿⣿⣿⣧
⠀⣸⣿⡟⠀⢠⣿⣿⣿⣿⣿⣿⠈⡇⠈⣿⣿⣿⣿⣷⡆⠀⢸⣿⣿⡏⢠⡇⣼⠃⠀⠀⠀⠀⠀⠀⠀⣷⠘⡇⠸⣿⡇⢀⠀⠀⣿⣿⣿⡇⠈⡇⣿⣿⣿⣿⣿⡄⢆⠸⣿⣿⣿
⢠⣿⣿⠁⡌⢸⣿⣿⣿⣿⣿⣿⠀⡇⠀⢿⣿⣿⣿⣿⡇⠀⢸⣿⣿⡇⢘⠇⣿⠀⠀⠀⠀⠀⠀⠀⠀⠸⡀⢻⠀⢿⣷⠈⠀⠀⣿⣿⣿⠇⠀⡇⣿⣿⣿⣿⣿⣷⠘⡄⢹⣿⣿
⣿⣿⠇⢸⠇⣿⣿⣿⣿⣿⣿⣿⠀⡇⠀⠸⣿⣿⣿⣿⡇⠀⢸⣿⣿⠇⣘⠀⡟⢠⣤⣤⣤⣤⣤⣴⣶⠀⡇⠸⡇⢸⣿⡀⠀⠀⢿⣿⣿⠀⠀⠃⣿⣿⣿⣿⣿⣿⡄⢹⡀⢿⣿
⠙⠿⢠⣿⠀⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⢻⣿⣿⣿⠀⠀⣾⣿⣿⠀⣿⠀⡇⢸⣿⣿⣿⣿⠿⠿⠿⡇⢸⠀⢻⠈⣿⣧⠀⠀⢸⣿⡏⠠⠀⢰⣿⣿⣿⣿⣿⣿⣷⠀⢷⣸⠟
⠷⠄⠈⠋⢠⣿⣿⣿⣿⣿⣿⣿⣷⠀⠀⠀⠈⢿⣿⡟⠀⠀⣿⣿⣿⠀⠋⢀⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⡇⠸⡇⢻⣿⣷⡄⠀⣿⠃⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣇⠈⠀⠲
⣦⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⢰⡄⠈⢻⠇⠀⢸⣿⣿⣿⠸⡇⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢿⠀⢧⠈⣿⣿⣷⡄⠘⢠⡆⢀⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀
⠉⠀⠀⠀⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⠈⢿⣦⡈⠀⣠⣿⣿⣿⡟⢠⠇⠘⠀⣤⣤⣤⣤⣤⣤⣤⣤⣴⡆⠸⡇⢸⡄⢹⣿⣿⡷⠀⣿⣧⣼⣿⣿⣿⣿⣿⡿⠟⢉⣤⠂⠀⠀
⠀⠀⠀⠀⠲⢤⣉⠛⠻⠿⣿⣿⣿⣿⣿⣶⣼⣿⣷⣀⣹⣿⣿⣿⡇⣼⠀⣿⠀⠛⠛⠛⠛⠋⠋⠉⠉⠉⠉⠀⢿⠈⣧⠈⣿⣿⣿⣿⣿⣿⣿⣿⠿⠟⠋⣁⣤⠶⠋⣀⠴⠀⠀
⠀⠀⠀⠀⠐⠂⠌⠉⠓⠒⠦⠤⠍⠉⠉⠙⠛⠛⠛⠻⠿⠿⠿⠿⠇⠿⠀⠿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⠇⠹⠄⠹⠿⠿⠿⠟⠋⠉⠤⠶⠚⠋⠉⠤⠔⠊⠁⠀⠀⠀
EOF
  echo -e "${C_B_PURPLE}Author : Xbibz Official ${C_RESET}"
  echo -e "${C_CYAN}=====================================================${C_RESET}"
  echo -e " ${C_B_YELLOW}1)${C_RESET} ${C_BOLD}Install Baru Kali${C_RESET} (Buat USB bootable)"
  echo -e " ${C_B_YELLOW}2)${C_RESET} ${C_BOLD}Uninstall Kali${C_RESET} (Hapus partisi + entri boot)"
  echo -e " ${C_B_YELLOW}3)${C_RESET} ${C_BOLD}Reinstall Kali${C_RESET} (Backup home -> Hapus -> Install)"
  echo -e " ${C_B_CYAN}4)${C_RESET} ${C_BOLD}Migrasi dari Ubuntu ke Kali Linux${C_RESET}"
  echo -e " ${C_B_YELLOW}5)${C_RESET} ${C_BOLD}Tampilkan Info Sistem${C_RESET}"
  echo -e " ${C_B_RED}6)${C_RESET} ${C_BOLD}Keluar${C_RESET}"
  echo -e "${C_CYAN}=====================================================${C_RESET}"
  read -p "Pilih opsi [1-6] : " PIL

  case "$PIL" in
    1) install_baru ;;
    2) uninstall_kali ;;
    3) reinstall_full ;;
    4) migrasi_ubuntu_ke_kali ;;
    5) tampilkan_info_sistem; menu_utama ;;
    6) log_info "Terima kasih telah menggunakan skrip ini!"; exit 0 ;;
    *) log_warn "Pilihan tidak valid."; sleep 2; menu_utama ;;
  esac
}

tampilkan_info_sistem() {
    clear
    echo -e "${C_B_CYAN}=============== INFO SISTEM & PERANGKAT ===============${C_RESET}"
    echo -e "${C_B_PURPLE}OS & Kernel:${C_RESET}"
    echo -e "  - OS      : $(grep PRETTY_NAME /etc/os-release | cut -d'=' -f2 | tr -d '"')"
    echo -e "  - Kernel  : $(uname -r)"
    echo -e "  - Arsitek : $(uname -m)"
    echo ""
    echo -e "${C_B_PURPLE}CPU & RAM:${C_RESET}"
    echo -e "  - CPU     : $(lscpu | grep "Model name" | sed 's/Model name:\s*//')"
    echo -e "  - Core(s) : $(lscpu | grep "^CPU(s):" | awk '{print $2}')"
    echo -e "  - RAM     : $(free -h | grep Mem | awk '{print $2}')"
    echo ""
    echo -e "${C_B_PURPLE}Penyimpanan (Disks & Partisi):${C_RESET}"
    lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT
    echo -e "${C_B_CYAN}========================================================${C_RESET}"
    read -p "Tekan [Enter] untuk kembali ke menu utama..."
}


download_iso() {
    log_info "Memeriksa file ISO Kali Linux..."
    if [[ -f "$ISO_NAME" ]]; then
        log_warn "File ISO '${ISO_NAME}' sudah ada. Melewatkan download."
        return
    fi
    log_info "Mulai download ISO dari ${ISO_URL}..."
    wget -q --show-progress -O "$ISO_NAME" "$ISO_URL"
    log_sukses "Download ISO selesai."
}

verify_iso() {
    log_info "Memverifikasi checksum SHA256 untuk ISO..."
    log_info "Mendownload file checksum dari ${ISO_SUM_URL}"
    wget -q -O SHA256SUMS "$ISO_SUM_URL"
    if grep -q "$ISO_NAME" SHA256SUMS; then
        sha256sum -c <(grep "$ISO_NAME" SHA256SUMS) || log_gagal "Verifikasi Checksum gagal! File ISO mungkin korup."
        log_sukses "Verifikasi Checksum berhasil. ISO valid."
    else
        log_gagal "Tidak dapat menemukan checksum untuk ${ISO_NAME} di file sumber."
    fi
    rm SHA256SUMS
}


pilih_usb_otomatis() {
    log_info "Mendeteksi perangkat USB yang terhubung..."
    mapfile -t usb_drives < <(lsblk -d -o NAME,TRAN | grep -i usb | awk '{print "/dev/"$1}')

    if [[ ${#usb_drives[@]} -eq 0 ]]; then
        log_gagal "Tidak ada perangkat USB yang terdeteksi."
    elif [[ ${#usb_drives[@]} -eq 1 ]]; then
        USB_DEV=${usb_drives[0]}
        log_info "Satu perangkat USB terdeteksi: ${USB_DEV}"
        lsblk -pn -o NAME,SIZE,VENDOR,MODEL "${USB_DEV}"
    else
        log_info "Beberapa perangkat USB terdeteksi. Silakan pilih satu:"
        select dev in "${usb_drives[@]}"; do
            if [[ -n "$dev" ]]; then
                USB_DEV=$dev
                break
            else
                log_warn "Pilihan tidak valid."
            fi
        done
    fi
    
    local dev_info
    dev_info=$(lsblk -pn -o SIZE,VENDOR,MODEL "${USB_DEV}" | tail -n1)
    if ! konfirmasi_aksi "Anda yakin ingin mem-flash ISO ke ${USB_DEV}?" "${dev_info}"; then
        menu_utama
    fi
}

flash_usb() {
    log_info "Memulai proses flashing ISO ke ${USB_DEV}. Ini akan memakan waktu..."
    if ! dd if="$ISO_NAME" of="$USB_DEV" bs=4M status=progress conv=fdatasync; then
        log_gagal "Gagal saat flashing ke ${USB_DEV}. Periksa log untuk detail."
    fi
    log_sukses "Pembuatan USB bootable selesai!"
}


hapus_partisi_dan_update_grub() {
    local partitions_to_delete=("$@")
    if [[ ${#partitions_to_delete[@]} -eq 0 ]]; then
        log_warn "Tidak ada partisi yang dipilih untuk dihapus."
        return 1
    fi

    log_info "Partisi yang akan dihapus: ${partitions_to_delete[*]}"
    if ! konfirmasi_aksi "ANDA YAKIN ingin MENGHAPUS SEMUA partisi ini secara permanen?" "${partitions_to_delete[*]}"; then
        return 1
    fi

    for p in "${partitions_to_delete[@]}"; do
        log_warn "Menghapus partisi ${p}..."
        umount "$p" 2>/dev/null || true
        if ! wipefs -a "$p"; then
            log_warn "Gagal menghapus signature pada ${p}, mencoba menghapus partisi dengan 'parted'..."
            local disk
            disk=$(lsblk -pn -o PKNAME "$p" | tail -n 1)
            local part_num
            part_num=$(echo "$p" | sed 's/.*[^0-9]\([0-9]*\)$/\1/')
            parted -s "$disk" rm "$part_num"
        fi
        log_sukses "Partisi ${p} telah dihapus."
    done

    log_info "Memperbarui konfigurasi GRUB..."
    if command -v update-grub &>/dev/null; then
        update-grub
    else
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
    log_sukses "GRUB telah diperbarui."
    return 0
}



uninstall_kali() {
    cek_root
    log_info "Mencari partisi Kali Linux..."
    mapfile -t KALI_PARTS < <(lsblk -pn -o NAME,LABEL | grep -i "kali" | awk '{print $1}')
    
    if [[ ${#KALI_PARTS[@]} -eq 0 ]]; then
        log_info "Label 'kali' tidak ditemukan, mencoba metode deteksi mendalam..."
        local all_parts
        all_parts=$(lsblk -pn -o NAME,FSTYPE | grep "ext4" | awk '{print $1}')
        for p in $all_parts; do
            local mnt_point
            mnt_point=$(mktemp -d)
            if mount -o ro "$p" "$mnt_point" 2>/dev/null; then
                if [[ -f "$mnt_point/etc/os-release" ]] && grep -qi "ID=kali" "$mnt_point/etc/os-release"; then
                    KALI_PARTS+=("$p")
                fi
                umount "$mnt_point"
            fi
            rmdir "$mnt_point"
        done
    fi

    if [[ -z "${KALI_PARTS[*]}" ]]; then
        log_gagal "Tidak dapat menemukan partisi Kali Linux."
    fi
    
    log_info "Ditemukan partisi Kali Linux: ${KALI_PARTS[*]}"
    if hapus_partisi_dan_update_grub "${KALI_PARTS[@]}"; then
        log_sukses "Uninstall Kali Linux selesai."
    else
        log_info "Proses uninstall dibatalkan."
    fi
}


backup_home_kali() {
    log_info "Tampilkan daftar partisi untuk membantu identifikasi:"
    lsblk -f
    log_info "Harap masukkan path partisi /home dari instalasi KALI Anda."
    read -p "Masukkan partisi /home (contoh: /dev/sda3): " HOME_PART
    
    if [[ ! -b "$HOME_PART" ]]; then
        log_gagal "Device partisi tidak valid."
        return 1
    fi

    local MNT_BAK="/mnt/kali_home_backup"
    local BACKUP_DIR="/root/kali_home_backup_$(date +%F_%H-%M)"
    
    log_info "Membuat backup dari ${HOME_PART} ke ${BACKUP_DIR}..."
    mkdir -p "$MNT_BAK"
    if ! mount "$HOME_PART" "$MNT_BAK"; then
        log_gagal "Gagal me-mount partisi home."
    fi
    
    mkdir -p "$BACKUP_DIR"
    log_info "Menyalin file dengan rsync (ini bisa lama)..."
    if ! rsync -a --info=progress2 "$MNT_BAK/" "$BACKUP_DIR/"; then
        umount "$MNT_BAK"
        log_gagal "Proses rsync (backup) gagal."
    fi
    
    umount "$MNT_BAK"
    rmdir "$MNT_BAK"
    log_sukses "Backup partisi /home selesai dan disimpan di ${BACKUP_DIR}"
    return 0
}

reinstall_full() {
    cek_root
    log_info "Memulai mode REINSTALL: Backup Home -> Uninstall -> Install Baru"
    backup_home_kali || return
    uninstall_kali || return
    install_baru
}


backup_home_ubuntu() {
    log_info "LANGKAH 1: BACKUP DATA UBUNTU"
    log_info "Tampilkan daftar partisi untuk membantu identifikasi:"
    lsblk -f
    log_info "Harap masukkan path partisi /home dari instalasi UBUNTU Anda."
    read -p "Masukkan partisi /home Ubuntu (contoh: /dev/sda2): " HOME_PART

    if [[ ! -b "$HOME_PART" ]]; then
        log_gagal "Device partisi tidak valid."
        return 1
    fi
    
    local BACKUP_DIR="/root/ubuntu_migration_backup_$(date +%F_%H-%M)"
    local MNT_BAK="/mnt/ubuntu_home_backup"
    
    log_info "Mencadangkan data dari ${HOME_PART} ke ${BACKUP_DIR}..."
    mkdir -p "$MNT_BAK"
    if ! mount "$HOME_PART" "$MNT_BAK"; then
        log_gagal "Gagal me-mount partisi home Ubuntu."
    fi
    
    mkdir -p "$BACKUP_DIR"
    log_info "Menyalin file dengan rsync (ini bisa lama)..."
    if ! rsync -a --info=progress2 "$MNT_BAK/" "$BACKUP_DIR/"; then
        umount "$MNT_BAK"
        log_gagal "Proses rsync (backup) gagal."
    fi
    
    umount "$MNT_BAK"
    rmdir "$MNT_BAK"
    log_sukses "Backup /home Ubuntu selesai dan disimpan di ${BACKUP_DIR}"
    return 0
}

uninstall_ubuntu() {
    log_info "LANGKAH 2: HAPUS PARTISI UBUNTU"
    log_warn "Anda harus mengidentifikasi SEMUA partisi yang digunakan oleh Ubuntu."
    log_info "Ini bisa termasuk partisi root (/), home (/home), boot (/boot), dan swap."
    lsblk -f
    read -p "Masukkan semua path partisi Ubuntu, pisahkan dengan spasi (contoh: /dev/sda1 /dev/sda2): " -a UBUNTU_PARTS
    
    if [[ ${#UBUNTU_PARTS[@]} -eq 0 ]]; then
        log_gagal "Tidak ada partisi yang dimasukkan. Proses dibatalkan."
        return 1
    fi

    
    for p in "${UBUNTU_PARTS[@]}"; do
        if [[ ! -b "$p" ]]; then
            log_gagal "Input '${p}' bukan merupakan device partisi yang valid."
            return 1
        fi
    done

    if hapus_partisi_dan_update_grub "${UBUNTU_PARTS[@]}"; then
        log_sukses "Penghapusan partisi Ubuntu selesai."
        return 0
    else
        log_gagal "Proses penghapusan partisi Ubuntu dibatalkan atau gagal."
        return 1
    fi
}

migrasi_ubuntu_ke_kali() {
    cek_root
    log_info "Memulai mode Migrasi dari Ubuntu ke Kali Linux."
    log_warn "Proses ini akan MENGHAPUS instalasi Ubuntu Anda secara permanen."
    log_warn "${C_B_RED}PENTING:${C_RESET} Skrip ini harus dijalankan dari sistem Linux LAIN (misal: Live USB), BUKAN dari instalasi Ubuntu yang akan dimigrasikan."
    read -p "Apakah Anda paham dan ingin melanjutkan? (y/N): " lanjut
    [[ "$lanjut" =~ ^[Yy]$ ]] || { log_info "Migrasi dibatalkan."; return; }

    
    backup_home_ubuntu || return

    
    log_info "LANGKAH 3: PERSIAPAN INSTALLER KALI"
    download_iso
    verify_iso
    pilih_usb_otomatis
    
    
    uninstall_ubuntu || return

    
    flash_usb

    
    log_sukses "Persiapan migrasi selesai! USB installer Kali siap digunakan."
    echo -e "${C_B_CYAN}================== LANGKAH MIGRASI SELANJUTNYA ==================${C_RESET}"
    echo -e " ${C_B_YELLOW}1.${C_RESET} ${C_BOLD}Reboot${C_RESET} komputer Anda SEKARANG."
    echo -e " ${C_B_YELLOW}2.${C_RESET} Masuk ke BIOS/UEFI dan atur ${C_BOLD}boot dari USB${C_RESET}."
    echo -e " ${C_B_YELLOW}3.${C_RESET} Ikuti petunjuk installer Kali. Saat partisi, pilih '${C_BOLD}Guided - use largest continuous free space${C_RESET}'."
    echo -e "         Ini akan menggunakan ruang kosong yang baru saja Anda buat dari partisi Ubuntu."
    echo -e " ${C_B_YELLOW}4.${C_RESET} Selesaikan instalasi dan boot ke sistem Kali baru Anda."
    echo -e " ${C_B_YELLOW}5.${C_RESET} Setelah masuk, buka terminal dan jalankan perintah ini untuk ${C_BOLD}restore data${C_RESET} Anda:"
    echo -e "    ${C_CYAN}sudo rsync -a /root/ubuntu_migration_backup_*/ /home/\$(whoami)/${C_RESET}"
    echo -e " ${C_B_YELLOW}6.${C_RESET} Periksa file Anda. Setelah yakin semua aman, Anda dapat menghapus folder backup di /root."
    echo -e "${C_B_CYAN}=======================================================================${C_RESET}"
    read -p "Tekan [Enter] untuk kembali ke menu utama..."
}

install_baru() {
    cek_root
    download_iso
    verify_iso
    pilih_usb_otomatis
    flash_usb
    log_sukses "Proses persiapan instalasi selesai!"
    echo -e "${C_B_CYAN}================== LANGKAH SELANJUTNYA ==================${C_RESET}"
    echo -e " ${C_B_YELLOW}1.${C_RESET} Reboot komputer Anda."
    echo -e " ${C_B_YELLOW}2.${C_RESET} Masuk ke BIOS/UEFI dan atur boot dari USB yang baru Anda buat."
    echo -e " ${C_B_YELLOW}3.${C_RESET} Ikuti petunjuk pada installer grafis Kali Linux."
    echo -e "${C_B_CYAN}=========================================================${C_RESET}"
    read -p "Tekan [Enter] untuk kembali ke menu utama..."
}

trap 'log_gagal "Terjadi error pada baris $LINENO. Periksa log di $LOG_FILE untuk detail."' ERR

cek_root
cek_lingkungan
cek_dependensi
touch "$LOG_FILE"
log_info "X-Reinstaller - Script By Xbibz Official."
menu_utama


