#!/bin/bash

# GitHub Pages Sync Script
# =========================
#
# USAGE:
#   1. Make it executable: chmod +x sync-gh-pages.sh
#   2. Run it: ./sync-gh-pages.sh [REPO_PATH]
#
# ALTERNATIVE USAGE (with environment variables):
#   REPO_PATH="/path/to/repo" ./sync-gh-pages.sh
#
# WHAT IT DOES:
#   - Switches to gh-pages branch
#   - Merges master branch into gh-pages
#   - Pushes gh-pages to origin
#   - Switches back to master branch
#
# REQUIREMENTS:
#   - Git repository with gh-pages and master branches
#   - Repository must have a remote origin configured
#
# EXAMPLES:
#   ./sync-gh-pages.sh
#   ./sync-gh-pages.sh /path/to/my/repo
#   REPO_PATH="/home/user/project" ./sync-gh-pages.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}GitHub Pages Sync Script${NC}"
echo "This script syncs master branch to gh-pages branch."
echo

# Handle repository path parameter
REPO_PATH="${REPO_PATH:-$1}"
if [ -n "$REPO_PATH" ]; then
    echo "Using repository path: $REPO_PATH"
    if [ ! -d "$REPO_PATH" ]; then
        echo -e "${RED}Error: Directory does not exist: $REPO_PATH${NC}"
        exit 1
    fi
    cd "$REPO_PATH" || {
        echo -e "${RED}Error: Cannot access directory: $REPO_PATH${NC}"
        exit 1
    }
    echo "Changed to repository directory: $(pwd)"
    echo
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a Git repository${NC}"
    if [ -n "$REPO_PATH" ]; then
        echo "The specified path is not a Git repository: $REPO_PATH"
    else
        echo "Current directory is not a Git repository: $(pwd)"
    fi
    exit 1
fi

# Check if master branch exists
if ! git show-ref --verify --quiet refs/heads/master; then
    echo -e "${RED}Error: master branch does not exist${NC}"
    echo "This script requires a master branch to sync from."
    exit 1
fi

# Check if gh-pages branch exists
if ! git show-ref --verify --quiet refs/heads/gh-pages; then
    echo -e "${YELLOW}Warning: gh-pages branch does not exist${NC}"
    echo "Do you want to create it? (y/N)"
    read -r CREATE_BRANCH
    if [[ "$CREATE_BRANCH" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Creating gh-pages branch...${NC}"
        git checkout -b gh-pages
    else
        echo "Operation cancelled."
        exit 0
    fi
fi

# Check if origin remote exists
if ! git remote get-url origin > /dev/null 2>&1; then
    echo -e "${RED}Error: No 'origin' remote configured${NC}"
    echo "Please configure a remote origin first: git remote add origin <url>"
    exit 1
fi

# Save current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $CURRENT_BRANCH"

echo
echo -e "${YELLOW}Starting GitHub Pages sync...${NC}"

echo -e "${BLUE}Switching to gh-pages branch...${NC}"
git checkout gh-pages

echo -e "${BLUE}Merging master into gh-pages...${NC}"
git merge master

echo -e "${BLUE}Pushing gh-pages to origin...${NC}"
git push origin gh-pages

echo -e "${BLUE}Switching back to $CURRENT_BRANCH branch...${NC}"
git checkout "$CURRENT_BRANCH"

echo
echo -e "${GREEN}GitHub Pages sync completed successfully!${NC}"
echo
echo "Next steps:"
echo "1. Check GitHub Pages settings in your repository"
echo "2. Verify deployment at your GitHub Pages URL"
echo "3. Wait a few minutes for changes to propagate"