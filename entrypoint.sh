#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Configuration for Connection Check ---
WG_CONFIG_FILE="/etc/wireguard/wg0.conf"
PING_COUNT=1
PING_TIMEOUT=2 # seconds per ping

# --- WireGuard Configuration File Check and Copy ---
echo -e "${YELLOW}Copying WireGuard config file...${NC}"
if [ ! -f /tmp/config/wg0.conf ]; then
    echo -e "${RED}Error: /tmp/config/wg0.conf not found! Cannot proceed with WireGuard setup.${NC}"
    exit 1
fi
cp /tmp/config/wg0.conf "$WG_CONFIG_FILE"

if [ ! -f "$WG_CONFIG_FILE" ]; then
    echo -e "${RED}Error: WireGuard config file ($WG_CONFIG_FILE) was not copied successfully.${NC}"
    exit 1
fi

# --- Extract Endpoint IP from wg0.conf ---
# This assumes the Endpoint is in the [Peer] section and is in the format IP:Port
# It will extract the IP address part.
WG_ENDPOINT_IP=$(grep -m 1 "Endpoint =" "$WG_CONFIG_FILE" | awk -F'=' '{print $2}' | awk -F':' '{print $1}' | xargs)

if [ -z "$WG_ENDPOINT_IP" ]; then
    echo -e "${RED}Error: Could not extract Endpoint IP from $WG_CONFIG_FILE. Please ensure 'Endpoint = IP:Port' is present in the [Peer] section.${NC}"
    exit 1
fi

echo -e "${YELLOW}Attempting to bring up WireGuard interface...${CYAN}"
wg-quick up wg0
WG_EXIT_CODE=$?

if [ $WG_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}Error: 'wg-quick up wg0' failed with exit code $WG_EXIT_CODE. Aborting.${NC}"
    exit 1
fi

echo -e "${YELLOW}Verifying WireGuard connection by pinging the Endpoint IP ($WG_ENDPOINT_IP)...${NC}"

# Give WireGuard a moment to establish the connection
sleep 3

# Attempt to ping the extracted Endpoint IP
ping -c $PING_COUNT -W $PING_TIMEOUT "$WG_ENDPOINT_IP" > /dev/null 2>&1
PING_EXIT_CODE=$?

if [ $PING_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Successfully connected to remote network via WireGuard (ping to $WG_ENDPOINT_IP successful).${NC}"
else
    echo -e "${RED}Error: Failed to connect to remote network. Ping to Endpoint IP ($WG_ENDPOINT_IP) failed (Exit code: $PING_EXIT_CODE).${NC}"
    echo -e "${RED}Possible issues: incorrect WireGuard config, firewall, or the server is not reachable at this Endpoint IP.${NC}"
    wg-quick down wg0 # Try to bring it down cleanly if it's up
    exit 1 # Exit the script as VPN connection is critical
fi

# Proceed with mounting only if WireGuard connection was successful
MOUNT_LOCATION=/mnt/remote
mkdir -p $MOUNT_LOCATION # Use -p to avoid error if directory already exists

echo -e "\n${YELLOW}Attempting to mount remote share...${NC}"
# It's highly recommended to use environment variables for username and password in Docker
# and ensure they are handled securely (e.g., Docker secrets).
sudo mount -t cifs -o username=$USERNAME,password=$PASSWORD \
    //$REMOTE_HOST/$REMOTE_SHARE $MOUNT_LOCATION

MOUNT_EXIT_CODE=$?
if [ $MOUNT_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Successfully mounted remote share to /mnt/remote.${NC}"
else
    echo -e "${RED}Error: Failed to mount remote share. (Exit code: $MOUNT_EXIT_CODE)${NC}"
    # You might want to exit here if mounting is critical
    exit 1
fi

# Can add --bwlimit=KB/s if network limited
echo -e "\n${YELLOW}Starting rsync process...${CYAN}"
rsync -avz --partial --progress --human-readable --timeout=30  \
    /tmp/copy_from/* \
    $MOUNT_LOCATION/$REMOTE_LOCATION

RSYNC_EXIT_CODE=$?
if [ $RSYNC_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Successfully copied all contents of directory.${NC}"
else
    echo -e "${RED}Error: rsync failed with exit code $RSYNC_EXIT_CODE.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Checking directoy integrity${CYAN}"
rsync -avzc --dry-run /tmp/copy_from/ "$MOUNT_LOCATION/$REMOTE_LOCATION"
INTEGRITY_RSYNC_EXIT_CODE=$?
if [ $INTEGRITY_RSYNC_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Successfully verified integrity${NC}"
else
    echo -e "${RED}Error: rsync failed with exit code $INTEGRITY_RSYNC_EXIT_CODE.${NC}"
    exit 1
fi

# Optional: Unmount and bring down WireGuard when done
# echo -e "\n${YELLOW}Cleaning up: Unmounting remote share and bringing down WireGuard.${NC}"
# sudo umount $MOUNT_LOCATION
# wg-quick down wg0

echo -e "\n${BLUE}Script finished.${NC}"