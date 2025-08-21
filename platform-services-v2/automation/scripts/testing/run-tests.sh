#!/bin/bash

set -euo pipefail

echo "Running platform tests..."

# Unit tests
echo "Running unit tests..."
python -m pytest tests/unit/ -v

# Integration tests
echo "Running integration tests..."
python -m pytest tests/integration/ -v

# Security tests
echo "Running security tests..."
python -m pytest tests/security/ -v

echo "All tests completed!"
