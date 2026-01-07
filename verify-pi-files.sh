#!/bin/bash
# Verify Raspberry Pi Files Are Available

echo "🔍 Verifying MiniRack Dashboard Pi files availability..."

BASE_URL="https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash"

FILES=(
    "raspberry-pi-install.sh"
    "create-pi-image.sh" 
    "pi-first-boot.sh"
    "README_RASPBERRY_PI.md"
    "deploy/dashboard_minimal.py"
    "deploy/index.html"
)

ALL_GOOD=true

for file in "${FILES[@]}"; do
    echo -n "Checking $file... "
    
    if curl -fsSL --head "$BASE_URL/$file" >/dev/null 2>&1; then
        echo "✅ Available"
    else
        echo "❌ Not found"
        ALL_GOOD=false
    fi
done

if [ "$ALL_GOOD" = true ]; then
    echo ""
    echo "🎉 All files are available for download!"
    echo ""
    echo "📋 Working download commands:"
    echo "curl -fsSL -o raspberry-pi-install.sh $BASE_URL/raspberry-pi-install.sh"
    echo "curl -fsSL -o create-pi-image.sh $BASE_URL/create-pi-image.sh"
    echo ""
    echo "🚀 Ready for Pi installation!"
else
    echo ""
    echo "❌ Some files are missing or not accessible"
    echo "💡 Files may need time to propagate or branch may be incorrect"
fi