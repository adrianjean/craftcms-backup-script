# CraftCMS Backup Script

A customizable script to back up a CraftCMS project — including its database, core files, and environment settings.

## Features

- Full database backup using `mysqldump`
- Critical directory backups (config, modules, templates, web assets)
- `.env` and `composer.json` file backups
- Automated `.tar.gz` archive creation
- Backup integrity check after compression
- Backup and log retention management (default: 14 days)
- Interactive or silent operation
- Detailed logging to a separate `/backups/logs/` folder

## Installation
Save this script to a useful location, like your home folder and make it executable:

```
```

## Usage
This script automates the creation of a backup of your CraftCMS project. 

**Important**:
- You still need to save a copy of your backups to another location for a more resillient backup strategy.
- ALWAYS periodically TEST your backups to make sure they satisfy your resiliency needs.

### Use:
```bash
./backup-craftcms.sh <path_to_craftcms_project> [-s|--silent] [--no-log]
```

### Arguments:
- `<path_to_craftcms_project>` — Absolute or relative path to the CraftCMS project
- `-s`, `--silent` — (optional) Skip prompts and run automatically
- `--no-log` — (optional) Disable saving a log file
- `-h`, `--help` — Show help message and exit

### Example:
```bash
./backup-craftcms.sh /srv/www/craftcms
```
or
```bash
./backup-craftcms.sh . --silent
```

## Configuration

### Backup Retention
- Backup archives (`*.tar.gz`) and logs (`*.log`) are automatically deleted after **14 days**.
- You can adjust this by editing the `RETENTION_DAYS` variable at the top of the script:

```
RETENTION_DAYS=14
```

### Additional Backup Directories
You can specify which directores (relative to the project root) are backed up by adding or removing directories from the following array:

```
BACKUP_DIRECTORIES=(
  "config"
  "modules"
  "templates"
  "web/css"
  "web/js"
  "translations"
)
```
For example if you wanted to backup your `assets` directory as well, you may want to change this array to include your assets path:

```
BACKUP_DIRECTORIES=(
  "config"
  "modules"
  "templates"
  "web/css"
  "web/js"
  "translations"
  "web/assets"
)
```

## What Gets Backed Up
By default the following is backed up by this script:

- **Database** → SQL dump
- **Directories**:
  - `config/`
  - `modules/`
  - `templates/`
  - `web/css/`
  - `web/js/`
  - `translations/`
- **Files**:
  - `.env` (renamed to `env-backup.txt`)
  - `composer.json`
- **Backup archive**:  
  - Saved to `/backups/backup-<project>-<timestamp>.tar.gz`
- **Log file** (optional):  
  - Saved to `/backups/logs/backup-<timestamp>.log`


## Requirements

- Installed tools:
  - `jq`, `curl`, `tar`, `mysqldump` (typically included with MySQL client)
- A `.env` file in the project root with these variables:
  - `CRAFT_DB_DATABASE`
  - `CRAFT_DB_SERVER`
  - `CRAFT_DB_PORT`
  - `CRAFT_DB_USER`
  - `CRAFT_DB_PASSWORD`

## Important Notes

- Ensure your server user has permission to read/write inside the project directory.
- Test the backup manually before scheduling it via cron or automation.
- This script assumes a trusted server environment. For maximum database credential security, consider using a `.my.cnf` file to avoid password exposure via command-line arguments.

## Use as a Cron job
You can automate your backups by adding this line as a cron job on your server. This will run the script daily at 2:00 AM and saves a log of any issues in the `backup` directory of the project:

```
0 2 * * * /home/username/backup-craftcms.sh /srv/www/craftcms --silent >> /srv/www/craftcms/backups/logs/cron-backup.log 2>&1
```

Where "username" could be your home directory



## Contributions

Contributions and improvements are welcome!  
Feel free to fork, submit pull requests, or open issues for feature suggestions.



## License

This script is released under the [Creative Commons Attribution](https://creativecommons.org/licenses/by/4.0/) license.  
It is free to use, modify, and distribute **with attribution**, provided **as-is** and **without warranty of any kind**. TEST ALL BACKUPS TO ENSURE THEY PROVIDE THE REDUNDANCY YOU DESIRE.

---

_Last updated: 2025-04-27_
