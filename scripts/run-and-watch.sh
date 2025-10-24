#!/bin/bash
# Run a GitHub workflow and automatically watch the latest run
# Commits and pushes all changes before running the workflow
# Usage: ./scripts/run-and-watch.sh "Workflow Name"
# Example: ./scripts/run-and-watch.sh "Test Oracle Action Simple"

set -e

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 \"Workflow Name\""
    echo "Example: $0 \"Test Oracle Action Simple\""
    exit 1
fi

WORKFLOW_NAME="$1"

echo "🔍 Checking for uncommitted changes..."
if ! git diff --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo "📝 Found uncommitted changes, committing and pushing..."
    
    # Add all changes (tracked and untracked)
    git add .
    
    # Create a commit message with timestamp
    COMMIT_MSG="Auto-commit before running workflow: ${WORKFLOW_NAME} ($(date '+%Y-%m-%d %H:%M:%S'))"
    git commit -m "$COMMIT_MSG"
    
    # Push to origin
    echo "⬆️  Pushing changes to origin..."
    git push origin $(git branch --show-current)
    
    echo "✅ Changes committed and pushed"
    echo "   Commit: $COMMIT_MSG"
    echo ""
else
    echo "✅ No uncommitted changes found"
    echo ""
fi

echo "🚀 Triggering workflow: ${WORKFLOW_NAME}"
gh workflow run "${WORKFLOW_NAME}"

echo "⏳ Waiting for workflow to start..."
sleep 5

echo "🔍 Getting latest run ID..."
RUN_ID=$(gh run list --workflow="${WORKFLOW_NAME}" --limit 1 --json databaseId -q '.[0].databaseId')

if [[ -z "${RUN_ID}" ]]; then
    echo "❌ Could not find run ID for workflow: ${WORKFLOW_NAME}"
    exit 1
fi

echo "👀 Watching run ID: ${RUN_ID}"
gh run watch "${RUN_ID}"

# Check the final status and show logs if failed
echo ""
echo "🔍 Checking final status..."
STATUS=$(gh run view "${RUN_ID}" --json status,conclusion -q '.status + ":" + .conclusion')
echo "Final status: ${STATUS}"

if [[ "${STATUS}" == *"failure"* || "${STATUS}" == *"cancelled"* ]]; then
    echo ""
    echo "❌ Workflow failed! Analyzing logs..."
    echo "==================== ERROR ANALYSIS ===================="
    
    # Get failed logs and try to extract meaningful errors
    echo "📋 Getting failure logs..."
    FAILED_LOGS=$(gh run view "${RUN_ID}" --log-failed 2>/dev/null || echo "Could not retrieve failed logs")
    
    if [[ "${FAILED_LOGS}" != "Could not retrieve failed logs" ]]; then
        echo ""
        echo "🔍 Common error patterns found:"
        echo "----------------------------------------"
        
        # Look for Python syntax errors
        echo "${FAILED_LOGS}" | grep -i "syntaxerror\|invalid syntax" | head -3 || true
        
        # Look for Oracle/database errors
        echo "${FAILED_LOGS}" | grep -i "ora-\|database error\|connection.*failed" | head -3 || true
        
        # Look for Docker errors
        echo "${FAILED_LOGS}" | grep -i "docker.*error\|container.*failed\|image.*not found" | head -3 || true
        
        # Look for general execution errors
        echo "${FAILED_LOGS}" | grep -i "error:\|failed:\|exception:" | head -5 || true
        
        # Look for process exit codes
        echo "${FAILED_LOGS}" | grep -i "process completed with exit code\|command.*failed" | head -3 || true
        
        echo "----------------------------------------"
        echo ""
        echo "📄 For full logs, run:"
        echo "  gh run view ${RUN_ID} --log-failed"
        echo ""
        echo "🌐 View in browser:"
        echo "  gh run view ${RUN_ID} --web"
        
    else
        echo "⚠️  Could not retrieve detailed error logs"
        echo "🌐 View run details in browser:"
        echo "  gh run view ${RUN_ID} --web"
    fi
    
    echo "======================================================"
    exit 1
    
elif [[ "${STATUS}" == *"success"* ]]; then
    echo ""
    echo "✅ Workflow completed successfully!"
    echo "🌐 View results: gh run view ${RUN_ID} --web"
    
else
    echo ""
    echo "ℹ️  Workflow status: ${STATUS}"
    echo "🌐 View details: gh run view ${RUN_ID} --web"
fi