#!/usr/bin/env python3
"""从开发版配方生成固定正式 tag 的源码 ebuild，保留旧版本供回退。"""

import argparse
import re
from pathlib import Path


def update_release(root, tag):
    """只接受正式三段版本；重复执行不改已有配方，禁止回退最新版本。"""
    # 版本必须使用标准十进制分量，不接受前导零和 Gentoo 修订号作为上游 tag。
    # 正式 tag 之外的开发版本继续由 9999 包承担，不能混入稳定更新序列。
    match = re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag)
    if not match:
        raise ValueError("Expected a stable release tag such as v0.6.3")
    version = tuple(map(int, match.groups()))
    # 只操作本 overlay 的源码包目录，二进制配方和其他包不属于同步范围。
    package = Path(root) / "app-editors/musicmapmaker-next"
    # 开发版是配方模板；稳定版继承 Clang、PGO 与耗时诊断关闭策略。
    # 统一读取 UTF-8 并写入 LF，避免 CI 平台换行差异生成重复更新。
    text = (package / "musicmapmaker-next-9999.ebuild").read_text(encoding="utf-8")
    # 替换项要求唯一匹配，模板结构变化时失败，不能生成错误版本来源。
    replacements = {
        # PV 来自新 ebuild 文件名；版本文件与其固定 tag 保持一一对应。
        '# 每次获取 main 开发主线最新 HEAD；子模块仍跟随该提交记录的版本。\nEGIT_BRANCH="main"':
            '# 正式版本只获取对应不可变 tag；子模块跟随该 tag 记录的提交。\nEGIT_COMMIT="refs/tags/v${PV}"',
        '# live 包没有发行版关键字，用户必须显式接受 ** 后安装。':
            '# 固定正式 tag 的源码包使用测试关键字，与开发版的 ** 区分。',
        'KEYWORDS=""': 'KEYWORDS="~amd64"',
    }
    for old, new in replacements.items():
        # 校验所有标记后才写文件，模板出错不会留下半个有效源码配方。
        if text.count(old) != 1:
            raise ValueError(f"Release template marker missing or duplicated: {old!r}")
        text = text.replace(old, new)
    # 比较整数分量，0.6.10 必须晚于 0.6.9，不能用字符串排序。
    for existing in package.glob("musicmapmaker-next-*.ebuild"):
        # 只识别正式版本配方，开发版 9999 不参与稳定版本大小比较。
        existing_match = re.fullmatch(r"musicmapmaker-next-(\d+)\.(\d+)\.(\d+)(?:-r\d+)?\.ebuild", existing.name)
        if existing_match and tuple(map(int, existing_match.groups())) > version:
            raise ValueError("Refusing to publish an older source ebuild")
    target = package / f"musicmapmaker-next-{tag[1:]}.ebuild"
    # 网络同步重试可能再次请求同一版本；已存在即视为完成，不制造重复提交。
    if target.exists():
        # 已发布配方不得因为开发版模板改变而被静默覆盖；修订应单独维护。
        print(f"Already present: {target.name}")
        return target
    target.write_text(text, encoding="utf-8", newline="\n")
    # 旧版本文件保留，用户可以显式安装旧 tag，而非跟随一个被改写的配方。
    print(f"Created {target.name} pinned to {tag}")
    return target


if __name__ == "__main__":
    # 参数解析与配方生成分开，隔离测试无需调用网络或修改真实仓库。
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    # 根路径可供隔离测试使用，默认从当前脚本位置解析 overlay 根目录。
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    update_release(args.root, args.tag)
