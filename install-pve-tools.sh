#!/bin/bash

# Installer untuk Proxmox VE Tools

PVE_TOOLS_SCRIPT="pve-tools.sh"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc"

echo "Installing Proxmox VE Tools..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if we're on Proxmox VE
if ! command -v pvesh &> /dev/null; then
    echo "Error: This script must be run on a Proxmox VE node"
    exit 1
fi

# Copy main script
echo "Copying main script to $INSTALL_DIR..."
cp "$PVE_TOOLS_SCRIPT" "$INSTALL_DIR/pve-tools"
chmod +x "$INSTALL_DIR/pve-tools"

# Create config file if not exists
if [[ ! -f "/etc/pve-tools.conf" ]]; then
    echo "Creating default configuration..."
    cat > "/etc/pve-tools.conf" << 'EOF'
# Proxmox VE Tools Configuration
# Log settings
LOG_LEVEL="INFO"
LOG_RETENTION_DAYS=30

# Backup settings
DEFAULT_BACKUP_STORAGE="local"
DEFAULT_BACKUP_COMPRESSION="zstd"

# Display settings
SHOW_WARNINGS=true
COLORED_OUTPUT=true
EOF
fi

# Create systemd service (optional)
echo "Creating systemd service..."
cat > "/etc/systemd/system/pve-tools.service" << 'EOF'
[Unit]
Description=Proxmox VE Tools
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecReload=/bin/true

[Install]
WantedBy=multi-user.target
EOF

# Create bash completion
echo "Creating bash completion..."
cat > "/etc/bash_completion.d/pve-tools" << 'EOF'
_pve_tools() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="--help --version --list --resources --start --stop --restart --details --backup --logs"
    
    case "${prev}" in
        --start|--stop|--restart|--details|--backup)
            local containers=$(pct list | awk 'NR>1 {print $1}')
            local vms=$(qm list | awk 'NR>1 {print $1}')
            COMPREPLY=( $(compgen -W "${containers} ${vms}" -- ${cur}) )
            ;;
        *)
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            ;;
    esac
}
complete -F _pve_tools pve-tools
EOF

echo "Installation completed successfully!"
echo ""
echo "Usage:"
echo "  pve-tools                    # Interactive mode"
echo "  pve-tools --list            # List all containers/VMs"
echo "  pve-tools --resources       # Show resource usage"
echo "  pve-tools --start <ID>      # Start container/VM"
echo "  pve-tools --stop <ID>       # Stop container/VM"
echo "  pve-tools --help            # Show help"
echo ""
echo "You can now run 'pve-tools' from anywhere in the system!"