#!/bin/bash

# Government CCaaS Admin UI - Installation Script
# This script installs all dependencies for the monorepo

set -e  # Exit on error

echo "================================================"
echo "  Government CCaaS Admin UI - Installation"
echo "================================================"
echo ""

# Check for Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is not installed"
    echo "   Please install Node.js 18+ from https://nodejs.org/"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Error: Node.js version must be 18 or higher"
    echo "   Current version: $(node -v)"
    echo "   Please upgrade Node.js from https://nodejs.org/"
    exit 1
fi

echo "✓ Node.js version: $(node -v)"
echo "✓ npm version: $(npm -v)"
echo ""

# Install root dependencies
echo "📦 Installing root dependencies..."
npm install

# Install UI package dependencies
echo ""
echo "📦 Installing UI package dependencies..."
npm install -w packages/ui

# Install API package dependencies
echo ""
echo "📦 Installing API package dependencies..."
npm install -w packages/api

# Install archiver for package generation
echo ""
echo "📦 Installing archiver for package generation..."
npm install -w packages/api archiver @types/archiver

echo ""
echo "================================================"
echo "  ✅ Installation Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Start the development servers:"
echo "     npm run dev"
echo ""
echo "  2. Or start them individually:"
echo "     npm run dev:ui    # UI on http://localhost:5173"
echo "     npm run dev:api   # API on http://localhost:3001"
echo ""
