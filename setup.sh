#!/bin/bash

# Ruan Cleaner Setup Script

echo "🚀 Setting up Ruan Cleaner..."

# Check for Swift
if ! command -v swift &> /dev/null; then
    echo "❌ Error: Swift is not installed."
    echo "Please install Xcode or the Swift toolchain from https://swift.org/download/"
    exit 1
fi

echo "✅ Swift found."
echo "📦 Fetching dependencies and building Ruan Cleaner..."

# Build the project
swift build -c release

if [ $? -eq 0 ]; then
    echo "🎉 Build successful!"
    echo "You can now run the app using: swift run -c release"
    echo "Or look for the binary in .build/release/"
else
    echo "❌ Build failed. Please check the errors above."
    exit 1
fi
