#!/usr/bin/env bash
# Generate apt repository metadata
# SPDX-License-Identifier: LGPL-2.1-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Output directory for the repository
REPO_DIR="$SCRIPT_DIR/repo"

# GitHub release URL base (will be filled in during CI)
GITHUB_REPO="${GITHUB_REPOSITORY:-nix-deb/nix.deb}"
GITHUB_TAG="${GITHUB_REF_NAME:-latest}"
RELEASE_URL="https://github.com/$GITHUB_REPO/releases/download/$GITHUB_TAG"

# Distributions we support
DEBIAN_DISTROS=(stretch buster bullseye bookworm trixie)
UBUNTU_DISTROS=(xenial bionic focal jammy noble)

usage() {
    cat <<EOF
Usage: $0 ARTIFACTS_DIR

Generate apt repository metadata for the .deb files in ARTIFACTS_DIR.

The repository structure will be created at: $REPO_DIR

Arguments:
    ARTIFACTS_DIR   Directory containing the .deb files (organized by distro)
EOF
}

# Generate Packages file for a distribution
generate_packages() {
    local distro="$1"
    local deb_dir="$2"
    local output_dir="$3"

    mkdir -p "$output_dir"

    local packages_file="$output_dir/Packages"

    # Clear existing file
    : > "$packages_file"

    # Find all .deb files for this distro
    for deb in "$deb_dir"/*.deb; do
        [[ -f "$deb" ]] || continue

        local filename
        filename=$(basename "$deb")

        # Extract package info using dpkg-deb
        local pkg_name pkg_version pkg_arch pkg_size pkg_sha256 pkg_description

        pkg_name=$(dpkg-deb -f "$deb" Package)
        pkg_version=$(dpkg-deb -f "$deb" Version)
        pkg_arch=$(dpkg-deb -f "$deb" Architecture)
        pkg_size=$(stat -c %s "$deb")
        pkg_sha256=$(sha256sum "$deb" | cut -d' ' -f1)

        # Get full control file
        local control
        control=$(dpkg-deb -f "$deb")

        # Write to Packages file
        echo "$control" >> "$packages_file"
        echo "Filename: $RELEASE_URL/$filename" >> "$packages_file"
        echo "Size: $pkg_size" >> "$packages_file"
        echo "SHA256: $pkg_sha256" >> "$packages_file"
        echo "" >> "$packages_file"

        echo "  Added: $pkg_name $pkg_version ($pkg_arch)"
    done

    # Compress Packages file
    gzip -k "$packages_file"
    xz -k "$packages_file"

    echo "Generated Packages for $distro"
}

# Generate Release file for a distribution
generate_release() {
    local distro="$1"
    local suite="$2"
    local output_dir="$3"

    local release_file="$output_dir/Release"

    # Determine codename and origin
    local origin="nix-deb"
    local label="Nix and Lix packages"
    local codename="$suite"

    # Calculate checksums
    local md5sums sha1sums sha256sums
    md5sums=""
    sha1sums=""
    sha256sums=""

    for file in "$output_dir"/Packages*; do
        [[ -f "$file" ]] || continue
        local fname size md5 sha1 sha256
        fname=$(basename "$file")
        size=$(stat -c %s "$file")
        md5=$(md5sum "$file" | cut -d' ' -f1)
        sha1=$(sha1sum "$file" | cut -d' ' -f1)
        sha256=$(sha256sum "$file" | cut -d' ' -f1)

        md5sums+=" $md5 $size main/binary-amd64/$fname
"
        sha1sums+=" $sha1 $size main/binary-amd64/$fname
"
        sha256sums+=" $sha256 $size main/binary-amd64/$fname
"
    done

    cat > "$release_file" <<EOF
Origin: $origin
Label: $label
Suite: $suite
Codename: $codename
Architectures: amd64
Components: main
Description: Nix and Lix packages for $distro
Date: $(date -R)
MD5Sum:
$md5sums
SHA1:
$sha1sums
SHA256:
$sha256sums
EOF

    echo "Generated Release for $distro"
}

# Sign Release file to create InRelease and Release.gpg
sign_release() {
    local output_dir="$1"

    local release_file="$output_dir/Release"

    # Create InRelease (clearsigned)
    gpg --clearsign -o "$output_dir/InRelease" "$release_file"

    # Create Release.gpg (detached signature)
    gpg -abs -o "$output_dir/Release.gpg" "$release_file"

    echo "Signed Release files"
}

# Main
main() {
    local artifacts_dir="${1:-}"

    if [[ -z "$artifacts_dir" ]]; then
        usage
        exit 1
    fi

    if [[ ! -d "$artifacts_dir" ]]; then
        echo "Error: Artifacts directory not found: $artifacts_dir" >&2
        exit 1
    fi

    echo "Generating apt repository..."
    echo "  Artifacts: $artifacts_dir"
    echo "  Output: $REPO_DIR"
    echo "  Release URL: $RELEASE_URL"

    # Clean and create repo directory
    rm -rf "$REPO_DIR"
    mkdir -p "$REPO_DIR"

    # Copy GPG public key
    if [[ -f "$SCRIPT_DIR/key.gpg" ]]; then
        cp "$SCRIPT_DIR/key.gpg" "$REPO_DIR/key.gpg"
    fi

    # Process each distribution
    for distro in "${DEBIAN_DISTROS[@]}"; do
        local distro_id="debian-$distro"
        local deb_dir="$artifacts_dir"/*"$distro_id"*

        # Check if we have artifacts for this distro
        local found_dir=""
        for d in $deb_dir; do
            [[ -d "$d" ]] && found_dir="$d" && break
        done

        if [[ -z "$found_dir" ]]; then
            echo "No artifacts found for $distro_id, skipping"
            continue
        fi

        echo "Processing $distro_id..."

        local suite_dir="$REPO_DIR/dists/$distro/main/binary-amd64"
        mkdir -p "$suite_dir"

        generate_packages "$distro_id" "$found_dir" "$suite_dir"
        generate_release "$distro_id" "$distro" "$REPO_DIR/dists/$distro"
        sign_release "$REPO_DIR/dists/$distro"
    done

    for distro in "${UBUNTU_DISTROS[@]}"; do
        local distro_id="ubuntu-$distro"
        local deb_dir="$artifacts_dir"/*"$distro_id"*

        # Check if we have artifacts for this distro
        local found_dir=""
        for d in $deb_dir; do
            [[ -d "$d" ]] && found_dir="$d" && break
        done

        if [[ -z "$found_dir" ]]; then
            echo "No artifacts found for $distro_id, skipping"
            continue
        fi

        echo "Processing $distro_id..."

        local suite_dir="$REPO_DIR/dists/$distro/main/binary-amd64"
        mkdir -p "$suite_dir"

        generate_packages "$distro_id" "$found_dir" "$suite_dir"
        generate_release "$distro_id" "$distro" "$REPO_DIR/dists/$distro"
        sign_release "$REPO_DIR/dists/$distro"
    done

    # Create index page
    cat > "$REPO_DIR/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>nix.deb - Nix and Lix packages for Debian/Ubuntu</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 2rem; }
        h1 { color: #333; }
        code { background: #f4f4f4; padding: 0.2rem 0.4rem; border-radius: 3px; }
        pre { background: #f4f4f4; padding: 1rem; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>nix.deb</h1>
    <p>Nix and Lix packages for Debian and Ubuntu, built with minimal runtime dependencies.</p>

    <h2>Installation</h2>
    <pre><code># Add the repository
curl -fsSL https://nix-deb.github.io/nix.deb/key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/nix-deb.gpg
echo "deb [signed-by=/usr/share/keyrings/nix-deb.gpg] https://nix-deb.github.io/nix.deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/nix-deb.list

# Install
sudo apt update
sudo apt install nix    # or: sudo apt install lix</code></pre>

    <h2>Supported Distributions</h2>
    <h3>Debian</h3>
    <ul>
        <li>Stretch (9)</li>
        <li>Buster (10)</li>
        <li>Bullseye (11)</li>
        <li>Bookworm (12)</li>
        <li>Trixie (13)</li>
    </ul>

    <h3>Ubuntu</h3>
    <ul>
        <li>Xenial (16.04)</li>
        <li>Bionic (18.04)</li>
        <li>Focal (20.04)</li>
        <li>Jammy (22.04)</li>
        <li>Noble (24.04)</li>
    </ul>

    <h2>Source</h2>
    <p><a href="https://github.com/nix-deb/nix.deb">github.com/nix-deb/nix.deb</a></p>
</body>
</html>
EOF

    echo ""
    echo "Repository generated at: $REPO_DIR"
    echo "Files:"
    find "$REPO_DIR" -type f | sort
}

main "$@"
