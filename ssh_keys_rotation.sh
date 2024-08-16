#!/bin/bash

# Check if the private instance IP is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <private-instance-ip>"
    exit 1
fi

PRIVATE_IP="$1"
cp "$HOME/key.pem "$HOME/.ssh/id_rsa_old"

OLD_KEY_PATH="$HOME/.ssh/id_rsa_old"  # Path to your old key
NEW_KEY_PATH="$HOME/.ssh/id_rsa"   # Path to store the new key

# Generate a new SSH key pair
ssh-keygen -t rsa -b 4096 -f "$NEW_KEY_PATH" -N ""  -C "Key rotated on $(date)" > /dev/null

# Ensure the old key exists before using it
if [ ! -f "$OLD_KEY_PATH" ]; then
    echo "Old key not found at $OLD_KEY_PATH"
    exit 1
fi

# Connect to the private instance and update authorized_keys
# Ensure to use the old key for this connection
#ssh -o StrictHostKeyChecking=no -i "$OLD_KEY_PATH" ubuntu@"$PRIVATE__IP" "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
#cat "${NEW_KEY_PATH}.pub" | ssh -o StrictHostKeyChecking=no -i "$OLD_KEY_PATH" ubuntu@"$PRIVATE_INSTANCE_IP" "cat > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

ssh -o StrictHostKeyChecking=no -i "$OLD_KEY_PATH" ubuntu@"$PRIVATE_IP" << EOF
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat >> ~/.ssh/authorized_keys << EOL
$(cat "${NEW_KEY_PATH}.pub")
EOL
chmod 600 ~/.ssh/authorized_keys
EOF

# Test SSH connection with the new key
ssh -o StrictHostKeyChecking=no -i "$NEW_KEY_PATH" ubuntu@"$PRIVATE_IP"