#!/bin/bash
#
# extract_python_deps.sh
# © 2024 Andrew Shen <wildfootw@hoschoc.com>
#
# Distributed under the same license as odooBundle-Codebase.
#

# Check if a .deb file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <path_to_deb_file>"
    exit 1
fi

DEB_FILE="$1"

# Check if dpkg-deb is available
if ! command -v dpkg-deb &> /dev/null; then
    echo "Error: dpkg-deb is not installed. Please install the dpkg package."
    exit 1
fi

# Check if apt-rdepends is available
if ! command -v apt-rdepends &> /dev/null; then
    echo "Error: apt-rdepends is not installed. Please run: sudo apt-get install apt-rdepends"
    exit 1
fi

# Extract the Depends field from the .deb file
DEPENDS=$(dpkg-deb -I "$DEB_FILE" | grep -E '^ Depends:' | sed 's/^ Depends://' | tr ',' '\n' | sed 's/|.*//' | sed 's/(.*)//' | sed 's/^[ \t]*//' | sed 's/[ \t]*$//')

# Extract packages that start with python3-
PYTHON_PACKAGES=$(echo "$DEPENDS" | grep '^python3-')

if [ -z "$PYTHON_PACKAGES" ]; then
    echo "No python3-related packages found in $DEB_FILE."
    exit 0
fi

echo "Found the following python3-related packages in $DEB_FILE:"
echo "$PYTHON_PACKAGES"
echo ""

# Run apt-rdepends for each package and collect all dependencies
ALL_DEPENDS=()

for pkg in $PYTHON_PACKAGES; do
    echo "Processing dependencies for package $pkg..."
    DEP_LIST=$(apt-rdepends "$pkg" 2>/dev/null | grep -E '^[a-zA-Z0-9-]+$')
    ALL_DEPENDS+=($DEP_LIST)
done

# Remove duplicate package names
UNIQUE_DEPENDS=($(echo "${ALL_DEPENDS[@]}" | tr ' ' '\n' | sort -u))

echo ""
echo "List of all recursive dependencies:"
for dep in "${UNIQUE_DEPENDS[@]}"; do
    echo "$dep"
done

