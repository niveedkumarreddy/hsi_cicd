#!/bin/bash

#############################################################################
#                                                                           #
# listArchivedBuilds.sh : List all archived full builds with details       #
#                                                                           #
#############################################################################

HOME_DIR=$1
repoName=$2
environment=${3:-""}  # Optional: filter by environment (dev/qa/prod)
filter_date=${4:-""}  # Optional: filter by date (YYYYMMDD)
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

# Set archive directory based on environment
if [ -n "$environment" ]; then
  ARCHIVE_DIR="${HOME_DIR}/${repoName}/assets/fullbuild/archive/${environment}"
else
  ARCHIVE_DIR="${HOME_DIR}/${repoName}/assets/fullbuild/archive"
fi

echod "=========================================="
echod "Archived Full Builds"
echod "=========================================="
echod "Repository: ${repoName}"
if [ -n "$environment" ]; then
  echod "Environment: ${environment}"
fi
echod "Archive Directory: ${ARCHIVE_DIR}"
if [ -n "$filter_date" ]; then
  echod "Filter Date: ${filter_date}"
fi
echod "=========================================="

# Check if archive directory exists
if [ ! -d "$ARCHIVE_DIR" ]; then
  echod "ℹ️  Archive directory does not exist: ${ARCHIVE_DIR}"
  echod "No archived builds available."
  exit 0
fi

# If no specific environment, list all environments
if [ -z "$environment" ]; then
  echod ""
  echod "Available Environments:"
  if [ -d "$ARCHIVE_DIR" ]; then
    for env_dir in "$ARCHIVE_DIR"/*/ ; do
      if [ -d "$env_dir" ]; then
        env_name=$(basename "$env_dir")
        file_count=$(find "$env_dir" -maxdepth 1 -type f -name "*.zip" 2>/dev/null | wc -l)
        echod "  - ${env_name} (${file_count} builds)"
      fi
    done
  fi
  echod ""
  echod "💡 Tip: Specify environment to see detailed builds"
  echod "Usage: $0 <HOME_DIR> <repoName> <environment> [filter_date]"
  exit 0
fi

cd "$ARCHIVE_DIR" || exit 1

# Find archived files
if [ -n "$filter_date" ]; then
  ARCHIVED_FILES=$(find . -maxdepth 1 -type f -name "*_${environment}_${filter_date}*.zip" | sort -r)
else
  ARCHIVED_FILES=$(find . -maxdepth 1 -type f -name "*_${environment}_*.zip" | sort -r)
fi

if [ -z "$ARCHIVED_FILES" ]; then
  if [ -n "$filter_date" ]; then
    echod "ℹ️  No archived builds found for environment: ${environment}, date: ${filter_date}"
  else
    echod "ℹ️  No archived builds available for environment: ${environment}"
  fi
  echod ""
  echod "All files in this directory:"
  ls -lh *.zip 2>/dev/null | awk '{print "  - " $9}'
  exit 0
fi

# Count files
FILE_COUNT=$(echo "$ARCHIVED_FILES" | wc -l)
TOTAL_SIZE=0

echod ""
echod "📦 Found ${FILE_COUNT} archived build(s)"
echod ""
echod "Available Builds:"
echod "=========================================="

# Display files with details
echo "$ARCHIVED_FILES" | while IFS= read -r file; do
  if [ -f "$file" ]; then
    BASENAME=$(basename "$file")
    FILE_SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    FILE_DATE=$(stat -f%Sm -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || stat -c%y "$file" 2>/dev/null | cut -d'.' -f1)
    FILE_AGE_DAYS=$(( ( $(date +%s) - $(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo 0) ) / 86400 ))
    
    # Extract date from filename (assuming format: *_YYYYMMDD_HHMMSS.zip)
    if [[ $BASENAME =~ _([0-9]{8})_([0-9]{6})\.zip$ ]]; then
      ARCHIVE_DATE="${BASH_REMATCH[1]}"
      ARCHIVE_TIME="${BASH_REMATCH[2]}"
      FORMATTED_DATE="${ARCHIVE_DATE:0:4}-${ARCHIVE_DATE:4:2}-${ARCHIVE_DATE:6:2}"
      FORMATTED_TIME="${ARCHIVE_TIME:0:2}:${ARCHIVE_TIME:2:2}:${ARCHIVE_TIME:4:2}"
      echod "📅 Date: ${FORMATTED_DATE} ${FORMATTED_TIME}"
    fi
    
    echod "📦 File: ${BASENAME}"
    echod "   Size: $(numfmt --to=iec-i --suffix=B $FILE_SIZE 2>/dev/null || echo "${FILE_SIZE} bytes")"
    echod "   Modified: ${FILE_DATE}"
    echod "   Age: ${FILE_AGE_DAYS} days"
    echod "   Rollback Command:"
    echod "   ./rollbackFullBuild.sh <URL> <user> <pass> ${repoName} ${HOME_DIR} ${ARCHIVE_DATE} ${environment}"
    echod "----------------------------------------"
    
    TOTAL_SIZE=$((TOTAL_SIZE + FILE_SIZE))
  fi
done

echod ""
echod "=========================================="
echod "Summary:"
echod "  Total Builds: ${FILE_COUNT}"
echod "  Total Size: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE 2>/dev/null || echo "${TOTAL_SIZE} bytes")"
echod "=========================================="

exit 0

# Made with Bob
