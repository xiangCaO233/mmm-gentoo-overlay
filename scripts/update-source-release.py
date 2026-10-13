#!/usr/bin/env python3
"""从开发版配方生成固定正式 tag 的源码 ebuild，保留旧版本供回退。"""

import argparse
import hashlib
import re
from pathlib import Path


# /// @brief 从统一模板生成正式版或固定热修复修订的源码包。
# @param root overlay 根目录，测试可传隔离目录。
# @param tag 正式发布基线，不直接接受热修复后缀。
# @param hotfix_revision 零为正式版，正数为独立的 Gentoo 包修订。
# @param deb 热修复使用已经验证且公开的同修订 DEB。
# @warning 仅生成配方；公开发布身份必须由调用方先验证。
def update_release(root, tag, hotfix_revision=0, deb=None):
    """只接受正式三段版本；重复执行不改已有配方，禁止回退最新版本。"""
    # 版本必须使用标准十进制分量，不接受前导零和 Gentoo 修订号作为上游 tag。
    # 正式 tag 之外的开发版本继续由 9999 包承担，不能混入稳定更新序列。
    match = re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag)
    if not match:
        raise ValueError("Expected a stable release tag such as v0.6.3")
    version = tuple(map(int, match.groups()))
    # 热修复使用 Gentoo 修订号，不能将包固定到会继续推进的 hotfix 分支。
    if not 0 <= hotfix_revision <= 2147483647:
        raise ValueError("Invalid hotfix revision")
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
    if hotfix_revision:
        # 独立不可变 tag 保存这一修订的源码；PR 是 Gentoo 的 rN，不是上游版本。
        text = text.replace('EGIT_COMMIT="refs/tags/v${PV}"',
                            'EGIT_COMMIT="refs/tags/v${PV}-hotfix.${PR#r}"')
        # 应用内修订与包修订一致，配置时显式导出而不污染用户全局环境。
        text = text.replace('src_configure() {', 'src_configure() {\n'
                            '\t# 固定源码热修复身份，防止客户端把它当作修订零。\n'
                            '\tlocal -x MMM_HOTFIX_REVISION="${PR#r}"')
    # 比较整数分量，0.6.10 必须晚于 0.6.9，不能用字符串排序。
    for existing in package.glob("musicmapmaker-next-*.ebuild"):
        # 同一正式版本的修订也按整数排序，旧 rN 不能进入更高修订之后。
        # 只识别正式版本配方，开发版 9999 不参与稳定版本大小比较。
        existing_match = re.fullmatch(r"musicmapmaker-next-(\d+)\.(\d+)\.(\d+)(?:-r(\d+))?\.ebuild", existing.name)
        if existing_match:
            existing_version = tuple(map(int, existing_match.groups()[:3]))
            if existing_version > version or (existing_version == version and
                    int(existing_match[4] or '0') > hotfix_revision):
                raise ValueError("Refusing to publish an older source ebuild")
    suffix = f"-r{hotfix_revision}" if hotfix_revision else ""
    target = package / f"musicmapmaker-next-{tag[1:]}{suffix}.ebuild"
    # 网络同步重试可能再次请求同一版本；已存在即视为完成，不制造重复提交。
    if target.exists():
        # 已发布配方不得因为开发版模板改变而被静默覆盖；修订应单独维护。
        print(f"Already present: {target.name}")
    else:
        target.write_text(text, encoding="utf-8", newline="\n")
    if hotfix_revision:
        # 二进制用户也必须收到修复；源文件与 Manifest 绑定同一已发布 DEB。
        if deb is None:
            raise ValueError("Hotfix requires the validated published DEB")
        update_binary_hotfix(root, tag, hotfix_revision, Path(deb))
    # 旧版本文件保留，用户可以显式安装旧 tag，而非跟随一个被改写的配方。
    print(f"Created {target.name} pinned to {tag}")
    return target


# /// @brief 将同一程序修订映射成可升级的 Gentoo 二进制包。
# @warning 输入 DEB 必须先通过源提交、控制字段和主 ELF 的一致性检查。
# 本函数只计算摘要和生成文本，不解包或运行 Debian 安装脚本。
def update_binary_hotfix(root, tag, revision, deb):
    """按实际 DEB 名称和摘要新增二进制修订，禁止替换历史下载对象。"""
    package = Path(root) / 'app-editors/musicmapmaker-next-bin'
    # 正式包已有 r1 对应 Debian 修订 2；热修复 N 使用 r(N+1) 避免回退。
    target = package / f'musicmapmaker-next-bin-{tag[1:]}-r{revision + 1}.ebuild'
    if not re.fullmatch(rf'musicmapmaker-next_{re.escape(tag[1:])}-[1-9][0-9]*\+hotfix\.{revision}_amd64\.deb', deb.name):
        raise ValueError('DEB filename does not match the hotfix identity')
    # 选择最高现有配方作为安装模板，保留既有运行依赖与安装约束。
    candidates = list(package.glob('*.ebuild'))
    template = max(candidates, key=lambda p: tuple(map(int, re.findall(r'\d+', p.stem))))
    # URL 固定到具体文件，热修复不会覆盖原正式版 URI。
    text = template.read_text(encoding='utf-8')
    uri = f'SRC_URI="https://downloads.xiang233.top/pool/main/m/musicmapmaker-next/{deb.name}"'
    text, changed = re.subn(r'^SRC_URI=.*$', uri, text, flags=re.MULTILINE)
    if changed != 1:
        raise ValueError('Binary template has no unique SRC_URI')
    # 增量读文件，生成 Portage 要求的两种散列，不把整个包加载到内存。
    hashes = [hashlib.blake2b(), hashlib.sha512()]
    with deb.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            for digest in hashes:
                digest.update(chunk)
    record = f'DIST {deb.name} {deb.stat().st_size} BLAKE2B {hashes[0].hexdigest()} SHA512 {hashes[1].hexdigest()}'
    manifest = package / 'Manifest'
    records = manifest.read_text(encoding='utf-8').splitlines()
    # 历史 DIST 行保留，已经安装旧版本的用户仍可验证和重新取得其包。
    # 同名文件的不同摘要必须拒绝，不能静默更新历史版本的 Manifest。
    matching = [line for line in records if line.startswith(f'DIST {deb.name} ')]
    if matching and matching != [record]:
        raise ValueError('Published DEB checksum differs from existing Manifest')
    if target.exists() and target.read_text(encoding='utf-8') != text:
        raise ValueError('Existing hotfix binary ebuild differs')
    target.write_text(text, encoding='utf-8', newline='\n')
    # 完全相同的重复请求不追加 DIST 行，恢复不会制造不同的索引集合。
    if not matching:
        manifest.write_text('\n'.join(records + [record]) + '\n', encoding='utf-8', newline='\n')


if __name__ == "__main__":
    # 参数解析与配方生成分开，隔离测试无需调用网络或修改真实仓库。
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--hotfix-revision", type=int, default=0)
    parser.add_argument("--deb", type=Path)
    # 热修复文件路径只用于本机摘要计算，不能作为任意远程下载地址。
    # 根路径可供隔离测试使用，默认从当前脚本位置解析 overlay 根目录。
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    update_release(args.root, args.tag, args.hotfix_revision, args.deb)
