# Rollback Scripts and Pipeline

This folder contains all scripts and pipelines related to rollback operations for full build imports.

## 📁 Contents

### 1. **rollback_pipeline.yml**
Azure DevOps pipeline for executing rollback operations.

**Features:**
- Manual trigger only (safety measure)
- Lists available archived builds
- Requires explicit confirmation
- Supports multiple environments (dev/qa/prod)
- Post-rollback validation

**Usage:**
```yaml
# Pipeline Parameters
rollbackDate: "20251215" or "20251215_143022"
targetEnvironment: "dev" | "qa" | "prod"
repoName: "your-project-name"
confirmRollback: "YES"  # Must type YES to proceed
listAvailableBuilds: true | false
```

### 2. **rollbackFullBuild.sh**
Main rollback script that restores a project to a previous state.

**Usage:**
```bash
./rollbackFullBuild.sh <URL> <admin_user> <admin_password> <repoName> <HOME_DIR> <rollback_date> <environment> [debug]

# Example
./rollbackFullBuild.sh https://api.example.com admin pass123 myProject /home/dir 20251215 dev debug
```

**Parameters:**
- `URL`: Target environment URL
- `admin_user`: Admin username
- `admin_password`: Admin password
- `repoName`: Repository/Project name
- `HOME_DIR`: Home directory path
- `rollback_date`: Date to rollback to (YYYYMMDD or YYYYMMDD_HHMMSS)
- `environment`: Environment name (dev/qa/prod)
- `debug`: Optional debug flag

**Process:**
1. Searches environment-specific archive for builds matching the specified date
2. Selects the most recent build if multiple matches found
3. Copies selected build to staging area
4. Imports the build as a full project
5. Validates import success
6. Cleans up staging area

**Archive Structure:**
Archives are organized by environment:
```
archive/
├── dev/
│   ├── project_fullbuild_dev_20251215_143022.zip
│   └── project_fullbuild_dev_20251214_091533.zip
├── qa/
│   ├── project_fullbuild_qa_20251215_120000.zip
│   └── project_fullbuild_qa_20251213_150000.zip
└── prod/
    ├── project_fullbuild_prod_20251215_100000.zip
    └── project_fullbuild_prod_20251210_140000.zip
```

### 3. **listArchivedBuilds.sh**
Lists all available archived builds with detailed information.

**Usage:**
```bash
# List all environments
./listArchivedBuilds.sh <HOME_DIR> <repoName>

# List builds for specific environment
./listArchivedBuilds.sh <HOME_DIR> <repoName> dev

# List builds for specific environment and date
./listArchivedBuilds.sh <HOME_DIR> <repoName> dev 20251215

# With debug mode
./listArchivedBuilds.sh <HOME_DIR> <repoName> dev 20251215 debug
```

**Output:**
- Environment-specific builds
- File name with timestamp and environment
- File size
- Modification date
- Age in days
- Rollback command for each build

### 4. **cleanupArchivedBuilds.sh**
Housekeeping script to clean up old archived builds.

**Usage:**
```bash
# Clean all environments with default 30-day retention
./cleanupArchivedBuilds.sh <HOME_DIR> <repoName>

# Clean specific environment with default retention
./cleanupArchivedBuilds.sh <HOME_DIR> <repoName> dev

# Clean specific environment with custom retention (e.g., 60 days)
./cleanupArchivedBuilds.sh <HOME_DIR> <repoName> dev 60

# Clean all environments with custom retention
./cleanupArchivedBuilds.sh <HOME_DIR> <repoName> "" 60

# With debug mode
./cleanupArchivedBuilds.sh <HOME_DIR> <repoName> dev 30 debug
```

**Features:**
- Deletes archives older than specified retention period (default: 30 days)
- Supports environment-specific or all-environment cleanup
- Provides detailed cleanup summary per environment
- Shows space freed
- Safe operation with validation

**Scheduling:**
Add to cron for automated cleanup:
```bash
# Clean all environments daily at 2 AM
0 2 * * * /path/to/cleanupArchivedBuilds.sh /home/dir repoName "" 30

# Clean dev environment daily at 2 AM
0 2 * * * /path/to/cleanupArchivedBuilds.sh /home/dir repoName dev 30

# Clean prod environment weekly with 90-day retention
0 2 * * 0 /path/to/cleanupArchivedBuilds.sh /home/dir repoName prod 90
```

## 🔄 Complete Workflow

### 1. Export Full Build
```bash
./exportAssetsWithFullBuild.sh ... fullBuild=true
```
Creates: `./assets/fullbuild/${repoName}_fullbuild.zip`

### 2. Import Full Build (with environment)
```bash
./importAssetsWithFullBuild.sh ... fullBuild=true environment=dev
```
Archives as: `./assets/fullbuild/archive/dev/${repoName}_fullbuild_dev_YYYYMMDD_HHMMSS.zip`

### 3. List Available Rollback Points
```bash
# List all environments
./listArchivedBuilds.sh /home/dir myProject

# List specific environment
./listArchivedBuilds.sh /home/dir myProject dev
```

### 4. Execute Rollback
```bash
./rollbackFullBuild.sh https://api.example.com admin pass myProject /home/dir 20251215 dev
```

### 5. Cleanup Old Archives
```bash
# Clean all environments
./cleanupArchivedBuilds.sh /home/dir myProject "" 30

# Clean specific environment
./cleanupArchivedBuilds.sh /home/dir myProject dev 30
```

## 📂 Directory Structure

```
assets/
└── fullbuild/
    ├── archive/                          # Archived successful imports by environment
    │   ├── dev/
    │   │   ├── project_fullbuild_dev_20251215_143022.zip
    │   │   └── project_fullbuild_dev_20251214_091533.zip
    │   ├── qa/
    │   │   ├── project_fullbuild_qa_20251215_120000.zip
    │   │   └── project_fullbuild_qa_20251213_150000.zip
    │   └── prod/
    │       ├── project_fullbuild_prod_20251215_100000.zip
    │       └── project_fullbuild_prod_20251210_140000.zip
    └── rollback_staging/                 # Temporary staging for rollback
        ├── dev/
        ├── qa/
        └── prod/
```

## ⚠️ Important Notes

1. **Safety First**: Rollback operations require explicit confirmation
2. **Archive Retention**: Default 30 days, configurable
3. **Staging Cleanup**: Automatically cleaned after rollback
4. **Validation**: Always validate application after rollback
5. **Notifications**: Notify stakeholders after rollback operations

## 🔐 Security Considerations

- Credentials should be stored in Azure Key Vault
- Use service principals for authentication
- Limit access to rollback pipeline
- Audit all rollback operations
- Maintain rollback logs

## 📊 Monitoring

Monitor the following:
- Archive directory size
- Number of archived builds
- Rollback success rate
- Time taken for rollback operations
- Post-rollback validation results

## 🆘 Troubleshooting

### Issue: No archived builds found
**Solution:** Check if imports were successful and archives were created

### Issue: Rollback fails with authentication error
**Solution:** Verify credentials in Azure Key Vault

### Issue: Archive directory full
**Solution:** Run cleanup script or adjust retention period

### Issue: Rollback succeeds but application not working
**Solution:** Check application logs, verify all dependencies, consider rolling back to earlier version

## 📝 Best Practices

1. **Test Rollback**: Test rollback process in non-production first
2. **Document Changes**: Document what changed between versions
3. **Backup Before Rollback**: Ensure current state is backed up
4. **Validate After Rollback**: Thoroughly test after rollback
5. **Communication**: Inform team before and after rollback
6. **Regular Cleanup**: Schedule regular archive cleanup
7. **Monitor Space**: Keep eye on archive directory size

## 🔗 Related Scripts

- [`../exportAssetsWithFullBuild.sh`](../exportAssetsWithFullBuild.sh) - Export with full build option
- [`../importAssetsWithFullBuild.sh`](../importAssetsWithFullBuild.sh) - Import with full build option and archiving

## 📞 Support

For issues or questions:
1. Check this README
2. Review script comments
3. Check pipeline logs
4. Contact DevOps team