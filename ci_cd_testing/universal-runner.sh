#!/bin/bash

# Universal Workflow Runner
# A comprehensive tool for running and monitoring any type of workflow or process
# Supports GitHub Actions, local scripts, Docker containers, and more

set -euo pipefail

# Script configuration
SCRIPT_NAME="universal-runner.sh"
VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "Error occurred on line $line_number (exit code: $exit_code)"
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# Help system
show_help() {
    cat << EOF
🚀 Universal Workflow Runner v${VERSION}
=====================================

Usage: $SCRIPT_NAME <command> [options] [target]

Commands:
  github <workflow>     Run and watch GitHub Actions workflow
  local <script>        Run and watch local script
  docker <container>    Run and watch Docker container
  compose <service>     Run and watch Docker Compose service
  watch <process>       Watch existing process by PID
  list                  List available workflows/processes
  status                Show status of recent runs

Options:
  --auto-commit, -c     Auto-commit changes before running
  --push, -p            Push changes to remote repository
  --watch, -w           Watch the process (default: true)
  --no-watch, -n        Don't watch, just trigger
  --timeout, -t <sec>   Set timeout for process (default: 300)
  --retry, -r <count>   Retry failed runs (default: 0)
  --verbose, -v         Verbose output
  --debug, -d           Debug mode
  --help, -h            Show this help

Examples:
  $SCRIPT_NAME github "Oracle Database Tests"     # Run GitHub workflow
  $SCRIPT_NAME local ./scripts/test.sh            # Run local script
  $SCRIPT_NAME docker oracle:21-slim              # Run Docker container
  $SCRIPT_NAME compose oracle-db                  # Run Docker Compose service
  $SCRIPT_NAME watch 12345                        # Watch process by PID
  $SCRIPT_NAME list                               # List available workflows
  $SCRIPT_NAME status                             # Show recent run status

GitHub Actions:
  $SCRIPT_NAME github "Test Oracle Action" --auto-commit --push
  $SCRIPT_NAME github "Security Scan" --timeout 600
  $SCRIPT_NAME github "Performance Test" --retry 2

Local Scripts:
  $SCRIPT_NAME local ./scripts/dev-tools.sh trunk all
  $SCRIPT_NAME local ./scripts/init-oracle-ci.sh advanced

Docker:
  $SCRIPT_NAME docker oracle:21-slim --timeout 1800
  $SCRIPT_NAME compose oracle-db --watch

Process Monitoring:
  $SCRIPT_NAME watch 12345 --timeout 300
  $SCRIPT_NAME status

EOF
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    command -v git >/dev/null 2>&1 || missing_deps+=("git")
    command -v ps >/dev/null 2>&1 || missing_deps+=("ps")
    
    # Check for optional commands
    local optional_deps=()
    command -v gh >/dev/null 2>&1 || optional_deps+=("gh")
    command -v docker >/dev/null 2>&1 || optional_deps+=("docker")
    command -v docker-compose >/dev/null 2>&1 || optional_deps+=("docker-compose")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install the missing dependencies and try again"
        exit 1
    fi
    
    if [[ ${#optional_deps[@]} -gt 0 ]]; then
        log_warning "Optional dependencies not found: ${optional_deps[*]}"
        log_info "Some features may not be available"
    fi
    
    log_debug "Dependencies checked"
}

# Git operations
git_auto_commit() {
    log_info "🔍 Checking for uncommitted changes..."
    
    if ! git diff --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
        log_info "📝 Found uncommitted changes, committing..."
        
        # Add all changes (tracked and untracked)
        git add .
        
        # Create a commit message with timestamp
        local commit_msg="Auto-commit before running workflow: $(date '+%Y-%m-%d %H:%M:%S')"
        git commit -m "$commit_msg"
        
        log_success "Changes committed: $commit_msg"
        return 0
    else
        log_info "✅ No uncommitted changes found"
        return 1
    fi
}

git_push() {
    log_info "⬆️  Pushing changes to remote repository..."
    
    local current_branch
    current_branch=$(git branch --show-current)
    
    if git push origin "$current_branch"; then
        log_success "Changes pushed to origin/$current_branch"
    else
        log_error "Failed to push changes to remote repository"
        exit 1
    fi
}

# GitHub Actions operations
run_github_workflow() {
    local workflow_name="$1"
    local auto_commit="${2:-false}"
    local push="${3:-false}"
    local watch="${4:-true}"
    local timeout="${5:-300}"
    local retry_count="${6:-0}"
    
    log_info "🚀 Running GitHub Actions workflow: $workflow_name"
    
    # Check if gh CLI is available
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI (gh) is not installed"
        log_info "Install with: https://cli.github.com/"
        exit 1
    fi
    
    # Auto-commit if requested
    if [[ "$auto_commit" == "true" ]]; then
        if git_auto_commit; then
            if [[ "$push" == "true" ]]; then
                git_push
            fi
        fi
    fi
    
    # Run the workflow
    log_info "Triggering workflow: $workflow_name"
    if ! gh workflow run "$workflow_name"; then
        log_error "Failed to trigger workflow: $workflow_name"
        exit 1
    fi
    
    if [[ "$watch" == "false" ]]; then
        log_success "Workflow triggered successfully (not watching)"
        return 0
    fi
    
    # Wait for workflow to start
    log_info "⏳ Waiting for workflow to start..."
    sleep 5
    
    # Get the latest run ID
    log_info "🔍 Getting latest run ID..."
    local run_id
    run_id=$(gh run list --workflow="$workflow_name" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || echo "")
    
    if [[ -z "$run_id" ]]; then
        log_error "Could not find run ID for workflow: $workflow_name"
        exit 1
    fi
    
    log_info "👀 Watching run ID: $run_id"
    
    # Watch the workflow with timeout
    local start_time
    start_time=$(date +%s)
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            log_error "Workflow timed out after ${timeout} seconds"
            exit 1
        fi
        
        # Check workflow status
        local status
        status=$(gh run view "$run_id" --json status,conclusion -q '.status + ":" + .conclusion' 2>/dev/null || echo "unknown:unknown")
        
        case "$status" in
            "completed:success")
                log_success "✅ Workflow completed successfully!"
                log_info "🌐 View results: gh run view $run_id --web"
                return 0
                ;;
            "completed:failure"|"completed:cancelled")
                log_error "❌ Workflow failed!"
                analyze_github_failure "$run_id"
                return 1
                ;;
            "in_progress:"*|"queued:"*)
                log_info "⏳ Workflow is running... (${elapsed}s elapsed)"
                sleep 10
                ;;
            *)
                log_warning "Unknown status: $status"
                sleep 5
                ;;
        esac
    done
}

# Analyze GitHub workflow failures
analyze_github_failure() {
    local run_id="$1"
    
    log_info "🔍 Analyzing workflow failure..."
    echo "==================== ERROR ANALYSIS ===================="
    
    # Get failed logs
    local failed_logs
    failed_logs=$(gh run view "$run_id" --log-failed 2>/dev/null || echo "Could not retrieve failed logs")
    
    if [[ "$failed_logs" != "Could not retrieve failed logs" ]]; then
        echo ""
        log_info "🔍 Common error patterns found:"
        echo "----------------------------------------"
        
        # Look for Python syntax errors
        echo "$failed_logs" | grep -i "syntaxerror\|invalid syntax" | head -3 || true
        
        # Look for Oracle/database errors
        echo "$failed_logs" | grep -i "ora-\|database error\|connection.*failed" | head -3 || true
        
        # Look for Docker errors
        echo "$failed_logs" | grep -i "docker.*error\|container.*failed\|image.*not found" | head -3 || true
        
        # Look for general execution errors
        echo "$failed_logs" | grep -i "error:\|failed:\|exception:" | head -5 || true
        
        # Look for process exit codes
        echo "$failed_logs" | grep -i "process completed with exit code\|command.*failed" | head -3 || true
        
        echo "----------------------------------------"
        echo ""
        log_info "📄 For full logs, run:"
        echo "  gh run view $run_id --log-failed"
        echo ""
        log_info "🌐 View in browser:"
        echo "  gh run view $run_id --web"
    else
        log_warning "⚠️  Could not retrieve detailed error logs"
        log_info "🌐 View run details in browser:"
        echo "  gh run view $run_id --web"
    fi
    
    echo "======================================================"
}

# Local script operations
run_local_script() {
    local script_path="$1"
    local watch="${2:-true}"
    local timeout="${3:-300}"
    local retry_count="${4:-0}"
    shift 4
    
    log_info "🚀 Running local script: $script_path"
    
    # Check if script exists and is executable
    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        exit 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        log_warning "Script is not executable, making it executable..."
        chmod +x "$script_path"
    fi
    
    # Run the script
    local start_time
    start_time=$(date +%s)
    
    if [[ "$watch" == "true" ]]; then
        log_info "👀 Running and watching script..."
        
        # Run script in background and capture PID
        log_debug "Running: $script_path with args: $*"
        "$script_path" "$@" &
        local script_pid=$!
        
        log_info "📊 Script PID: $script_pid"
        
        # Watch the process
        while kill -0 "$script_pid" 2>/dev/null; do
            local current_time
            current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            
            if [[ $elapsed -gt $timeout ]]; then
                log_error "Script timed out after ${timeout} seconds"
                kill -TERM "$script_pid" 2>/dev/null || true
                exit 1
            fi
            
            log_debug "Script running... (${elapsed}s elapsed)"
            sleep 5
        done
        
        # Wait for process to complete and get exit code
        wait "$script_pid"
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_success "✅ Script completed successfully!"
        else
            log_error "❌ Script failed with exit code: $exit_code"
            exit $exit_code
        fi
    else
        log_info "🚀 Running script (not watching)..."
        if "$script_path" "$@"; then
            log_success "✅ Script completed successfully!"
        else
            log_error "❌ Script failed"
            exit 1
        fi
    fi
}

# Docker operations
run_docker_container() {
    local container_name="$1"
    local watch="${2:-true}"
    local timeout="${3:-300}"
    local retry_count="${4:-0}"
    
    log_info "🐳 Running Docker container: $container_name"
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Run the container
    local start_time
    start_time=$(date +%s)
    
    if [[ "$watch" == "true" ]]; then
        log_info "👀 Running and watching container..."
        
        # Run container and capture output
        if docker run --rm "$container_name"; then
            log_success "✅ Container completed successfully!"
        else
            log_error "❌ Container failed"
            exit 1
        fi
    else
        log_info "🐳 Running container (not watching)..."
        docker run --rm "$container_name"
    fi
}

# Docker Compose operations
run_docker_compose() {
    local service_name="$1"
    local watch="${2:-true}"
    local timeout="${3:-300}"
    local retry_count="${4:-0}"
    
    log_info "🐳 Running Docker Compose service: $service_name"
    
    # Check if Docker Compose is available
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    # Run the service
    if [[ "$watch" == "true" ]]; then
        log_info "👀 Running and watching service..."
        
        if docker-compose up --build "$service_name"; then
            log_success "✅ Service completed successfully!"
        else
            log_error "❌ Service failed"
            exit 1
        fi
    else
        log_info "🐳 Running service (not watching)..."
        docker-compose up --build "$service_name"
    fi
}

# Process monitoring
watch_process() {
    local pid="$1"
    local timeout="${2:-300}"
    
    log_info "👀 Watching process PID: $pid"
    
    # Check if process exists
    if ! kill -0 "$pid" 2>/dev/null; then
        log_error "Process $pid does not exist or is not accessible"
        exit 1
    fi
    
    local start_time
    start_time=$(date +%s)
    
    while kill -0 "$pid" 2>/dev/null; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            log_error "Process timed out after ${timeout} seconds"
            exit 1
        fi
        
        log_debug "Process running... (${elapsed}s elapsed)"
        sleep 5
    done
    
    log_success "✅ Process completed successfully!"
}

# List available workflows/processes
list_available() {
    log_info "📋 Available workflows and processes:"
    echo ""
    
    # List GitHub workflows
    if command -v gh >/dev/null 2>&1; then
        log_info "🔧 GitHub Actions Workflows:"
        gh workflow list 2>/dev/null || log_warning "Could not list GitHub workflows"
        echo ""
    fi
    
    # List local scripts
    log_info "📜 Local Scripts:"
    find "$SCRIPT_DIR" -name "*.sh" -type f -executable | head -10
    echo ""
    
    # List Docker containers
    if command -v docker >/dev/null 2>&1; then
        log_info "🐳 Docker Images:"
        docker images --format "table {{.Repository}}:{{.Tag}}" | head -10
        echo ""
    fi
    
    # List Docker Compose services
    if [[ -f "docker-compose.yml" ]] && command -v docker-compose >/dev/null 2>&1; then
        log_info "🐳 Docker Compose Services:"
        docker-compose config --services 2>/dev/null || log_warning "Could not list Docker Compose services"
        echo ""
    fi
    
    # List running processes
    log_info "🔄 Running Processes:"
    ps aux | grep -v grep | head -10
}

# Show status of recent runs
show_status() {
    log_info "📊 Recent run status:"
    echo ""
    
    # Show recent GitHub workflow runs
    if command -v gh >/dev/null 2>&1; then
        log_info "🔧 Recent GitHub Workflow Runs:"
        gh run list --limit 5 2>/dev/null || log_warning "Could not list recent workflow runs"
        echo ""
    fi
    
    # Show recent local script runs (from history)
    log_info "📜 Recent Local Script Runs:"
    history | grep -E "\.sh|universal-runner" | tail -5 || log_warning "No recent script runs found"
    echo ""
    
    # Show Docker container status
    if command -v docker >/dev/null 2>&1; then
        log_info "🐳 Docker Container Status:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -10
        echo ""
    fi
}

# Main execution
main() {
    local command="${1:-help}"
    local auto_commit=false
    local push=false
    local watch=true
    local timeout=300
    local retry_count=0
    
    # Parse global options
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto-commit|-c)
                auto_commit=true
                shift
                ;;
            --push|-p)
                push=true
                shift
                ;;
            --watch|-w)
                watch=true
                shift
                ;;
            --no-watch|-n)
                watch=false
                shift
                ;;
            --timeout|-t)
                timeout="$2"
                shift 2
                ;;
            --retry|-r)
                retry_count="$2"
                shift 2
                ;;
            --verbose|-v)
                export DEBUG=true
                shift
                ;;
            --debug|-d)
                export DEBUG=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version)
                echo "$SCRIPT_NAME v$VERSION"
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Check dependencies
    check_dependencies
    
    # Route to appropriate handler
    case "$command" in
        "github")
            if [[ $# -lt 1 ]]; then
                log_error "GitHub workflow name is required"
                log_info "Usage: $SCRIPT_NAME github \"Workflow Name\""
                exit 1
            fi
            run_github_workflow "$1" "$auto_commit" "$push" "$watch" "$timeout" "$retry_count"
            ;;
        "local")
            if [[ $# -lt 1 ]]; then
                log_error "Local script path is required"
                log_info "Usage: $SCRIPT_NAME local ./script.sh"
                exit 1
            fi
            local script_path="$1"
            shift
            log_debug "Script path: $script_path"
            log_debug "Remaining args: $*"
            # Pass remaining arguments to the script
            run_local_script "$script_path" "$watch" "$timeout" "$retry_count" "$@"
            ;;
        "docker")
            if [[ $# -lt 1 ]]; then
                log_error "Docker container name is required"
                log_info "Usage: $SCRIPT_NAME docker container:tag"
                exit 1
            fi
            run_docker_container "$1" "$watch" "$timeout" "$retry_count"
            ;;
        "compose")
            if [[ $# -lt 1 ]]; then
                log_error "Docker Compose service name is required"
                log_info "Usage: $SCRIPT_NAME compose service-name"
                exit 1
            fi
            run_docker_compose "$1" "$watch" "$timeout" "$retry_count"
            ;;
        "watch")
            if [[ $# -lt 1 ]]; then
                log_error "Process PID is required"
                log_info "Usage: $SCRIPT_NAME watch 12345"
                exit 1
            fi
            watch_process "$1" "$timeout"
            ;;
        "list")
            list_available
            ;;
        "status")
            show_status
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function
main "$@"
