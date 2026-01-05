#!/bin/bash

# ====================================================
# 脚本名称: 一键自动修改 Swap 脚本
# 适用系统: Ubuntu / Debian / CentOS
# ====================================================

# 设置颜色变量
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

# 必须以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 必须以 root 权限运行此脚本。${NC}"
   exit 1
fi

# 交互获取 Swap 大小
read -p "请输入您想设置的 Swap 大小 (单位 GB, 例如 2 或 4): " SWAP_SIZE

# 校验输入是否为数字
if ! [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}错误: 请输入有效的数字。${NC}"
    exit 1
fi

SWAP_FILE="/swapfile"

echo -e "${YELLOW}>>> 开始配置 Swap...${NC}"

# 1. 禁用现有的 Swap 文件
if [ -f "$SWAP_FILE" ]; then
    echo -e "${YELLOW}检测到旧的 Swap 文件，正在禁用并删除...${NC}"
    swapoff $SWAP_FILE
    rm -f $SWAP_FILE
fi

# 2. 计算并检查磁盘空间
FREE_DISK=$(df / | awk 'NR==2 {print $4}')
REQUIRED_KB=$((SWAP_SIZE * 1024 * 1024))

if [ "$FREE_DISK" -lt "$REQUIRED_KB" ]; then
    echo -e "${RED}错误: 磁盘空间不足以创建 ${SWAP_SIZE}GB 的 Swap。${NC}"
    exit 1
fi

# 3. 创建 Swap 文件 (使用 fallocate 更快)
echo -e "${GREEN}正在创建 ${SWAP_SIZE}GB 的 Swap 文件...${NC}"
fallocate -l ${SWAP_SIZE}G $SWAP_FILE || dd if=/dev/zero of=$SWAP_FILE bs=1M count=$((SWAP_SIZE * 1024))

# 4. 设置权限
chmod 600 $SWAP_FILE

# 5. 格式化并启用
mkswap $SWAP_FILE
swapon $SWAP_FILE

# 6. 写入 /etc/fstab 以便开机自启
if ! grep -q "$SWAP_FILE" /etc/fstab; then
    echo "$SWAP_FILE swap swap defaults 0 0" >> /etc/fstab
fi

# 7. 优化 Swappiness (建议设为 10)
sysctl vm.swappiness=10
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
    echo "vm.swappiness=10" >> /etc/sysctl.conf
else
    sed -i 's/vm.swappiness=.*/vm.swappiness=10/' /etc/sysctl.conf
fi

echo -e "----------------------------------------------------"
echo -e "${GREEN}恭喜！Swap 配置完成。${NC}"
swapon --show
free -h
echo -e "----------------------------------------------------"