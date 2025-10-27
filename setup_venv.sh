#!/bin/bash
# Setup Python virtual environment and install dependencies

set -e

echo "Setting up Python virtual environment..."

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

echo "Activating virtual environment..."
echo "Installing required dependencies..."

# Upgrade pip first
pip install --upgrade pip

# Install requirements from requirements.txt if it exists, otherwise install core dependencies
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
else
    pip install oracledb jinja2 jsonschema pytest black pylint
fi

echo ""
echo "Setup complete! To activate the virtual environment, run:"
echo "  source venv/bin/activate"
echo ""
echo "To deactivate, run:"
echo "  deactivate"

