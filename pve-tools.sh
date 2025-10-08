#!/bin/bash

# Proxmox VE Tools - CLI Helper untuk CT/VM
# Author: System Administrator
# Version: 1.0
# Description: Tools untuk memudahkan management CT/VM di Proxmox VE

PVE_TOOLS_VERSION="1.0"
CONFIG_FILE="/etc/pve-tools.conf"
LOG_FILE="/var/log/pve-tools.log"

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fungsi logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Fungsi untuk menampilkan header
show_header() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║               PROXMOX VE TOOLS v$PVE_TOOLS_VERSION               ║"
    echo "║                 CLI Helper untuk CT/VM                  ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Fungsi untuk memeriksa dependencies
check_dependencies() {
    local deps=("pvesh" "qm" "pct")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Error: Dependencies berikut tidak ditemukan:${NC}"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        echo -e "\nPastikan Anda menjalankan script ini di Proxmox VE node"
        exit 1
    fi
}

# Fungsi untuk menampilkan daftar VM/CT
list_containers() {
    show_header
    echo -e "${YELLOW}📋 DAFTAR CONTAINER (LXC)${NC}"
    echo "══════════════════════════════════════════════════════════"
    pct list | awk '
    BEGIN { printf "%-8s %-20s %-12s %-15s %-10s\n", "ID", "Nama", "Status", "IP", "Memori" }
    NR>1 { printf "%-8s %-20s %-12s %-15s %-10s\n", $1, $2, $3, $4, $5 }
    '
    
    echo -e "\n${YELLOW}🖥️  DAFTAR VIRTUAL MACHINE (QEMU)${NC}"
    echo "══════════════════════════════════════════════════════════"
    qm list | awk '
    BEGIN { printf "%-8s %-20s %-12s %-8s %-12s %-10s\n", "ID", "Nama", "Status", "CPU", "Memori", "Disk" }
    NR>1 { printf "%-8s %-20s %-12s %-8s %-12s %-10s\n", $1, $2, $3, $4, $5, $6 }
    '
}

# Fungsi untuk menampilkan resource usage
show_resources() {
    show_header
    echo -e "${YELLOW}📊 STATUS RESOURCE NODE${NC}"
    echo "══════════════════════════════════════════════════════════"
    
    # CPU Usage
    cpu_usage=$(mpstat 1 1 | awk '$12 ~ /[0-9.]+/ { print 100 - $12 }' | tail -1)
    echo -e "CPU Usage: ${GREEN}$cpu_usage%${NC}"
    
    # Memory Usage
    mem_total=$(free -h | awk '/Mem:/ {print $2}')
    mem_used=$(free -h | awk '/Mem:/ {print $3}')
    mem_percent=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}')
    echo -e "Memory: ${GREEN}$mem_used${NC} / $mem_total ($mem_percent%)"
    
    # Disk Usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5 " used (" $3 " / " $2 ")"}')
    echo -e "Disk: ${GREEN}$disk_usage${NC}"
    
    echo -e "\n${YELLOW}🏃 CONTAINER/VM YANG SEDANG BERJALAN${NC}"
    echo "══════════════════════════════════════════════════════════"
    
    # Running containers
    running_ct=$(pct list | grep running | wc -l)
    total_ct=$(pct list | tail -n +2 | wc -l)
    echo -e "Container: ${GREEN}$running_ct${NC} / $total_ct berjalan"
    
    # Running VMs
    running_vm=$(qm list | grep running | wc -l)
    total_vm=$(qm list | tail -n +2 | wc -l)
    echo -e "VM: ${GREEN}$running_vm${NC} / $total_vm berjalan"
}

# Fungsi untuk start container/VM
start_container() {
    show_header
    echo -e "${YELLOW}🚀 START CONTAINER/VM${NC}"
    echo "══════════════════════════════════════════════════════════"
    
    list_containers
    echo
    read -p "Masukkan ID Container/VM yang akan di-start: " target_id
    
    if [[ -z "$target_id" ]]; then
        echo -e "${RED}ID tidak boleh kosong!${NC}"
        return
    fi
    
    # Cek apakah ID termasuk container atau VM
    if pct list | awk '{print $1}' | grep -q "^$target_id$"; then
        echo -e "${BLUE}Starting Container $target_id...${NC}"
        pct start "$target_id"
        log "Started container $target_id"
    elif qm list | awk '{print $1}' | grep -q "^$target_id$"; then
        echo -e "${BLUE}Starting VM $target_id...${NC}"
        qm start "$target_id"
        log "Started VM $target_id"
    else
        echo -e "${RED}ID $target_id tidak ditemukan!${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Fungsi untuk stop container/VM
stop_container() {
    show_header
    echo -e "${YELLOW}🛑 STOP CONTAINER/VM${NC}"
    echo "══════════════════════════════════════════════════════════"
    
    list_containers
    echo
    read -p "Masukkan ID Container/VM yang akan di-stop: " target_id
    
    if [[ -z "$target_id" ]]; then
        echo -e "${RED}ID tidak boleh kosong!${NC}"
        return
    fi
    
    # Cek apakah ID termasuk container atau VM
    if pct list | awk '{print $1}' | grep -q "^$target_id$"; then
        echo -e "${BLUE}Stopping Container $target_id...${NC}"
        pct stop "$target_id"
        log "Stopped container $target_id"
    elif qm list | awk '{print $1}' | grep -q "^$target_id$"; then
        echo -e "${BLUE}Stopping VM $target_id...${NC}"
        qm stop "$target_id"
        log "Stopped VM $target_id"
    else
        echo -e "${RED}ID $target_id tidak ditemukan!${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Fungsi untuk restart container/VM
restart_container() {
    show_header
    echo -e "${YELLOW}🔄 RESTART CONTAINER/VM${NC}"
    echo "══════════════════════════════════════════════════════════"
    
    list_containers
    echo
    read -p "Masukkan ID Container/VM yang akan di-restart: " target_id
    
    if [[ -z "$target_id" ]]; then
        echo -e "${RED}ID tidak boleh kosong!${NC}"
        return
    fi
    
    # Cek apakah ID termasuk container atau VM
    if pct list | awk '{print $1}' | grep -q "^$target_id$"; then
        echo -e "${BLUE}Restarting Container $target_id...${NC}"
        pct restart "$target_id"
        log "Restarted container $target_id"
    elif qm list | awk '{print $1}' | grep -q "^$target_id$"; then
        echo -e "${BLUE}Restarting VM $target_id...${NC}"
        qm reset "$target_id"
        log "Restarted VM $target_id"
    else
        echo -e "${RED}ID $target_id tidak ditemukan!${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Fungsi untuk melihat detail container/VM
show_details() {
    show_header
    echo -e "${YELLOW}📄 DETAIL CONTAINER/VM${NC}"
    echo "══════════════════════════════════════════════════════════"
    
    list_containers
    echo
    read -p "Masukkan ID Container/VM: " target_id
    
    if [[ -z "$target_id" ]]; then
        echo -e "${RED}ID tidak boleh kosong!${NC}"
        return
    fi
    
    # Cek apakah ID termasuk container atau VM
    if pct list | awk '{print $1}' | grep -q "^$target_id$"; then
        echo -e "\n${GREEN}Detail Container $target_id:${NC}"
        echo "──────────────────────────────────────────────────"
        pct config "$target_id" | grep -E "(hostname|memory|cores|net|rootfs)" | head -10
    elif qm list | awk '{print $1}' | grep -q "^$target_id$"; then
        echo -e "\n${GREEN}Detail VM $target_id:${NC}"
        echo "──────────────────────────────────────────────────"
        qm config "$target_id" | grep -E "(name|memory|cores|net|scsi)" | head -10
    else
        echo -e "${RED}ID $target_id tidak ditemukan!${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Fungsi untuk backup container/VM
backup_container() {
    show_header
    echo -e "${YELLOW}💾 BACKUP CONTAINER/VM${NC}"
    echo "══════════════════════════════════════════════════════════"
    
    list_containers
    echo
    read -p "Masukkan ID Container/VM yang akan di-backup: " target_id
    
    if [[ -z "$target_id" ]]; then
        echo -e "${RED}ID tidak boleh kosong!${NC}"
        return
    fi
    
    read -p "Masukkan nama file backup (tanpa ekstensi): " backup_name
    
    if [[ -z "$backup_name" ]]; then
        backup_name="backup_${target_id}_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Cek apakah ID termasuk container atau VM
    if pct list | awk '{print $1}' | grep -q "^$target_id$"; then
        echo -e "${BLUE}Creating backup for Container $target_id...${NC}"
        vzdump "$target_id" --dumpdir "/var/lib/vz/dump/" --mode snapshot --compress zstd --storage local
        log "Backed up container $target_id to $backup_name"
    elif qm list | awk '{print $1}' | grep -q "^$target_id$"; then
        echo -e "${BLUE}Creating backup for VM $target_id...${NC}"
        vzdump "$target_id" --dumpdir "/var/lib/vz/dump/" --mode suspend --compress zstd --storage local
        log "Backed up VM $target_id to $backup_name"
    else
        echo -e "${RED}ID $target_id tidak ditemukan!${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Fungsi untuk menampilkan menu utama
show_menu() {
    echo -e "\n${GREEN}📝 MENU UTAMA${NC}"
    echo "══════════════════════════════════════════════════════════"
    echo -e "${BLUE}1.${NC} List semua Container/VM"
    echo -e "${BLUE}2.${NC} Status Resource Node"
    echo -e "${BLUE}3.${NC} Start Container/VM"
    echo -e "${BLUE}4.${NC} Stop Container/VM"
    echo -e "${BLUE}5.${NC} Restart Container/VM"
    echo -e "${BLUE}6.${NC} Detail Container/VM"
    echo -e "${BLUE}7.${NC} Backup Container/VM"
    echo -e "${BLUE}8.${NC} View Logs"
    echo -e "${BLUE}0.${NC} Exit"
    echo "══════════════════════════════════════════════════════════"
}

# Fungsi untuk view logs
view_logs() {
    show_header
    echo -e "${YELLOW}📋 LOGS PROXMOX VE TOOLS${NC}"
    echo "══════════════════════════════════════════════════════════"
    
    if [[ -f "$LOG_FILE" ]]; then
        tail -20 "$LOG_FILE"
    else
        echo -e "${YELLOW}Log file belum ada.${NC}"
    fi
    
    echo -e "\n${YELLOW}Options:${NC}"
    echo "1. Tampilkan semua logs"
    echo "2. Clear logs"
    echo "3. Kembali ke menu utama"
    
    read -p "Pilih option [1-3]: " log_option
    
    case $log_option in
        1)
            if [[ -f "$LOG_FILE" ]]; then
                cat "$LOG_FILE"
            fi
            ;;
        2)
            > "$LOG_FILE"
            echo -e "${GREEN}Logs telah di-clear.${NC}"
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}Pilihan tidak valid!${NC}"
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Main function
main() {
    # Check dependencies
    check_dependencies
    
    # Create log file if not exists
    touch "$LOG_FILE"
    
    # Log startup
    log "Proxmox VE Tools started"
    
    while true; do
        show_header
        show_menu
        
        read -p "Pilih menu [0-8]: " choice
        
        case $choice in
            1)
                list_containers
                read -p "Press Enter to continue..."
                ;;
            2)
                show_resources
                read -p "Press Enter to continue..."
                ;;
            3)
                start_container
                ;;
            4)
                stop_container
                ;;
            5)
                restart_container
                ;;
            6)
                show_details
                ;;
            7)
                backup_container
                ;;
            8)
                view_logs
                ;;
            0)
                echo -e "${GREEN}Terima kasih telah menggunakan Proxmox VE Tools!${NC}"
                log "Proxmox VE Tools stopped"
                exit 0
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid! Silakan coba lagi.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Trap untuk handle Ctrl+C
trap 'echo -e "\n${RED}Script diinterupsi. Keluar...${NC}"; log "Script interrupted by user"; exit 1' INT

# Jalankan main function
main "$@"