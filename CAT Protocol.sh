#!/bin/bash

# 定义所需的文件路径和变量
Crontab_file="/usr/bin/crontab"

# 提示信息前缀
Info="[信息]"
Error="[错误]"
Tip="[注意]"

# 检查是否以root身份运行
check_root() {
    [[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限), 无法继续操作, 请更换ROOT账号或使用 sudo su 命令获取临时ROOT权限。" && exit 1
}

# 安装必要的依赖和全节点
install_env_and_full_node() {
    check_root
    sudo apt update && sudo apt upgrade -y
    sudo apt install curl tar wget clang pkg-config libssl-dev jq build-essential git make ncdu unzip zip docker.io -y
    
    # 安装docker-compose
    VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
    DESTINATION=/usr/local/bin/docker-compose
    sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
    sudo chmod 755 $DESTINATION

    # 安装npm并更新Node版本
    sudo apt-get install npm -y
    sudo npm install n -g
    sudo n stable
    sudo npm i -g yarn

    # 克隆项目代码并进行构建
    git clone https://github.com/CATProtocol/cat-token-box
    cd cat-token-box
    sudo yarn install
    sudo yarn build

    # 设置并启动docker容器
    cd ./packages/tracker/
    sudo chmod 777 docker/data
    sudo chmod 777 docker/pgdata
    sudo docker-compose up -d

    cd ../../
    sudo docker build -t tracker:latest .
    sudo docker run -d \
        --name tracker \
        --add-host="host.docker.internal:host-gateway" \
        -e DATABASE_HOST="host.docker.internal" \
        -e RPC_HOST="host.docker.internal" \
        -p 3000:3000 \
        tracker:latest

    # 配置文件设置
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

    # 创建自动mint的脚本
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

# 创建钱包并显示地址和助记词
create_wallet() {
    echo -e "\n"
    cd ~/cat-token-box/packages/cli
    sudo yarn cli wallet create
    echo -e "\n"
    sudo yarn cli wallet address
    echo -e "请保存上面创建好的钱包地址和助记词"
}

# 开始mint CAT代币
start_mint_cat() {
    cd ~/cat-token-box/packages/cli
    bash ~/cat-token-box/packages/cli/mint_script.sh
}

# 查看节点日志
check_node_log() {
    docker logs -f --tail 100 tracker
}

# 查看钱包余额
check_wallet_balance() {
    cd ~/cat-token-box/packages/cli
    sudo yarn cli wallet balances
}

# 卸载所有组件和文件
uninstall() {
    check_root

    # 停止并删除Docker容器和镜像
    echo "停止并删除Docker容器和镜像..."
    sudo docker stop tracker
    sudo docker rm tracker
    sudo docker rmi tracker:latest
    sudo docker-compose down
    sudo rm -f /usr/local/bin/docker-compose

    # 删除安装的文件和目录
    echo "删除项目目录..."
    sudo rm -rf ~/cat-token-box

    # 卸载软件包
    echo "卸载软件包..."
    sudo apt-get purge --auto-remove docker.io npm yarn -y

    echo "卸载完成。"
}

# 主菜单
echo "dusk_network 一键安装脚本"
echo " 1. 安装依赖环境和全节点"
echo " 2. 创建钱包"
echo " 3. 开始 mint cat"
echo " 4. 查看节点同步日志"
echo " 5. 查看钱包余额"
echo " 6. 卸载所有组件和文件"
echo -n "请输入操作对应的数字: "
read num

# 根据用户输入选择功能
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
6)
    uninstall
    ;;
*)
    echo "${Error} 请输入正确的数字"
    ;;
esac
