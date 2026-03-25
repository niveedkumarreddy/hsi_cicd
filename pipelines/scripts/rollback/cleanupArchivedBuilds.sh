#!/bin/bash

#############################################################################
#                                                                           #
# cleanupArchivedBuilds.sh : Housekeeping job to clean up old archived     #
#                            full build ZIP files (older than 30 days)     #
#                                                                           #
#############################################################################

HOME_DIR=$1
repoName=$2
environment=${3:-""}     # Optional: specific environment (dev/qa/prod), empty for all
retention_days=${4:-30}  # Default to 30 days if not specified
debug=${5:-""}

# Validate required inputs
[ -z "$HOME_DIR" ] && echo "Missing template parameter HOME_DIR" >&2 && exit 1
[ -z "$repoName" ] && echo "Missing template parameter repoName" >&2 && exit 1

# Debug mode
if [ "$debug" == "debug" ]; then
  echo "......Running in Debug mode ......" >&2
  set -x
fi

function echod() {
  echo "$@" >&2
}

BASE_ARCHIVE_DIR="${HOME_DIR}/${repoName}/assets/fullbuild/archive"

echod "=========================================="
echod "Full Build Archive Cleanup Job"
echod "=========================================="
echod "Repository: ${repoName}"
if [ -n "$environment" ]; then
  echod "Environment: ${environment} (specific)"
  ARCHIVE_DIR="${BASE_ARCHIVE_DIR}/${environment}"
else
  echod "Environment: ALL"
  ARCHIVE_DIR="${BASE_ARCHIVE_DIR}"
fi
echod "Archive Directory: ${ARCHIVE_DIR}"
echod "Retention Period: ${retention_days} days"
echod "Current Date: $(date)"
echod "=========================================="

# Check if archive directory exists
if [ ! -d "$ARCHIVE_DIR" ]; then
  echod "ℹ️  Archive directory does not exist: ${ARCHIVE_DIR}"
  echod "Nothing to clean up."
  exit 0
fi

cd "$ARCHIVE_DIR" || exit 1

# Function to cleanup files in a directory
cleanup_directory() {
  local dir=$1
  local env_name=$2
  
  cd "$dir" || return 1
  
  echod ""
  echod "Processing environment: ${env_name}"
  echod "----------------------------------------"
  
  # Count total files before cleanup
  TOTAL_FILES=$(find . -maxdepth 1 -type f -name "*.zip" 2>/dev/null | wc -l)
  echod "📊 Total archived files found: ${TOTAL_FILES}"
  
  if [ "$TOTAL_FILES" -eq 0 ]; then
    echod "ℹ️  No archived files to process."
    return 0
  fi
  
  # Find files older than retention_days
  OLD_FILES=$(find . -maxdepth 1 -type f -name "*.zip" -mtime +${retention_days} 2>/dev/null)
  
  if [ -z "$OLD_FILES" ]; then
    echod "✅ No files older than ${retention_days} days found."
    echod "All archived files are within retention period."
    return 0
  fi
  
  echod ""
  echod "🗑️  Files to be deleted:"
  
  DELETED_COUNT=0
  DELETED_SIZE=0
  
  while IFS= read -r file; do
    if [ -f "$file" ]; then
      # Get file size in bytes
      FILE_SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
      FILE_AGE=$(find "$file" -mtime +${retention_days} -printf "%Td days\n" 2>/dev/null || echo "N/A")
      
      echod "  - $(basename "$file") (Size: $(numfmt --to=iec-i --suffix=B $FILE_SIZE 2>/dev/null || echo "${FILE_SIZE} bytes"), Age: ${FILE_AGE})"
      
      # Delete the file
      rm -f "$file"
      
      if [ $? -eq 0 ]; then
        DELETED_COUNT=$((DELETED_COUNT + 1))
        DELETED_SIZE=$((DELETED_SIZE + FILE_SIZE))
      else
        echod "    ⚠️  Failed to delete: $file"
      fi
    fi
  done <<< "$OLD_FILES"
  
  echod ""
  echod "📈 Cleanup Summary for ${env_name}:"
  echod "  - Files deleted: ${DELETED_COUNT}"
  echod "  - Space freed: $(numfmt --to=iec-i --suffix=B $DELETED_SIZE 2>/dev/null || echo "${DELETED_SIZE} bytes")"
  echod "  - Files remaining: $((TOTAL_FILES - DELETED_COUNT))"
}

# If specific environment, clean only that environment
if [ -n "$environment" ]; then
  ENV_DIR="${BASE_ARCHIVE_DIR}/${environment}"
  if [ -d "$ENV_DIR" ]; then
    cleanup_directory "$ENV_DIR" "$environment"
  else
    echod "⚠️  Environment directory not found: ${ENV_DIR}"
    exit 1
  fi
else
  # Clean all environments
  echod ""
  echod "🔍 Scanning all environments..."
  
  TOTAL_DELETED=0
  TOTAL_FREED=0
  
  for env_dir in "$BASE_ARCHIVE_DIR"/*/ ; do
    if [ -d "$env_dir" ]; then
      env_name=$(basename "$env_dir")
      cleanup_directory "$env_dir" "$env_name"
    fi
  done
fi


echod ""
echod "✅ Cleanup job completed successfully"
echod "=========================================="

exit 0

# Made with Bob
