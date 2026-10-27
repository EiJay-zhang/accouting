"""初始化 SQLite 数据库。

服务器：

    cd server
    python3 init_db.py

本地想带上示例账单：

    python3 init_db.py --demo

数据库文件由环境变量 DATABASE_PATH 指定，未设置时使用 server/account.db。
"""

import argparse
from pathlib import Path

from dotenv import load_dotenv

from database import init_db, seed_demo


def main() -> None:
    load_dotenv(Path(__file__).parent / ".env")

    parser = argparse.ArgumentParser(description="初始化记账 SQLite 数据库")
    parser.add_argument(
        "--demo",
        action="store_true",
        help="交易表为空时写入示例账单（仅本地开发，不要在服务器上使用）",
    )
    args = parser.parse_args()

    path = init_db()
    print(f"数据库已就绪: {path}")

    if args.demo:
        inserted = seed_demo()
        if inserted:
            print(f"已写入 {inserted} 条示例交易")
        else:
            print("交易表已有数据，跳过示例交易")


if __name__ == "__main__":
    main()
