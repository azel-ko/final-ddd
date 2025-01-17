import yaml
import os
import sys
import subprocess

# 获取配置文件路径
config_file = sys.argv[1] if len(sys.argv) > 1 else "../configs/config.yml"

# 读取配置文件
try:
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)
except FileNotFoundError:
    print(f"Error: Config file not found at {config_file}")
    sys.exit(1)
except yaml.YAMLError as e:
    print(f"Error parsing YAML file: {e}")
    sys.exit(1)

# 从配置中提取并设置环境变量
database = config.get('database', {})
redis = config.get('redis', {})

os.environ['DATABASE_SERVICE'] = database.get('type', '')
os.environ['DB_USER'] = database.get('user', '')
os.environ['DB_PASSWORD'] = database.get('password', '')
os.environ['DB_PORT'] = str(database.get('port', ''))
os.environ['DB_NAME'] = database.get('name', '')
os.environ['DB_PATH'] = database.get('path', '')
os.environ['REDIS_PORT'] = str(redis.get('port', ''))

# 打印环境变量
print("Environment variables have been set:")
for key in os.environ:
    if key.startswith('DATABASE_') or key.startswith('DB_') or key.startswith('REDIS_'):
        print(f"{key}={os.environ[key]}")

# 如果需要执行 docker-compose
subprocess.run(["docker-compose","--profile", database.get('type', ''), "-f", "../deployments/docker-compose.yml", "up", "--build", "-d"])
