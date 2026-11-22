#!/bin/bash
# Build script for AIClient TLS Proxy

set -e

echo "Building AIClient TLS Proxy..."

# Build for Linux (VPS)
GOOS=linux GOARCH=amd64 go build -o aiclient-proxy-linux-amd64 main.go

# Build for macOS (local testing)
GOOS=darwin GOARCH=amd64 go build -o aiclient-proxy-darwin-amd64 main.go

# Build for Windows (optional)
GOOS=windows GOARCH=amd64 go build -o aiclient-proxy-windows-amd64.exe main.go

echo "Build complete:"
ls -la aiclient-proxy-*

echo ""
echo "Deploy to VPS:"
echo "  scp aiclient-proxy-linux-amd64 user@your-vps:/opt/aiclient-proxy/"
echo ""
echo "Run on VPS:"
echo "  ./aiclient-proxy-linux-amd64 -listen :8080 -target api.openai.com -v"
echo ""
echo "Or with systemd service (see proxy.service)"