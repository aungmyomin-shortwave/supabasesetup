#!/bin/bash

# Quick Setup Script for Supabase
# This script provides a simple way to get started with Supabase

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}Supabase Self-Hosted Setup${NC}"
echo "================================"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Check if installation script exists
if [ ! -f "./install-supabase.sh" ]; then
    echo "Error: install-supabase.sh not found in current directory"
    exit 1
fi

echo -e "${BLUE}Starting Supabase installation...${NC}"
echo ""

# Run the main installation script
./install-supabase.sh

echo ""
echo -e "${GREEN}Installation completed!${NC}"
echo ""
echo "Next steps:"
echo "1. Start Supabase: sudo ./manage-supabase.sh start"
echo "2. Configure SSL: sudo ./manage-supabase.sh ssl"
echo "3. Access Studio: http://$(hostname -I | awk '{print $1}')"
echo ""
echo "For help: sudo ./manage-supabase.sh help"
