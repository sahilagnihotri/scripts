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
echo "This script will change the email address and/or name for all previous commits."
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

echo -e "${YELLOW}=== REPOSITORY STATUS CHECK ===${NC}"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}Warning: You have uncommitted changes in your working directory!${NC}"
    echo "Uncommitted files:"
    git status --porcelain
    echo
    echo "It's recommended to commit or stash these changes before rewriting history."
    echo -e "${BLUE}Do you want to continue anyway? (y/N)${NC}"
    read -r CONTINUE_WITH_CHANGES
    if [[ ! "$CONTINUE_WITH_CHANGES" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled. Please commit or stash your changes first."
        exit 0
    fi
    echo
fi

# Check if repository has commits
if ! git rev-parse HEAD > /dev/null 2>&1; then
    echo -e "${YELLOW}No commits found in this repository.${NC}"
    echo "Nothing to rewrite. Exiting."
    exit 0
fi

# Check remote status
REMOTES=$(git remote)
if [ -n "$REMOTES" ]; then
    echo "Checking remote status..."
    
    # Check if we have unpushed commits (if remote exists)
    if git remote get-url origin > /dev/null 2>&1; then
        REMOTE_NAME="origin"
    else
        REMOTE_NAME=$(echo "$REMOTES" | head -1)
    fi
    
    # Try to fetch to get latest remote state (suppress errors if no network)
    if git fetch "$REMOTE_NAME" > /dev/null 2>&1; then
        # Check if local is ahead of remote
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        if git rev-list --count "$REMOTE_NAME/$CURRENT_BRANCH..$CURRENT_BRANCH" > /dev/null 2>&1; then
            AHEAD_COUNT=$(git rev-list --count "$REMOTE_NAME/$CURRENT_BRANCH..$CURRENT_BRANCH")
            if [ "$AHEAD_COUNT" -gt 0 ]; then
                echo -e "${YELLOW}Your local branch is $AHEAD_COUNT commits ahead of remote.${NC}"
                echo "These unpushed commits will have their metadata changed."
            fi
        fi
    else
        echo -e "${YELLOW}Could not fetch from remote (network issue or no tracking branch).${NC}"
    fi
else
    echo -e "${YELLOW}No remotes configured.${NC}"
fi

# Check for tags
TAGS=$(git tag -l)
if [ -n "$TAGS" ]; then
    TAG_COUNT=$(echo "$TAGS" | wc -l | tr -d ' ')
    echo -e "${YELLOW}Found $TAG_COUNT tags in repository:${NC}"
    git tag -l --format="  %(refname:short) -> %(objectname:short)"
    echo
    echo -e "${RED}WARNING: Tags will be recreated to point to new commit SHAs after rewrite!${NC}"
    echo "Tag names will remain the same, but they'll point to the new commits."
    echo
else
    echo "No tags found in repository."
fi

echo

# Determine what to change if not provided via environment variables
if [ -z "$OLD_EMAIL" ] && [ -z "$NEW_EMAIL" ] && [ -z "$OLD_NAME" ] && [ -z "$NEW_NAME" ]; then
    echo "What would you like to change?"
    echo "1) Email address only"
    echo "2) Name only"
    echo "3) Both email and name"
    echo "Enter your choice (1/2/3):"
    read -r CHANGE_CHOICE
    
    case "$CHANGE_CHOICE" in
        1)
            echo "Enter the OLD email address to replace:"
            read -r OLD_EMAIL
            echo "Enter the NEW email address:"
            read -r NEW_EMAIL
            ;;
        2)
            echo "Enter the OLD name to replace:"
            read -r OLD_NAME
            echo "Enter the NEW name:"
            read -r NEW_NAME
            ;;
        3)
            echo "Enter the OLD email address to replace:"
            read -r OLD_EMAIL
            echo "Enter the NEW email address:"
            read -r NEW_EMAIL
            echo "Enter the OLD name to replace:"
            read -r OLD_NAME
            echo "Enter the NEW name:"
            read -r NEW_NAME
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
else
    # Legacy behavior: get email if not provided
    if [ -z "$OLD_EMAIL" ] && [ -z "$OLD_NAME" ]; then
        echo "Enter the OLD email address to replace:"
        read -r OLD_EMAIL
    fi
    
    if [ -z "$NEW_EMAIL" ] && [ -n "$OLD_EMAIL" ]; then
        echo "Enter the NEW email address:"
        read -r NEW_EMAIL
    fi
    
    # Get current name if not provided (optional)
    if [ -z "$OLD_NAME" ] && [ -z "$NEW_NAME" ] && [ -n "$OLD_EMAIL" ]; then
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
fi

# Validate email addresses (if provided)
if [ -n "$OLD_EMAIL" ] && [[ ! "$OLD_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo -e "${RED}Error: Invalid old email format${NC}"
    exit 1
fi

if [ -n "$NEW_EMAIL" ] && [[ ! "$NEW_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo -e "${RED}Error: Invalid new email format${NC}"
    exit 1
fi

# Validate that we have something to change
if [ -z "$OLD_EMAIL" ] && [ -z "$OLD_NAME" ]; then
    echo -e "${RED}Error: Must specify either OLD_EMAIL or OLD_NAME to change${NC}"
    exit 1
fi

# Validate email pairing
if [ -n "$OLD_EMAIL" ] && [ -z "$NEW_EMAIL" ]; then
    echo -e "${RED}Error: NEW_EMAIL must be provided when OLD_EMAIL is specified${NC}"
    exit 1
fi

if [ -z "$OLD_EMAIL" ] && [ -n "$NEW_EMAIL" ]; then
    echo -e "${RED}Error: OLD_EMAIL must be provided when NEW_EMAIL is specified${NC}"
    exit 1
fi

# Validate name pairing
if [ -n "$OLD_NAME" ] && [ -z "$NEW_NAME" ]; then
    echo -e "${RED}Error: NEW_NAME must be provided when OLD_NAME is specified${NC}"
    exit 1
fi

if [ -z "$OLD_NAME" ] && [ -n "$NEW_NAME" ]; then
    echo -e "${RED}Error: OLD_NAME must be provided when NEW_NAME is specified${NC}"
    exit 1
fi

echo
if [ -n "$OLD_EMAIL" ] && [ -n "$NEW_EMAIL" ]; then
    echo "OLD EMAIL: $OLD_EMAIL"
    echo "NEW EMAIL: $NEW_EMAIL"
fi
if [ -n "$OLD_NAME" ] && [ -n "$NEW_NAME" ]; then
    echo "OLD NAME:  $OLD_NAME"
    echo "NEW NAME:  $NEW_NAME"
fi
echo

# Check if there are any commits with the old email (if email is being changed)
if [ -n "$OLD_EMAIL" ]; then
    COMMIT_COUNT=$(git log --all --pretty=format:"%ae" | grep -c "^$OLD_EMAIL$" || true)
    if [ "$COMMIT_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}No commits found with email: $OLD_EMAIL${NC}"
        # Don't exit yet, check if we're also changing names
    else
        echo "Found $COMMIT_COUNT commits with the old email address."
    fi
else
    COMMIT_COUNT=0
fi

# Check if there are any commits with the old name (if specified)
if [ -n "$OLD_NAME" ]; then
    NAME_COMMIT_COUNT=$(git log --all --pretty=format:"%an" | grep -c "^$OLD_NAME$" || true)
    if [ "$NAME_COMMIT_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}No commits found with name: $OLD_NAME${NC}"
    else
        echo "Found $NAME_COMMIT_COUNT commits with the old name."
    fi
else
    NAME_COMMIT_COUNT=0
fi

# Exit if no commits found for either email or name
if [ "$COMMIT_COUNT" -eq 0 ] && [ "$NAME_COMMIT_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No commits found to modify. Exiting.${NC}"
    exit 0
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

# Save tag information before rewrite
echo "Saving tag information..."
TEMP_TAG_FILE=$(mktemp)
git tag -l --format="%(refname:short) %(objectname)" > "$TEMP_TAG_FILE" 2>/dev/null || true

# Save remote configuration before rewrite
echo "Saving remote configuration..."
TEMP_REMOTE_FILE=$(mktemp)
git remote -v > "$TEMP_REMOTE_FILE" 2>/dev/null || true
SAVED_REMOTES_COUNT=$(wc -l < "$TEMP_REMOTE_FILE" | tr -d ' ')

# Save current branch and upstream info
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
UPSTREAM_BRANCH=""
if git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
    UPSTREAM_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})
fi

# Check if git filter-repo is available
if command -v git-filter-repo > /dev/null 2>&1; then
    echo "Using git filter-repo (recommended method)..."
    
    # Build the filter-repo command based on what we're changing
    FILTER_REPO_ARGS="--force"
    
    if [ -n "$OLD_EMAIL" ] && [ -n "$NEW_EMAIL" ]; then
        EMAIL_CALLBACK="return email.replace(b'$OLD_EMAIL', b'$NEW_EMAIL')"
        FILTER_REPO_ARGS="$FILTER_REPO_ARGS --email-callback '$EMAIL_CALLBACK'"
    fi
    
    if [ -n "$OLD_NAME" ] && [ -n "$NEW_NAME" ]; then
        NAME_CALLBACK="return name.replace(b'$OLD_NAME', b'$NEW_NAME')"
        FILTER_REPO_ARGS="$FILTER_REPO_ARGS --name-callback '$NAME_CALLBACK'"
    fi
    
    eval "git filter-repo $FILTER_REPO_ARGS"
    
    echo "git filter-repo automatically updated tags to point to new commits."
else
    echo "Using git filter-branch (git filter-repo not found)..."
    
    ENV_FILTER=""
    
    if [ -n "$OLD_EMAIL" ] && [ -n "$NEW_EMAIL" ]; then
        ENV_FILTER="$ENV_FILTER
if [ \"\$GIT_COMMITTER_EMAIL\" = \"$OLD_EMAIL\" ]; then
    export GIT_COMMITTER_EMAIL=\"$NEW_EMAIL\"
fi
if [ \"\$GIT_AUTHOR_EMAIL\" = \"$OLD_EMAIL\" ]; then
    export GIT_AUTHOR_EMAIL=\"$NEW_EMAIL\"
fi"
    fi
    
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
    
    echo "git filter-branch updated tags to point to new commits."
fi

# Verify tags after rewrite
echo
echo -e "${YELLOW}Verifying tags after rewrite...${NC}"
UPDATED_TAGS=$(git tag -l)
if [ -n "$UPDATED_TAGS" ]; then
    TAG_COUNT=$(echo "$UPDATED_TAGS" | wc -l | tr -d ' ')
    echo "✅ $TAG_COUNT tags successfully updated:"
    git tag -l --format="  %(refname:short) -> %(objectname:short)"
    echo
else
    echo "No tags to update."
fi

# Restore remote configuration
echo -e "${YELLOW}Restoring remote configuration...${NC}"
if [ "$SAVED_REMOTES_COUNT" -gt 0 ]; then
    echo "Restoring saved remotes..."
    while IFS=$'\t' read -r remote_name remote_url; do
        if [ -n "$remote_name" ] && [ -n "$remote_url" ]; then
            # Remove (fetch) and (push) indicators
            clean_url=$(echo "$remote_url" | sed 's/ (fetch)$//' | sed 's/ (push)$//')
            if [ "$clean_url" != "$remote_url" ]; then
                git remote add "$remote_name" "$clean_url" 2>/dev/null || git remote set-url "$remote_name" "$clean_url"
            fi
        fi
    done <<< "$(cat "$TEMP_REMOTE_FILE" | awk '{print $1 "\t" $2}' | sort -u)"
    echo "✅ Remotes restored."
else
    echo -e "${YELLOW}No remotes were configured before. Would you like to add one now? (y/N)${NC}"
    read -r ADD_REMOTE
    if [[ "$ADD_REMOTE" =~ ^[Yy]$ ]]; then
        echo "Enter remote name (default: origin):"
        read -r REMOTE_NAME
        REMOTE_NAME="${REMOTE_NAME:-origin}"
        
        echo "Enter repository URL (e.g., https://github.com/username/repo.git):"
        read -r REMOTE_URL
        
        if [ -n "$REMOTE_URL" ]; then
            git remote add "$REMOTE_NAME" "$REMOTE_URL"
            echo "✅ Added remote '$REMOTE_NAME': $REMOTE_URL"
        else
            echo "No URL provided, skipping remote setup."
        fi
    fi
fi

# Clean up temporary files
if [ -f "$TEMP_TAG_FILE" ]; then
    rm -f "$TEMP_TAG_FILE"
fi
if [ -f "$TEMP_REMOTE_FILE" ]; then
    rm -f "$TEMP_REMOTE_FILE"
fi

echo
echo -e "${GREEN}Email/name replacement completed!${NC}"
echo

# Check repository state after changes
echo -e "${YELLOW}=== POST-CHANGE REPOSITORY STATUS ===${NC}"

# All commits are now "unpushed" since we rewrote history
TOTAL_COMMITS=$(git rev-list --count HEAD)
echo -e "${RED}IMPORTANT: All $TOTAL_COMMITS commits now have different hashes and need to be force-pushed!${NC}"

# Check if we have remotes
REMOTES=$(git remote)
if [ -n "$REMOTES" ]; then
    echo -e "${YELLOW}Remotes found - changes need to be pushed to update the server.${NC}"
    if git remote get-url origin > /dev/null 2>&1; then
        REMOTE_NAME="origin"
    else
        REMOTE_NAME=$(echo "$REMOTES" | head -1)
    fi
    echo "Primary remote: $REMOTE_NAME ($(git remote get-url "$REMOTE_NAME" 2>/dev/null || echo "URL not available"))"
else
    echo -e "${YELLOW}No remotes configured - add one to push changes to a server.${NC}"
fi

echo
echo "Next steps:"
echo "1. Verify the changes: git log --oneline --pretty=format:'%h %an <%ae> %s'"
echo "2. Push changes to remote: git push --force-with-lease"
echo "3. Notify collaborators to re-clone or rebase their work"
echo
echo -e "${YELLOW}Note: All commit hashes have changed due to metadata rewriting!${NC}"
echo

# Ask if user wants to push now
echo -e "${BLUE}Do you want to push the changes to remote now? (y/N)${NC}"
read -r PUSH_NOW

if [[ "$PUSH_NOW" =~ ^[Yy]$ ]]; then
    echo
    echo -e "${YELLOW}Checking for configured remotes...${NC}"
    
    # Get all remotes
    REMOTES=$(git remote)
    
    if [ -z "$REMOTES" ]; then
        echo -e "${YELLOW}No remotes configured in this repository.${NC}"
        echo
        echo "To push changes, you need to add a remote first:"
        echo "  git remote add origin <your-repository-url>"
        echo "Then push with:"
        echo "  git push --force-with-lease origin"
        echo "  git push --force-with-lease origin --tags  # Push tags too"
    else
        echo "Available remotes:"
        git remote -v
        echo
        
        # Check if origin exists
        if git remote get-url origin > /dev/null 2>&1; then
            REMOTE_NAME="origin"
        else
            # Use the first available remote
            REMOTE_NAME=$(echo "$REMOTES" | head -1)
        fi
        
        echo "Using remote: $REMOTE_NAME"
        
        # Check if current branch has upstream
        if git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
            echo "Executing: git push --force-with-lease $REMOTE_NAME"
            PUSH_CMD="git push --force-with-lease $REMOTE_NAME"
        else
            echo "Executing: git push --set-upstream $REMOTE_NAME $CURRENT_BRANCH"
            PUSH_CMD="git push --set-upstream $REMOTE_NAME $CURRENT_BRANCH"
        fi
        
        if eval "$PUSH_CMD"; then
            echo -e "${GREEN}Successfully pushed commits to remote '$REMOTE_NAME'!${NC}"
            
            # Push tags if they exist
            TAGS_TO_PUSH=$(git tag -l)
            if [ -n "$TAGS_TO_PUSH" ]; then
                echo "Pushing updated tags..."
                if git push --force-with-lease "$REMOTE_NAME" --tags; then
                    echo -e "${GREEN}Successfully pushed tags to remote '$REMOTE_NAME'!${NC}"
                else
                    echo -e "${YELLOW}Warning: Failed to push tags. You may need to push them manually:${NC}"
                    echo "git push --force-with-lease $REMOTE_NAME --tags"
                fi
            fi
        else
            echo -e "${RED}Failed to push changes.${NC}"
            echo
            echo "You may need to:"
            echo "1. Set up authentication (SSH keys, personal access tokens)"
            echo "2. Check if the remote URL is correct: git remote -v"
            echo "3. Try pushing manually: git push --force-with-lease $REMOTE_NAME"
            echo "4. Push tags separately: git push --force-with-lease $REMOTE_NAME --tags"
        fi
    fi
else
    echo
    echo -e "${YELLOW}Remember to push your changes when ready.${NC}"
    echo
    # Show available remotes for manual push
    REMOTES=$(git remote)
    if [ -n "$REMOTES" ]; then
        echo "Available remotes:"
        git remote -v
        echo
        if git remote get-url origin > /dev/null 2>&1; then
            MANUAL_REMOTE="origin"
        else
            MANUAL_REMOTE=$(echo "$REMOTES" | head -1)
        fi
        
        # Check if current branch has upstream for manual instructions
        if git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
            echo -e "${BLUE}git push --force-with-lease $MANUAL_REMOTE${NC}"
        else
            echo -e "${BLUE}git push --set-upstream $MANUAL_REMOTE $CURRENT_BRANCH${NC}"
        fi
        
        TAGS_TO_PUSH=$(git tag -l)
        if [ -n "$TAGS_TO_PUSH" ]; then
            echo -e "${BLUE}git push --force-with-lease $MANUAL_REMOTE --tags${NC}"
        fi
    else
        echo "No remotes configured. Add one first:"
        echo -e "${BLUE}git remote add origin <your-repository-url>${NC}"
        echo -e "${BLUE}git push --set-upstream origin $CURRENT_BRANCH${NC}"
        TAGS_TO_PUSH=$(git tag -l)
        if [ -n "$TAGS_TO_PUSH" ]; then
            echo -e "${BLUE}git push origin --tags${NC}"
        fi
    fi
fi