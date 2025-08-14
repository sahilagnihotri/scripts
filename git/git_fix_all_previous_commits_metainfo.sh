#!/bin/bash

# Git Commit Metadata Fix Script
# ====================
#
# USAGE:
#   1. Make it executable: chmod +x git_fix_all_previous_commits_metainfo.sh
#   2. Run it: ./git_fix_all_previous_commits_metainfo.sh [REPO_PATH]
#   3. Follow the prompts to enter old and new email addresses
#
# ALTERNATIVE USAGE (with environment variables):
#   OLD_EMAIL="old@example.com" NEW_EMAIL="new@example.com" ./git_fix_all_previous_commits_metainfo.sh [REPO_PATH]
#   OLD_NAME="Old Name" NEW_NAME="New Name" OLD_EMAIL="old@example.com" NEW_EMAIL="new@example.com" ./git_fix_all_previous_commits_metainfo.sh
#   REPO_PATH="/path/to/repo" OLD_EMAIL="old@example.com" NEW_EMAIL="new@example.com" ./git_fix_all_previous_commits_metainfo.sh
#
# WHAT IT DOES:
#   - Changes the author and committer email for ALL previous commits
#   - Optionally changes the author and committer name for ALL previous commits
#   - Rewrites Git history (changes commit hashes)
#   - Works with both git filter-repo (recommended) and git filter-branch
#
# REQUIREMENTS:
#   - Git repository (can be specified via REPO_PATH parameter or current directory)
#   - Optional: Install git-filter-repo for better performance (pip install git-filter-repo)
#
# WARNING:
#   - This rewrites Git history and changes ALL commit hashes
#   - If already pushed to remote, you'll need: git push --force-with-lease
#   - All collaborators will need to re-clone or rebase their work
#
# EXAMPLES:
#   ./git_fix_all_previous_commits_metainfo.sh
#   ./git_fix_all_previous_commits_metainfo.sh /path/to/my/repo
#   OLD_EMAIL="john@oldcompany.com" NEW_EMAIL="john@newcompany.com" ./git_fix_all_previous_commits_metainfo.sh
#   OLD_NAME="John Doe" NEW_NAME="John Smith" OLD_EMAIL="john@oldcompany.com" NEW_EMAIL="john@newcompany.com" ./git_fix_all_previous_commits_metainfo.sh
#   REPO_PATH="/home/user/project" ./git_fix_all_previous_commits_metainfo.sh

# Script to fix email addresses and names in all previous Git commits
# WARNING: This rewrites Git history and changes commit hashes!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Git Commit Metadata Fix Script${NC}"
echo "This script will change the email address and optionally the name for all previous commits."
echo -e "${RED}WARNING: This rewrites Git history and changes commit hashes!${NC}"
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

# Get current email if not provided
if [ -z "$OLD_EMAIL" ]; then
    echo "Enter the OLD email address to replace:"
    read -r OLD_EMAIL
fi

if [ -z "$NEW_EMAIL" ]; then
    echo "Enter the NEW email address:"
    read -r NEW_EMAIL
fi

# Get current name if not provided (optional)
if [ -z "$OLD_NAME" ] && [ -z "$NEW_NAME" ]; then
    echo
    echo "Do you also want to change the author/committer name? (y/N)"
    read -r CHANGE_NAME
    if [[ "$CHANGE_NAME" =~ ^[Yy]$ ]]; then
        echo "Enter the OLD name to replace (leave empty to skip):"
        read -r OLD_NAME
        if [ -n "$OLD_NAME" ]; then
            echo "Enter the NEW name:"
            read -r NEW_NAME
        fi
    fi
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

# Validate name parameters (if provided)
if [ -n "$OLD_NAME" ] && [ -z "$NEW_NAME" ]; then
    echo -e "${RED}Error: NEW_NAME must be provided when OLD_NAME is specified${NC}"
    exit 1
fi

if [ -z "$OLD_NAME" ] && [ -n "$NEW_NAME" ]; then
    echo -e "${RED}Error: OLD_NAME must be provided when NEW_NAME is specified${NC}"
    exit 1
fi

echo
echo "OLD EMAIL: $OLD_EMAIL"
echo "NEW EMAIL: $NEW_EMAIL"
if [ -n "$OLD_NAME" ] && [ -n "$NEW_NAME" ]; then
    echo "OLD NAME:  $OLD_NAME"
    echo "NEW NAME:  $NEW_NAME"
fi
echo

# Check if there are any commits with the old email
COMMIT_COUNT=$(git log --all --pretty=format:"%ae" | grep -c "^$OLD_EMAIL$" || true)

if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No commits found with email: $OLD_EMAIL${NC}"
    exit 0
fi

echo "Found $COMMIT_COUNT commits with the old email address."

# Check if there are any commits with the old name (if specified)
if [ -n "$OLD_NAME" ]; then
    NAME_COMMIT_COUNT=$(git log --all --pretty=format:"%an" | grep -c "^$OLD_NAME$" || true)
    echo "Found $NAME_COMMIT_COUNT commits with the old name."
fi
echo

# Final confirmation
echo -e "${RED}This will rewrite Git history. Continue? (y/N)${NC}"
read -r CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo
echo -e "${YELLOW}Starting email/name replacement...${NC}"

# Check if git filter-repo is available
if command -v git-filter-repo > /dev/null 2>&1; then
    echo "Using git filter-repo (recommended method)..."
    
    # Build the callback script
    CALLBACK="return email.replace(b'$OLD_EMAIL', b'$NEW_EMAIL')"
    
    if [ -n "$OLD_NAME" ] && [ -n "$NEW_NAME" ]; then
        git filter-repo --email-callback "$CALLBACK" --name-callback "return name.replace(b'$OLD_NAME', b'$NEW_NAME')" --force
    else
        git filter-repo --email-callback "$CALLBACK" --force
    fi
else
    echo "Using git filter-branch (git filter-repo not found)..."
    
    ENV_FILTER="
if [ \"\$GIT_COMMITTER_EMAIL\" = \"$OLD_EMAIL\" ]; then
    export GIT_COMMITTER_EMAIL=\"$NEW_EMAIL\"
fi
if [ \"\$GIT_AUTHOR_EMAIL\" = \"$OLD_EMAIL\" ]; then
    export GIT_AUTHOR_EMAIL=\"$NEW_EMAIL\"
fi"
    
    if [ -n "$OLD_NAME" ] && [ -n "$NEW_NAME" ]; then
        ENV_FILTER="$ENV_FILTER
if [ \"\$GIT_COMMITTER_NAME\" = \"$OLD_NAME\" ]; then
    export GIT_COMMITTER_NAME=\"$NEW_NAME\"
fi
if [ \"\$GIT_AUTHOR_NAME\" = \"$OLD_NAME\" ]; then
    export GIT_AUTHOR_NAME=\"$NEW_NAME\"
fi"
    fi
    
    git filter-branch -f --env-filter "$ENV_FILTER" --tag-name-filter cat -- --branches --tags

    # Clean up refs
    git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d
fi

echo
echo -e "${GREEN}Email/name replacement completed!${NC}"
echo
echo "Next steps:"
echo "1. Verify the changes: git log --oneline --pretty=format:'%h %an <%ae> %s'"
echo "2. If you've already pushed to remote, force push: git push --force-with-lease"
echo "3. Notify collaborators to re-clone or rebase their work"
echo
echo -e "${YELLOW}Note: All commit hashes have changed!${NC}"