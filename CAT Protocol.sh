#!/bin/bash

CAT_TOKEN_BOX_DIR="$HOME/cat-token-box"

# 整合安装和配置 CAT Tracker 的步骤
install_and_setup_cat_tracker() {
    echo "1. 环境准备..."
    sudo apt-get update && sudo apt-get upgrade -y && \
    sudo apt-get install -y build-essential libssl-dev curl git

    echo "2. 安装 nvm 和 Node.js 22..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 22 && nvm use 22
    echo "Node.js 版本: $(node -v)"

    echo "3. 安装 Docker 和 Docker Compose..."
    sudo apt-get update && \
    sudo apt-get install docker.io -y

    VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
    DESTINATION=/usr/local/bin/docker-compose
    sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
    sudo chmod 755 $DESTINATION

    sudo systemctl start docker && \
    sudo systemctl enable docker

    echo "4. 设置 CAT Tracker..."
    git clone https://github.com/CATProtocol/cat-token-box.git "$CAT_TOKEN_BOX_DIR" && \
    cd "$CAT_TOKEN_BOX_DIR"

    yarn install

    cat <<EOF > packages/tracker/.env
DATABASE_TYPE=postgres
DATABASE_HOST=127.0.0.1
DATABASE_PORT=5432
DATABASE_DB=postgres
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres

RPC_HOST=127.0.0.1
RPC_PORT=8332
RPC_USER=bitcoin
RPC_PASSWORD=opcatAwesome

NETWORK=mainnet
API_PORT=3000
GENESIS_BLOCK_HEIGHT=0
EOF

    sudo chmod 777 docker/data && \
    sudo chmod 777 docker/pgdata && \
    docker compose up -d

    echo "5. 安装 sCrypt 编译器..."
    yarn add scryptlib

    echo "6. 启动 CAT Tracker..."
    docker build -t tracker:latest .
    docker run -d \
        --name tracker \
        --add-host="host.docker.internal:host-gateway" \
        -e DATABASE_HOST="host.docker.internal" \
        -e RPC_HOST="host.docker.internal" \
        -p 3000:3000 \
        tracker:latest

    echo "查看 CAT Tracker 日志..."
    docker logs -f tracker
}

# 创建钱包
create_wallet() {
    echo "创建钱包..."
    cd "$CAT_TOKEN_BOX_DIR"
    yarn cli wallet create
}

# 查看钱包余额
check_balance() {
    echo "查看钱包余额..."
    cd "$CAT_TOKEN_BOX_DIR"
    yarn cli wallet balances
}

# 铸造 CAT Token
mint_cat_token() {
    read -p "请输入要铸造的 CAT Token ID: " TOKEN_ID
    read -p "请输入铸造的 Token 数量: " TOKEN_AMOUNT
    echo "铸造 CAT Token..."
    cd "$CAT_TOKEN_BOX_DIR"
    yarn cli mint -i "$TOKEN_ID" "$TOKEN_AMOUNT"
}

# 重复铸造 CAT Token
repeat_mint_cat_token() {
    echo "在 cli 目录中创建 script.sh 脚本..."
    cd "$CAT_TOKEN_BOX_DIR"
    
    cat <<EOF > script.sh
#!/bin/bash

command="sudo yarn cli mint -i 45ee725c2c5993b3e4d308842d87e973bf1951f5f7a804b21e4dd964ecd12d6b_0 5"

while true; do
    \$command

    if [ \$? -ne 0 ]; then
        echo "命令执行失败，退出循环"
        exit 1
    fi

    sleep 1
done
EOF

    chmod +x script.sh
    echo "重复铸造 CAT Token..."
    ./script.sh
}

# 显示菜单
show_menu() {
    echo "请选择一个选项:"
    echo "1) 安装和配置 CAT Tracker"
    echo "2) 创建钱包"
    echo "3) 查看钱包余额"
    echo "4) 铸造 CAT Token"
    echo "5) 重复铸造 CAT Token"
    echo "6) 退出"
}

# 处理用户输入
handle_choice() {
    local choice
    read -p "请输入选择 [1-6]: " choice
    case $choice in
        1) install_and_setup_cat_tracker ;;
        2) create_wallet ;;
        3) check_balance ;;
        4) mint_cat_token ;;
        5) repeat_mint_cat_token ;;
        6) exit 0 ;;
        *) echo "无效的选项" ;;
    esac
}

# 主程序循环
while true; do
    show_menu
    handle_choice
done
