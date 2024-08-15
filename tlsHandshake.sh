#!/bin/bash

# Check if the correct number of arguments is supplied
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <server-ip>"
    exit 1
fi

SERVER_IP=$1
CA_CERT_URL="https://exit-zero-academy.github.io/DevOpsTheHardWayAssets/networking_project/cert-ca-aws.pem"
CA_CERT_FILE="cert-ca-aws.pem"
CERT_FILE="cert.pem"
MASTER_KEY_FILE="master_key.txt"
SESSION_ID=""
ENCRYPTED_MASTER_KEY=""
SAMPLE_MESSAGE="Hi server, please encrypt me and send to client!"

# Step 1: Test the server status
echo "Testing server status..."
if curl -s "${SERVER_IP}:8080/status" | grep -q "Hi! I'm available, let's start the TLS handshake"; then
    echo "Server is available. Proceeding to the next step..."
else
    echo "Failed to connect to the server or incorrect response."
    exit 2
fi

# Step 2: Send Client Hello
echo "Sending Client Hello request..."
CLIENT_HELLO='{"version": "1.3", "ciphersSuites": ["TLS_AES_128_GCM_SHA256", "TLS_CHACHA20_POLY1305_SHA256"], "message": "Client Hello"}'

echo "$CLIENT_HELLO" | jq . > /dev/null
if [ $? -ne 0 ]; then
    echo "Invalid JSON format."
    exit 2
fi

RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "$CLIENT_HELLO" "${SERVER_IP}:8080/clienthello")

# Check if the response is successful
if [ $? -ne 0 ]; then
    echo "Failed to send Client Hello."
    exit 3
fi

# Step 3: Parse the Server Hello response
SESSION_ID=$(echo "$RESPONSE" | jq -r '.sessionID')
SERVER_CERT=$(echo "$RESPONSE" | jq -r '.serverCert')

if [ "$SESSION_ID" == "null" ] || [ "$SERVER_CERT" == "null" ]; then
    echo "Failed to retrieve sessionID or serverCert from the response."
    exit 4
fi

echo "Received Server Hello response:"
echo "Session ID: $SESSION_ID"
echo "Server Certificate: $SERVER_CERT"

# Save server certificate to file
echo "$SERVER_CERT" > "$CERT_FILE"

# Step 4: Download CA certificate if it doesn't exist
if [ ! -f "$CA_CERT_FILE" ]; then
    echo "Downloading CA certificate..."
    wget -q "$CA_CERT_URL" -O "$CA_CERT_FILE"
    if [ $? -ne 0 ]; then
        echo "Failed to download CA certificate."
        exit 5
    fi
fi

# Step 5: Verify the server certificate
echo "Verifying the server certificate..."
openssl verify -CAfile "$CA_CERT_FILE" "$CERT_FILE"
if [ $? -ne 0 ]; then
    echo "Server Certificate is invalid."
    exit 5
fi

echo "Server certificate verified successfully."

# Step 6: Generate a random master key
echo "Generating a random master key..."
MASTER_KEY=$(openssl rand -base64 32)
echo "$MASTER_KEY" > "$MASTER_KEY_FILE"

# Step 7: Encrypt the master key with the server certificate
echo "Encrypting the master key with the server certificate..."
openssl smime -encrypt -aes-256-cbc -in "$MASTER_KEY_FILE" -outform DER "$CERT_FILE" | base64 -w 0 > "${MASTER_KEY_FILE}.enc"
ENCRYPTED_MASTER_KEY=$(cat "${MASTER_KEY_FILE}.enc")

# Step 8: Send the encrypted master key to the server
echo "Sending the encrypted master key to the server..."
KEY_EXCHANGE_BODY="{\"sessionID\": \"$SESSION_ID\", \"masterKey\": \"$ENCRYPTED_MASTER_KEY\", \"sampleMessage\": \"$SAMPLE_MESSAGE\"}"
KEY_EXCHANGE_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "$KEY_EXCHANGE_BODY" "${SERVER_IP}:8080/keyexchange")

# Step 9: Parse the encrypted sample message
ENCRYPTED_SAMPLE_MESSAGE=$(echo "$KEY_EXCHANGE_RESPONSE" | jq -r '.encryptedSampleMessage')
if [ "$ENCRYPTED_SAMPLE_MESSAGE" == "null" ]; then
    echo "Failed to retrieve encryptedSampleMessage from the response."
    exit 4
fi

# Step 10: Decrypt the sample message
echo "Decrypting the sample message..."
DECRYPTED_MESSAGE=$(echo "$ENCRYPTED_SAMPLE_MESSAGE" | base64 -d | openssl enc -d -aes-256-cbc -pbkdf2 -k "$MASTER_KEY")

# Step 11: Verify the decrypted message
if [ "$DECRYPTED_MESSAGE" == "$SAMPLE_MESSAGE" ]; then
    echo "Client-Server TLS handshake has been completed successfully."
else
    echo "Server symmetric encryption using the exchanged master-key has failed."
    exit 6
fi

# Clean up temporary files
rm -f "$MASTER_KEY_FILE" "${MASTER_KEY_FILE}.enc" "$CERT_FILE"

echo "All done! You've successfully implemented a secure communication over HTTP."

