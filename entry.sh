#!/bin/bash

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"

# 时间戳打印函数
log() {
    local color=$1
    shift
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${color}$@${RESET}"
}

# 显示使用方法
show_usage() {
    echo "使用方法:"
    echo "  备份模式: $0 --backup"
    echo "  恢复模式: $0 --restore [版本ID/latest]"
    echo
    echo "示例:"
    echo "  $0 --backup              # 执行备份"
    echo "  $0 --restore latest      # 恢复最新版本"
    echo "  $0 --restore 1a2b3c      # 恢复指定版本"
}

# 列出可用的备份版本
list_snapshots() {
    log "$BLUE" "可用的备份版本:"
    restic -r "$RESTIC_REPOSITORY" snapshots
}

# 检查必要的环境变量
if [ -z "$B2_BUCKET" ] || [ -z "$B2_PATH" ]; then
    log "$RED" "Error: B2_BUCKET and B2_PATH must be set."
    exit 1
fi

if [ -z "$RESTIC_PASSWORD" ]; then
    log "$RED" "Error: RESTIC_PASSWORD must be set."
    exit 1
fi

# 默认值
BACKUP_INTERVAL=${BACKUP_INTERVAL:-6}h
BACKUP_KEEP_LAST=${BACKUP_KEEP_LAST:-4}

# 设置固定的主机名用于备份
# 如果环境变量未设置，使用 'XSC-DOCKER-RESTIC' 作为默认值
export RESTIC_HOST=${RESTIC_HOST:-"XSC-DOCKER-RESTIC"}

# 生成 rclone 配置路径
RCLONE_CONFIG_PATH="/root/.config/rclone/rclone.conf"

# 检查 rclone 配置是否存在，如果不存在，进行配置
if [ ! -f "$RCLONE_CONFIG_PATH" ]; then
    log "$YELLOW" "rclone configuration file not found. Creating configuration..."

    # 检查环境变量并生成配置
    mkdir -p /root/.config/rclone

    echo "[backup]" > "$RCLONE_CONFIG_PATH"
    echo "type = b2" >> "$RCLONE_CONFIG_PATH"

    # B2_ACCOUNT
    if [ ! -z "$B2_ACCOUNT" ]; then
        echo "account = $B2_ACCOUNT" >> "$RCLONE_CONFIG_PATH"
    fi

    # B2_KEY
    if [ ! -z "$B2_KEY" ]; then
        echo "key = $B2_KEY" >> "$RCLONE_CONFIG_PATH"
    fi

    # B2_HARD_DELETE
    if [ ! -z "$B2_HARD_DELETE" ]; then
        echo "hard_delete = $B2_HARD_DELETE" >> "$RCLONE_CONFIG_PATH"
    fi

    # B2_DOWNLOAD_URL
    if [ ! -z "$B2_DOWNLOAD_URL" ]; then
        echo "download_url = $B2_DOWNLOAD_URL" >> "$RCLONE_CONFIG_PATH"
    fi

    log "$GREEN" "rclone configuration file created at $RCLONE_CONFIG_PATH."
fi

# 配置 Restic 仓库路径
RESTIC_REPOSITORY="rclone:backup:$B2_BUCKET/$B2_PATH"

# 检查 Restic 仓库是否已初始化
if ! restic -r "$RESTIC_REPOSITORY" snapshots > /dev/null 2>&1; then
    log "$CYAN" "Restic repository not initialized. Initializing now..."
    restic -r "$RESTIC_REPOSITORY" init
    if [ $? -ne 0 ]; then
        log "$RED" "Error: Failed to initialize Restic repository."
        exit 1
    fi
    log "$GREEN" "Restic repository initialized successfully."
fi

# 定义备份函数
backup() {
    log "$BLUE" "Starting backup..."
    # 使用固定的主机名进行备份
    restic -r "$RESTIC_REPOSITORY" backup /data
    if [ $? -ne 0 ]; then
        log "$RED" "Error: Backup failed."
        exit 1
    fi
    log "$GREEN" "Backup completed successfully."

    log "$BLUE" "Cleaning up old backups..."
    # 使用 --host 参数确保只清理特定主机名的备份
    restic -r "$RESTIC_REPOSITORY" forget --group-by paths --keep-last "$BACKUP_KEEP_LAST" --prune
    if [ $? -ne 0 ]; then
        log "$RED" "Error: Failed to prune old snapshots."
        exit 1
    fi
    log "$GREEN" "Old backups cleaned up successfully."
}

# 定义恢复函数
restore() {
    local snapshot_id=$1

    if [ -z "$snapshot_id" ]; then
        log "$RED" "错误: 需要指定恢复版本ID"
        echo
        list_snapshots
        exit 1
    fi

    log "$BLUE" "开始恢复数据 (版本: $snapshot_id)..."
    restic -r "$RESTIC_REPOSITORY" restore "$snapshot_id" --target /data
    if [ $? -ne 0 ]; then
        log "$RED" "Error: 恢复失败."
        exit 1
    fi
    log "$GREEN" "数据恢复成功."
}

# 信号处理
trap 'log "$YELLOW" "收到退出信号，正在结束..."; exit 0' SIGTERM SIGINT

# 命令行参数处理
if [ "$1" = "--backup" ]; then
    # 备份模式
    backup
    while true; do
        log "$CYAN" "等待 $BACKUP_INTERVAL 后进行下一次备份..."
        sleep "$BACKUP_INTERVAL"
        backup
    done
elif [ "$1" = "--restore" ]; then
    # 恢复模式
    if [ -z "$2" ]; then
        log "$RED" "错误: 请指定要恢复的版本ID"
        echo
        list_snapshots
        exit 1
    fi
    restore "$2"
else
    # 显示使用说明
    log "$YELLOW" "为了您的数据安全，我们没有做任何事，您需要明确备份或恢复模式。"
    echo
    show_usage
    exit 1
fi
