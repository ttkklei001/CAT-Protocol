#!/bin/bash

# 定义颜色代码以格式化输出
Crontab_file="/usr/bin/crontab"

# 检查脚本是否以root用户身份运行
check_root() {
    [[ $EUID != 0 ]] && echo "当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 'sudo su' 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}

# 检查并安装必要的命令
check_and_install() {
    local cmd=$1
    local pkg=$2
    if ! command -v "$cmd" &> /dev/null; then
        echo "未检测到 ${cmd}，正在安装..."
        apt install "$pkg" -y
    fi
}

# 安装环境和设置完整节点
install_env_and_full_node() {
    check_root

    # 更新系统并安装依赖
    apt update && apt upgrade -y
    check_and_install "curl" "curl"
    check_and_install "tar" "tar"
    check_and_install "wget" "wget"
    check_and_install "clang" "clang"
    check_and_install "pkg-config" "pkg-config"
    check_and_install "libssl-dev" "libssl-dev"
    check_and_install "jq" "jq"
    check_and_install "build-essential" "build-essential"
    check_and_install "git" "git"
    check_and_install "make" "make"
    check_and_install "ncdu" "ncdu"
    check_and_install "unzip" "unzip"
    check_and_install "zip" "zip"
    check_and_install "docker.io" "docker.io"
    check_and_install "npm" "npm"

    # 安装 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
        DESTINATION=/usr/local/bin/docker-compose
        curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
        chmod 755 $DESTINATION
    fi

    # 安装 Node.js 和 Yarn
    npm install n -g
    n stable
    npm i -g yarn

    # 克隆代码库并构建项目
    git clone https://github.com/CATProtocol/cat-token-box
    cd cat-token-box
    yarn install
    yarn build

    # 设置权限并启动 Docker 容器
    cd ./packages/tracker/
    chmod 777 docker/data
    chmod 777 docker/pgdata
    docker-compose up -d

    cd ../../
    docker build -t tracker:latest .
    docker run -d \
        --name tracker \
        --add-host="host.docker.internal:host-gateway" \
        -e DATABASE_HOST="host.docker.internal" \
        -e RPC_HOST="host.docker.internal" \
        -p 3000:3000 \
        tracker:latest

    # 创建配置文件
    echo '{
      "network": "fractal-mainnet",
      "tracker": "http://127.0.0.1:3000",
      "dataDir": ".",
      "maxFeeRate": 30,
      "rpc": {
          "url": "http://127.0.0.1:8332",
          "username": "bitcoin",
          "password": "opcatAwesome"
      }
    }' > ~/cat-token-box/packages/cli/config.json

    # 创建铸造脚本
    echo '#!/bin/bash
    command="yarn cli mint -i 45ee725c2c5993b3e4d308842d87e973bf1951f5f7a804b21e4dd964ecd12d6b_0 5"

    while true; do
        $command

        if [ $? -ne 0 ]; then
            echo "命令执行失败，退出循环"
            exit 1
        fi

        sleep 1
    done' > ~/cat-token-box/packages/cli/mint_script.sh
    chmod +x ~/cat-token-box/packages/cli/mint_script.sh
}

# 创建钱包
create_wallet() {
    echo -e "\n"
    cd ~/cat-token-box/packages/cli
    yarn cli wallet create
    echo -e "\n"
    yarn cli wallet address
    echo -e "请保存上面创建好的钱包地址、助记词"
}

# 开始铸造
start_mint_cat() {
    cd ~/cat-token-box/packages/cli
    bash ~/cat-token-box/packages/cli/mint_script.sh
}

# 查看全节点日志
check_node_log() {
    docker logs -f --tail 100 tracker
}

# 查看钱包余额
check_wallet_balance() {
    cd ~/cat-token-box/packages/cli
    yarn cli wallet balances
}

# 显示菜单选项
echo -e "\nCAT Protocol 管理工具"
echo -e "==============================="
echo -e "1. 初始化环境和节点配置"
echo -e "2. 生成新的钱包地址"
echo -e "3. 启动铸造操作"
echo -e "4. 实时查看节点日志"
echo -e "5. 查询钱包余额"
echo -e "==============================="

# 读取用户输入并执行相应操作
read -e -p "请输入选项编号并按回车: " num
case "$num" in
1)
    install_env_and_full_node
    ;;
2)
    create_wallet
    ;;
3)
    start_mint_cat
    ;;
4)
    check_node_log
    ;;
5)
    check_wallet_balance
    ;;
*)
    echo -e "请输入有效的选项编号"
    ;;
esac
