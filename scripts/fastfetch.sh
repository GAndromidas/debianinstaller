#!/bin/bash

# Function to check the architecture
check_architecture() {
    ARCH=$(uname -m)
    if [[ "$ARCH" == "aarch64" ]]; then
        echo "aarch64"
    elif [[ "$ARCH" == "x86_64" ]]; then
        echo "amd64"
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
}

# Function to find the latest release on GitHub
find_latest_release_url() {
    REPO="fastfetch-cli/fastfetch"
    API_URL="https://api.github.com/repos/$REPO/releases/latest"
    ARCH=$1

    # Get the latest release data from GitHub API
    LATEST_RELEASE_JSON=$(curl -s $API_URL)

    # Extract the correct download URL for the architecture
    DEB_URL=$(echo "$LATEST_RELEASE_JSON" | grep -Eo "https://[^\"]*${ARCH}\.deb")

    echo $DEB_URL
}

# Function to download and install the .deb file
download_and_install() {
    ARCH=$(check_architecture)
    DEB_URL=$(find_latest_release_url $ARCH)

    if [[ -z "$DEB_URL" ]]; then
        echo "No .deb package found for architecture: $ARCH"
        exit 1
    fi

    # Download the .deb file
    wget -O fastfetch.deb "$DEB_URL"

    # Install the .deb file
    sudo dpkg -i fastfetch.deb

    # Clean up
    rm fastfetch.deb
}

# Run the functions
download_and_install

echo "Fastfetch installed successfully!"