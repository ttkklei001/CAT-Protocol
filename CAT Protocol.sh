#!/bin/bash

Crontab_file="/usr/bin/crontab"

# 检查是否为 root 用户
check_root() {
    [[ $EUID != 0 ]] && echo "错误: 当前非 root 用户。请切换到 root 账号或使用 'sudo su' 获取临时 root 权限。" && exit 1
}

# 安装依赖环境和全节点
install_env_and_full_node() {
    check_root
    # 更新系统并升级
    sudo apt update && sudo apt upgrade -y

    # 安装必要的工具和库
    sudo apt install curl tar wget clang pkg-config libssl-dev jq build-essential git make ncdu unzip zip docker.io -y

    # 获取 Docker Compose 的最新版本
    VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
    DESTINATION=/usr/local/bin/docker-compose
    sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
    sudo chmod 755 $DESTINATION

    # 安装 Node.js 和 Yarn
    sudo apt-get install npm -y
    sudo npm install n -g
    sudo n stable
    sudo npm i -g yarn

    # 克隆 CAT Token Box 项目并进行安装和构建
    git clone https://github.com/CATProtocol/cat-token-box
    cd cat-token-box
    sudo yarn install
    sudo yarn build

    # 设置 Docker 环境并启动服务
    cd ./packages/tracker/
    sudo chmod 777 docker/data
    sudo chmod 777 docker/pgdata
    sudo docker-compose up -d

    # 构建和运行 Docker 镜像
    cd ../../
    sudo docker build -t tracker:latest .
    sudo docker run -d \
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

    # 创建 mint 脚本
    echo '#!/bin/bash

    command="sudo yarn cli mint -i 45ee725c2c5993b3e4d308842d87e973bf1951f5f7a804b21e4dd964ecd12d6b_0 5"

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
  sudo yarn cli wallet create
  echo -e "\n"
  sudo yarn cli wallet address
  echo -e "请保存上面创建好的钱包地址和助记词。"
}

# 启动 mint 脚本
start_mint_cat() {
  cd ~/cat-token-box/packages/cli
  bash ~/cat-token-box/packages/cli/mint_script.sh
}

# 查看节点同步日志
check_node_log() {
  docker logs -f --tail 100 tracker
}

# 查看钱包余额
check_wallet_balance() {
  cd ~/cat-token-box/packages/cli
  sudo yarn cli wallet balances
}

# 显示主菜单
echo -e "\n
欢迎使用 CAT Token Box 安装脚本。
此脚本完全免费且开源。
请根据需要选择操作：
1. 安装依赖环境和全节点
2. 创建钱包
3. 开始 mint CAT
4. 查看节点同步日志
5. 查看钱包余额
"

# 获取用户选择并执行相应操作
read -e -p "请输入您的选择: " num
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
    echo -e "错误: 请输入有效的数字。"
    ;;
esac
