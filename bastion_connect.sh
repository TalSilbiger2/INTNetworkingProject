#!/bin/bash

# Check if KEY_PATH environment variable is set
if [ -z "$KEY_PATH" ]; then
    echo "KEY_PATH env var is expected"
    exit 5
fi

# Check if at least one argument (public instance IP) is provided
if [ $# -lt 1 ]; then
    echo "Please provide bastion IP address"
    exit 5
fi

# Variables
PUBLIC_IP=$1
PRIVATE_IP=$2
COMMAND=$3

# Construct the SSH command
if [ -z "$PRIVATE_IP" ]; then
    # Case 2: Connect to the public instance
    ssh -i "$KEY_PATH" ubuntu@"$PUBLIC_IP"
else
    # Case 1 & Case 3: Connect to the private instance via the public instance
    if [ -z "$COMMAND" ]; then
        # Case 1: Interactive SSH to private instance
        ssh -i "$KEY_PATH" -t ubuntu@"$PUBLIC_IP" ssh -i "$KEY_PATH" ubuntu@"$PRIVATE_IP"
    else
        # Case 3: Run command on the private instance
        ssh -i "$KEY_PATH" -t ubuntu@"$PUBLIC_IP" ssh -i "$KEY_PATH" ubuntu@"$PRIVATE_IP" "$COMMAND"
    fi
fi
