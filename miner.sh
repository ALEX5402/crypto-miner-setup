#!/bin/bash

set -e

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
else
    echo "Docker is already installed."
fi

# Enable Docker service and socket
sudo systemctl enable --now docker.service
sudo systemctl enable --now docker.socket

# Get the Docker image name from the first argument
if [ -z "$1" ]; then
    echo "Usage: $0 <docker-image-name>"
    exit 1
fi

IMAGE_NAME="$1"

# Sanitize image name to be used as service name
SERVICE_NAME=$(echo "$IMAGE_NAME" | sed 's/[:\/\\]/_/g')

echo "Using service name: $SERVICE_NAME"

# Run Docker container
sudo docker run -d --restart unless-stopped --name "$SERVICE_NAME" "$IMAGE_NAME"

# Create systemd service
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=$SERVICE_NAME
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/bin/docker start $SERVICE_NAME
ExecStop=/bin/docker stop $SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable/start the service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

echo "Service $SERVICE_NAME is now active and managed by systemd."
