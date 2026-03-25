#!/bin/bash

#############################################################################
#                                                                           #
# rollbackFullBuild.sh : Rollback to a previously imported full build      #
#                        from archive by date                              #
#                                                                           #
#############################################################################

LOCAL_DEV_URL=$1
X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
repoName=$3
HOME_DIR=$4
rollback_date=$5
environment=$6
debug=${8:-""}

# Validate required inputs
[ -z "$LOCAL_DEV_URL" ] && echo "Missing template parameter LOCAL_DEV_URL" >&2 && exit 1
[ -z "$X_INSTANCE_API_KEY" ] && echo "Missing template parameter X_INSTANCE_API_KEY" >&2 && exit 1 # Gen-2: Changed from admin_user and admin_password
[ -z "$repoName" ] && echo "Missing template parameter repoName" >&2 && exit 1
[ -z "$HOME_DIR" ] && echo "Missing template parameter HOME_DIR" >&2 && exit 1
[ -z "$rollback_date" ] && echo "Missing template parameter rollback_date (format: YYYYMMDD or YYYYMMDD_HHMMSS)" >&2 && exit 1
[ -z "$environment" ] && environment="default" && echo "⚠️  Environment not specified, using 'default'"

# Debug mode
if [ "$debug" == "debug" ]; then
  echo "......Running in Debug mode ......" >&2
  set -x
fi

function echod() {
  echo "$@" >&2
}

ARCHIVE_DIR="${HOME_DIR}/${repoName}/assets/fullbuild/archive/${environment}"
ROLLBACK_STAGING_DIR="${HOME_DIR}/${repoName}/assets/fullbuild/rollback_staging/${environment}"

echod "=========================================="
echod "Full Build Rollback Process"
echod "=========================================="
echod "Repository: ${repoName}"
echod "Environment: ${environment}"
echod "Archive Directory: ${ARCHIVE_DIR}"
echod "Rollback Date: ${rollback_date}"
echod "Target Environment: ${LOCAL_DEV_URL}"
echod "=========================================="

# Check if archive directory exists
if [ ! -d "$ARCHIVE_DIR" ]; then
  echo "❌ Archive directory does not exist: ${ARCHIVE_DIR}" >&2
  exit 1
fi

cd "$ARCHIVE_DIR" || exit 1

# Search for archived files matching the date pattern and environment
echod ""
echod "🔍 Searching for archived builds matching date: ${rollback_date} for environment: ${environment}"

# Find files matching the date pattern and environment
MATCHING_FILES=$(find . -maxdepth 1 -type f -name "*_${environment}_${rollback_date}*.zip" | sort -r)

if [ -z "$MATCHING_FILES" ]; then
  echo "❌ No archived builds found for date: ${rollback_date} and environment: ${environment}" >&2
  echod ""
  echod "Available archived builds for ${environment}:"
  ls -lh *_${environment}_*.zip 2>/dev/null | awk '{print "  - " $9 " (" $5 ", " $6 " " $7 ")"}'
  echod ""
  echod "All available builds in this environment:"
  ls -lh *.zip 2>/dev/null | awk '{print "  - " $9 " (" $5 ", " $6 " " $7 ")"}'
  exit 1
fi

# Count matching files
FILE_COUNT=$(echo "$MATCHING_FILES" | wc -l)

echod ""
echod "📦 Found ${FILE_COUNT} archived build(s) for date ${rollback_date} in environment ${environment}:"
echod "----------------------------------------"

# Display matching files with details
echo "$MATCHING_FILES" | while IFS= read -r file; do
  if [ -f "$file" ]; then
    FILE_SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    FILE_DATE=$(stat -f%Sm -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || stat -c%y "$file" 2>/dev/null | cut -d'.' -f1)
    echod "  $(basename "$file")"
    echod "    Size: $(numfmt --to=iec-i --suffix=B $FILE_SIZE 2>/dev/null || echo "${FILE_SIZE} bytes")"
    echod "    Modified: ${FILE_DATE}"
  fi
done

echod "----------------------------------------"

# Select the most recent file if multiple matches
SELECTED_FILE=$(echo "$MATCHING_FILES" | head -n 1)
SELECTED_BASENAME=$(basename "$SELECTED_FILE")

echod ""
echod "✅ Selected file for rollback: ${SELECTED_BASENAME}"

# Create staging directory and copy file
echod ""
echod "📋 Preparing rollback staging area..."
mkdir -p "$ROLLBACK_STAGING_DIR"

# Copy the selected file to staging
cp "$SELECTED_FILE" "$ROLLBACK_STAGING_DIR/"

if [ $? -ne 0 ]; then
  echo "❌ Failed to copy file to staging directory" >&2
  exit 1
fi

echod "✅ File copied to staging: ${ROLLBACK_STAGING_DIR}/${SELECTED_BASENAME}"

# Import the archived build
echod ""
echod "🚀 Starting rollback import process..."
echod "=========================================="

cd "$ROLLBACK_STAGING_DIR" || exit 1

IMPORT_URL=${LOCAL_DEV_URL}/apis/v1/rest/project-import
FILE="./${SELECTED_BASENAME}"

if [ ! -f "$FILE" ]; then
  echo "❌ Staged file not found: ${FILE}" >&2
  exit 1
fi

# Import the full project
formKey="project=@${FILE}"
overwriteKey="overwrite=true"

echod "Importing from: ${FILE}"
echod "Import URL: ${IMPORT_URL}"

importedName=$(curl --location --request POST ${IMPORT_URL} \
  --header 'Content-Type: multipart/form-data' \
  --header 'Accept: application/json' \
  --form ${formKey} \
  --form ${overwriteKey} \
  --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

# Check import result
status=$(echo "$importedName" | jq -r '.output.status // empty')
error_status=$(echo "$importedName" | jq -r '.error.status // empty')

echod ""
echod "=========================================="

if [ "$status" == "IMPORT_SUCCESS" ]; then
  echod "✅ Rollback import succeeded!"
  echod "Response: ${importedName}"
  
  # Clean up staging directory
  echod ""
  echod "🧹 Cleaning up staging area..."
  rm -f "$FILE"
  echod "✅ Staging cleanup completed"
  
  echod ""
  echod "=========================================="
  echod "✅ ROLLBACK COMPLETED SUCCESSFULLY"
  echod "=========================================="
  echod "Rolled back to: ${SELECTED_BASENAME}"
  echod "Environment: ${environment}"
  echod "Date: ${rollback_date}"
  echod "Repository: ${repoName}"
  echod "=========================================="
  
elif [ -n "$status" ] && [ "$status" != "null" ] && [ "$status" != "empty" ]; then
  # Partial success or other status
  echod "⚠️  Rollback import completed with status: ${status}"
  
  # Check for messaging issues
  messaging_issues=$(echo "$importedName" | jq -r '.output.messaging_issues // empty')
  if [ -n "$messaging_issues" ] && [ "$messaging_issues" != "null" ]; then
    issues=$(echo "$importedName" | jq -r '.output.messaging_issues.issues[]? // empty' | tr '\n' ', ')
    description=$(echo "$importedName" | jq -r '.output.messaging_issues.description // empty')
    echod "Issues: ${issues}"
    echod "Description: ${description}"
  fi
  
  echod "Full response: ${importedName}"
  echod ""
  echod "⚠️  ROLLBACK COMPLETED WITH WARNINGS"
  
elif [ -n "$error_status" ]; then
  # Error response
  error_message=$(echo "$importedName" | jq -r '.error.message // empty')
  error_code=$(echo "$importedName" | jq -r '.error.errorSource.errorCode // empty')
  request_id=$(echo "$importedName" | jq -r '.error.errorSource.requestID // empty')
  
  echo "❌ Rollback import failed with status: ${error_status}" >&2
  echo "Error message: ${error_message}" >&2
  echo "Error code: ${error_code}" >&2
  echo "Request ID: ${request_id}" >&2
  echo "Full response: ${importedName}" >&2
  
  # Clean up staging directory
  rm -f "$FILE"
  
  exit 1
else
  echo "❌ Rollback import failed - unexpected response format" >&2
  echo "Response: ${importedName}" >&2
  
  # Clean up staging directory
  rm -f "$FILE"
  
  exit 1
fi

cd "${HOME_DIR}/${repoName}" || exit 1

exit 0


