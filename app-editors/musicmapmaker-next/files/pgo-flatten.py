#!/usr/bin/env python3
"""将服务器 PGO 归档中的完整采样平铺到本次构建的独立目录。"""

import re
import shutil
import sys
import tarfile
from pathlib import Path


def flatten_profiles(archive_path, output_dir):
    """只复制日期目录中的普通 profraw，拒绝路径逃逸、链接和重名覆盖。"""
    output = Path(output_dir)
    # 不复用已有目录，避免本轮归档与历史构建数据混合。
    output.mkdir(parents=True, exist_ok=False)
    count = 0
    with tarfile.open(archive_path, mode="r|gz") as archive:
        for member in archive:
            # 不调用 extract；远程成员路径永远不能控制实际写入位置。
            match = re.fullmatch(r"(\d{4}-\d{2}-\d{2})/([A-Za-z0-9._-]+\.profraw)", member.name)
            if not member.isfile() or not match or member.size <= 0:
                raise ValueError(f"Invalid PGO archive member: {member.name!r}")
            # 日期进入平铺文件名，不同日期的同名采样也不会互相覆盖。
            target = output / f"{match[1]}-{match[2]}"
            with archive.extractfile(member) as source, target.open("xb") as destination:
                shutil.copyfileobj(source, destination)
            count += 1
    if not count:
        # 空响应不得退回无 PGO 构建，避免 USE 的语义与成品不一致。
        raise ValueError("PGO archive contains no profiles")
    print(f"Prepared {count} PGO profiles in {output}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: pgo-flatten.py ARCHIVE OUTPUT_DIRECTORY")
    # 异常让调用方收到非零退出码，Portage 将停止本轮构建。
    flatten_profiles(sys.argv[1], sys.argv[2])
