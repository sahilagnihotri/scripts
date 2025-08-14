#!/bin/bash

# Git Repository Statistics Script
# ================================
#
# USAGE:
#   1. Make it executable: chmod +x git_repo_stats.sh
#   2. Run it: ./git_repo_stats.sh [REPO_PATH]
#
# ALTERNATIVE USAGE (with environment variables):
#   REPO_PATH="/path/to/repo" ./git_repo_stats.sh
#
# WHAT IT DOES:
#   - Shows comprehensive statistics about commit authors and committers
#   - Lists unique email addresses used in commits
#   - Shows commit counts by author/committer
#   - Displays recent commit history with detailed metadata
#
# REQUIREMENTS:
#   - Git repository (can be specified via REPO_PATH parameter or current directory)
#
# EXAMPLES:
#   ./git_repo_stats.sh
#   ./git_repo_stats.sh /path/to/my/repo
#   REPO_PATH="/home/user/project" ./git_repo_stats.sh

# Script to show comprehensive Git repository statistics

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}Git Repository Statistics${NC}"
echo "This script shows comprehensive commit statistics for the repository."
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

echo -e "${GREEN}Repository: $(basename "$(git rev-parse --show-toplevel)")${NC}"
echo -e "${GREEN}Path: $(git rev-parse --show-toplevel)${NC}"
echo

# Check if repository has any commits
if ! git rev-parse HEAD > /dev/null 2>&1; then
    echo -e "${YELLOW}No commits found in this repository.${NC}"
    exit 0
fi

echo -e "${YELLOW}=== REPOSITORY OVERVIEW ===${NC}"
TOTAL_COMMITS=$(git rev-list --all --count)
TOTAL_BRANCHES=$(git branch -a | wc -l | tr -d ' ')
TOTAL_AUTHORS=$(git log --all --pretty=format:"%an" | sort -u | wc -l | tr -d ' ')
echo "Total commits: $TOTAL_COMMITS"
echo "Total branches: $TOTAL_BRANCHES"
echo "Total unique authors: $TOTAL_AUTHORS"
echo

echo -e "${YELLOW}=== UNIQUE AUTHOR EMAILS ===${NC}"
git log --all --pretty=format:"%ae" | sort -u | while read -r email; do
    echo "  $email"
done
echo

echo -e "${YELLOW}=== UNIQUE COMMITTER EMAILS ===${NC}"
git log --all --pretty=format:"%ce" | sort -u | while read -r email; do
    echo "  $email"
done
echo

echo -e "${YELLOW}=== COMMIT COUNT BY AUTHOR EMAIL ===${NC}"
git log --all --pretty=format:"%ae" | sort | uniq -c | sort -nr | while read -r count email; do
    printf "  %3d commits: %s\n" "$count" "$email"
done
echo

echo -e "${YELLOW}=== COMMIT COUNT BY COMMITTER EMAIL ===${NC}"
git log --all --pretty=format:"%ce" | sort | uniq -c | sort -nr | while read -r count email; do
    printf "  %3d commits: %s\n" "$count" "$email"
done
echo

echo -e "${YELLOW}=== COMMIT COUNT BY AUTHOR NAME ===${NC}"
git log --all --pretty=format:"%an" | sort | uniq -c | sort -nr | while read -r count name; do
    printf "  %3d commits: %s\n" "$count" "$name"
done
echo

echo -e "${YELLOW}=== RECENT COMMITS (Last 10) ===${NC}"
echo "Format: [Hash] Author <email> | Committer <email> | Message"
git log -10 --pretty=format:"%C(yellow)%h%C(reset) %C(green)%an%C(reset) <%C(blue)%ae%C(reset)> | %C(green)%cn%C(reset) <%C(blue)%ce%C(reset)> | %s"
echo
echo

echo -e "${YELLOW}=== FIRST AND LAST COMMITS ===${NC}"
echo -e "${BLUE}First commit:${NC}"
git log --reverse --pretty=format:"  %C(yellow)%h%C(reset) %C(green)%an%C(reset) <%C(blue)%ae%C(reset)> %C(yellow)%ad%C(reset) | %s" --date=short | head -1
echo -e "${BLUE}Last commit:${NC}"
git log -1 --pretty=format:"  %C(yellow)%h%C(reset) %C(green)%an%C(reset) <%C(blue)%ae%C(reset)> %C(yellow)%ad%C(reset) | %s" --date=short
echo
echo

echo -e "${GREEN}Repository statistics complete!${NC}"
echo
echo "Useful commands for further analysis:"
echo "  git log --pretty=fuller                          # Detailed commit info"
echo "  git shortlog -sn                                 # Author commit counts"
echo "  git log --since='2023-01-01' --until='2023-12-31' # Commits in date range"
echo "  git log --author='email@example.com'             # Commits by specific author"
echo "  git log --grep='keyword'                         # Search commit messages"