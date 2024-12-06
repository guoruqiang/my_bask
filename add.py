import requests
import logging
import json

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# 常量配置
ONE_API_TOKEN = "your_api_token"
ONE_API_BASE_URL = "https://api.example.com"
LATEST_GEMINI_MODELS = [
    "gemini-1.5-pro-802",
    "gemini-1.5-flash-802",
    "gemini-1.5-flash-80-exp-0924",
    "gemini-1.5-flash-80",
    # ...其他模型
]

def get_channel_list():
    """获取所有 Gemini 渠道的列表"""
    headers = {
        "Authorization": f"Bearer {ONE_API_TOKEN}",
    }
    all_channels = []
    page = 0
    while True:
        try:
            response = requests.get(f"{ONE_API_BASE_URL}/channel/?p={page}&page_size=100", headers=headers)
            response.raise_for_status()  # 检查请求是否成功

            json_data = response.json()
            if not json_data.get("success", True):
                logging.error(f"获取渠道列表失败: {json_data.get('message', '未知错误')}")
                break  # 停止获取

            data = json_data["data"]
            if not data:  # 没有更多数据了
                break
            all_channels.extend(data)
            page += 1
        except requests.exceptions.RequestException as e:
            logging.error(f"获取渠道列表失败: {e}")
            break  # 停止获取
    return all_channels

def update_channel_models(channel_data):
    """更新指定渠道的模型列表"""
    headers = {
        "Authorization": f"Bearer {ONE_API_TOKEN}",
        "Content-Type": "application/json",
    }

    current_models = channel_data["models"].split(",")
    new_models = list(set(current_models + LATEST_GEMINI_MODELS))  # 合并并去重
    channel_data["models"] = ",".join(new_models)

    # 设置特定的状态码映射
    channel_data["status_code_mapping"] = json.dumps({"429": "403"})

    try:
        response = requests.put(f"{ONE_API_BASE_URL}/channel/", headers=headers, json=channel_data)
        response.raise_for_status()  # 检查请求是否成功
        logging.info(f"更新渠道 {channel_data['name']} 成功")
    except requests.exceptions.RequestException as e:
        logging.error(f"更新渠道 {channel_data['name']} 失败: {e}")

def main():
    """主函数"""
    channel_list = get_channel_list()

    if not channel_list:
        logging.warning("没有获取到任何渠道")
        return

    for channel in channel_list:
        update_channel_models(channel)

if __name__ == "__main__":
    main()
