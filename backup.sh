#!/bin/bash

# --- 1. 配置部分 ---
DIR="/Users/user/web/sql-apple"
DATE=$(date "+%Y_%m_%d_%H%M%S")

# 容器名称
MYSQL_CONTAINER="mysql847" # 请替换为你的 MySQL 容器名
PG_CONTAINER="postgres177"

# 凭据配置
MYSQL_PASS="Adwd^%*&a*@#DSFsUdfA2.4f"
PG_PASS="A@$#%dsfefw123T*(@#fe"

# 数据库任务列表 (格式: "类型:数据库名")
DB_TASKS=(
    "postgres:azah_prod_db"
    "postgres:azah_dev_db"
    "postgres:azyt_db"
)

# --- 2. 核心备份函数 ---
do_backup() {
    local TYPE=$1
    local DB=$2
    local FILE="${DATE}_${DB}_${TYPE}.sql"

    echo "正在处理 [$TYPE] 数据库: $DB ..."

    # 根据类型选择不同的 Docker 执行命令
    case "$TYPE" in
        "mysql")
            # 使用 -e 传递密码，避免命令行明文警告
            docker exec -e MYSQL_PWD="$MYSQL_PASS" "$MYSQL_CONTAINER" \
                mysqldump -u root "$DB" > "$FILE" 2>/dev/null
            ;;
        "postgres")
            docker exec -e PGPASSWORD="$PG_PASS" "$PG_CONTAINER" \
                pg_dump -U postgres "$DB" > "$FILE" 2>/dev/null
            ;;
    esac

    # 统一检查并压缩
    if [[ -s "$FILE" ]]; then
        xz -9e "$FILE"
        echo "  [OK] 备份成功: ${FILE}.xz"
    else
        echo "  [Error] 备份失败: $DB (请检查容器名或密码)"
        #rm -f "$FILE"
    fi
    rm -f "$FILE"
}

# --- 3. 执行流程 ---
mkdir -p "$DIR"
cd "$DIR" || exit

echo "======= 任务开始: $DATE ======="

for task in "${DB_TASKS[@]}"; do
    IFS=":" read -r TYPE DB_NAME <<< "$task"
    do_backup "$TYPE" "$DB_NAME"
done

# --- 4. 远程同步 ---
echo "======= 正在执行远程同步 ======="

# Git 同步 (仅在存在 .git 目录时)
if [ -d ".git" ]; then
    git add .
    git diff-index --quiet HEAD || { git commit -m "Backup: $DATE" && git push origin main; }
fi

# Rclone 同步 (R2)
/usr/local/bin/rclone -P copy "$DIR" r2:mini/sql-apple/ --exclude "/.git/**" --quiet

echo "======= 任务完成: $(date "+%Y-%m-%d %H:%M:%S") ======="
