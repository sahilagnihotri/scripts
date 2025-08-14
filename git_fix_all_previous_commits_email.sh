#!/bin/bash

# Git Email Fix Script
# ====================
#
# USAGE:
#   1. Copy this script to your Git repository directory
#   2. Make it executable: chmod +x git_fix_all_previous_commits_email.sh
#   3. Run it: ./git_fix_all_previous_commits_email.sh
#   4. Follow the prompts to enter old and new email addresses
#
# ALTERNATIVE USAGE (with environment variables):
#   OLD_EMAIL="old@example.com" NEW_EMAIL="new@example.com" ./git_fix_all_previous_commits_email.sh
#
# WHAT IT DOES:
#   - Changes the author and committer email for ALL previous commits
#   - Rewrites Git history (changes commit hashes)
#   - Works with both git filter-repo (recommended) and git filter-branch
#
# REQUIREMENTS:
#   - Must be run from inside a Git repository
#   - Optional: Install git-filter-repo for better performance (pip install git-filter-repo)
#
# WARNING:
#   - This rewrites Git history and changes ALL commit hashes
#   - If already pushed to remote, you'll need: git push --force-with-lease
#   - All collaborators will need to re-clone or rebase their work
#
# EXAMPLES:
#   ./git_fix_all_previous_commits_email.sh
#   OLD_EMAIL="john@oldcompany.com" NEW_EMAIL="john@newcompany.com" ./git_fix_all_previous_commits_email.sh

# Script to fix email addresses in all previous Git commits
# WARNING: This rewrites Git history and changes commit hashes!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Git Email Fix Script${NC}"
echo "This script will change the email address for all previous commits."
echo -e "${RED}WARNING: This rewrites Git history and changes commit hashes!${NC}"
echo

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a Git repository${NC}"
    exit 1
fi

# Get current email if not provided
if [ -z "$OLD_EMAIL" ]; then
    echo "Enter the OLD email address to replace:"
    read -r OLD_EMAIL
fi

if [ -z "$NEW_EMAIL" ]; then
    echo "Enter the NEW email address:"
    read -r NEW_EMAIL
fi

# Validate email addresses
if [[ ! "$OLD_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo -e "${RED}Error: Invalid old email format${NC}"
    exit 1
fi

if [[ ! "$NEW_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo -e "${RED}Error: Invalid new email format${NC}"
    exit 1
fi

echo
echo "OLD EMAIL: $OLD_EMAIL"
echo "NEW EMAIL: $NEW_EMAIL"
echo

# Check if there are any commits with the old email
COMMIT_COUNT=$(git log --all --pretty=format:"%ae" | grep -c "^$OLD_EMAIL$" || true)

if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No commits found with email: $OLD_EMAIL${NC}"
    exit 0
fi

echo "Found $COMMIT_COUNT commits with the old email address."
echo

# Final confirmation
echo -e "${RED}This will rewrite Git history. Continue? (y/N)${NC}"
read -r CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo
echo -e "${YELLOW}Starting email replacement...${NC}"

# Check if git filter-repo is available
if command -v git-filter-repo > /dev/null 2>&1; then
    echo "Using git filter-repo (recommended method)..."
    git filter-repo --email-callback "
return email.replace(b'$OLD_EMAIL', b'$NEW_EMAIL')
" --force
else
    echo "Using git filter-branch (git filter-repo not found)..."
    git filter-branch -f --env-filter "
if [ \"\$GIT_COMMITTER_EMAIL\" = \"$OLD_EMAIL\" ]; then
    export GIT_COMMITTER_EMAIL=\"$NEW_EMAIL\"
fi
if [ \"\$GIT_AUTHOR_EMAIL\" = \"$OLD_EMAIL\" ]; then
    export GIT_AUTHOR_EMAIL=\"$NEW_EMAIL\"
fi
" --tag-name-filter cat -- --branches --tags

    # Clean up refs
    git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d
fi

echo
echo -e "${GREEN}Email replacement completed!${NC}"
echo
echo "Next steps:"
echo "1. Verify the changes: git log --oneline"
echo "2. If you've already pushed to remote, force push: git push --force-with-lease"
echo "3. Notify collaborators to re-clone or rebase their work"
echo
echo -e "${YELLOW}Note: All commit hashes have changed!${NC}"