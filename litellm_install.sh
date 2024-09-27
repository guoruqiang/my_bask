#!/bin/bash

# 获取当前用户
USER_NAME=$(whoami)
USER_HOME=$(eval echo ~$USER_NAME)

# 输出当前用户信息
echo "当前用户是: $USER_NAME"

# 确定目录路径，根据用户类型选择
if [ "$USER_NAME" = "root" ]; then
    DIRECTORY="$USER_HOME/litellm"
else
    DIRECTORY="/home/$USER_NAME/litellm"
fi

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "Docker未安装，正在安装..."
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y docker-ce
    sudo systemctl start docker
    sudo systemctl enable docker
else
    echo "Docker已安装"
    sudo docker --version
fi

# 检查Docker Compose是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose未安装，正在安装..."
    DOCKER_COMPOSE_VERSION="v2.24.6"
    sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
else
    echo "Docker Compose已安装"
    docker-compose --version
fi

# 创建目录
mkdir -p "$DIRECTORY" || { echo "无法创建目录: $DIRECTORY"; exit 1; }

# 提示用户输入AWS凭证
read -p "请输入 LITELLM_MASTER_KEY（你调用使用的APIKEY）: " LITELLM_MASTER_KEY
read -p "请输入 AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -p "请输入 AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
read -p "请输入 AWS Region Name: " AWS_REGION_NAME

# 创建docker-compose.yml
cat <<EOL > "$DIRECTORY/docker-compose.yml"
# compose.yaml
services:
  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    environment:
      LITELLM_MASTER_KEY: "$LITELLM_MASTER_KEY"
    entrypoint: "litellm"
    ports:
      - "4000:4000"
    command: ["--port", "4000", "--config", "/app/config.yaml", "--detailed_debug"]
    volumes:
      - ./litellm_config.yaml:/app/config.yaml:ro
      - ~/.aws:/root/.aws:ro
    restart: always
EOL

# 创建litellm_config.yaml
cat <<EOL > "$DIRECTORY/litellm_config.yaml"
# litellm_config.yaml
aws_credentials: &aws_credentials
  aws_access_key_id: $AWS_ACCESS_KEY_ID
  aws_secret_access_key: $AWS_SECRET_ACCESS_KEY
  aws_region_name: $AWS_REGION_NAME

model_list:
  - model_name: claude-instant-1.2
    litellm_params:
      model: anthropic.claude-instant-v1
      <<: *aws_credentials
  - model_name: claude-2.0
    litellm_params:
      model: anthropic.claude-v2
      <<: *aws_credentials
  - model_name: claude-2.1
    litellm_params:
      model: anthropic.claude-v2:1
      <<: *aws_credentials
  - model_name: claude-3-5-sonnet-20240620
    litellm_params:
      model: anthropic.claude-3-5-sonnet-20240620-v1:0
      <<: *aws_credentials
  - model_name: claude-3-sonnet-20240229
    litellm_params:
      model: anthropic.claude-3-sonnet-20240229-v1:0
      <<: *aws_credentials
  - model_name: claude-3-opus-20240229
    litellm_params:
      model: anthropic.claude-3-opus-20240229-v1:0
      <<: *aws_credentials
  - model_name: claude-3-haiku-20240307
    litellm_params:
      model: anthropic.claude-3-haiku-20240307-v1:0
      <<: *aws_credentials
EOL

# 检查Docker是否在运行
if [ "$(docker ps -q -f name=litellm)" ]; then
    echo "Docker容器正在运行，正在停止..."
    sudo docker-compose -f "$DIRECTORY/docker-compose.yml" down
else
    echo "Docker容器未运行，正在拉取最新镜像并启动..."
    sudo docker-compose -f "$DIRECTORY/docker-compose.yml" pull && sudo docker-compose -f "$DIRECTORY/docker-compose.yml" up -d
fi

echo "设置完成，litellm已被配置。"
