#!/usr/bin/env python3
"""按原始格式分组转换 PGO，使用所选 LLVM 完成最终合并。"""
import argparse
from pathlib import Path
import subprocess
import tempfile


def merge(profdata, input_dir, output):
    """保留全部采样；任一组无法读取则终止，不降级成无 PGO 构建。"""
    selected = Path(profdata).resolve(strict=True)
    groups = {}
    # 原始格式不向后兼容，同组文件只能交给能够读取该版本的工具。
    # 不改写版本头，也不使用 failure-mode=all 忽略不兼容文件。
    for profile in sorted(Path(input_dir).glob("*.profraw")):
        with profile.open("rb") as source:
            header = source.read(16)
        if len(header) != 16:
            raise ValueError(f"Truncated profile: {profile}")
        # 当前服务器收集 64 位小端 raw；高位保留的变体标志不能当成主格式号。
        # 具体内容仍由 LLVM 校验，读取头部仅用于保持同版本输入成组。
        version = int.from_bytes(header[8:16], "little") & 0xffffffff
        groups.setdefault(version, []).append(str(profile))
    if not groups:
        raise ValueError("No PGO profiles")
    # 首选当前工具，再查同一 Gentoo 前缀中的已安装 LLVM slot。
    # 老工具只负责兼容原始输入，最终 indexed 文件始终由当前工具生成。
    candidates = [selected]
    candidates += [path for path in sorted(selected.parents[2].glob("*/bin/llvm-profdata"), reverse=True)
                   if path != selected and path.is_file()]
    # 分组合并结果是构建期临时文件，成功或失败都由临时目录自动回收。
    # 每个工具必须完整接受同一原始版本的所有文件，不能只抽取部分有效输入。
    # 最终工具仍可能拒绝较新 indexed 格式，此时明确失败，由包依赖约束版本。
    with tempfile.TemporaryDirectory(prefix="pgo-convert-") as temporary:
        converted = []
        for version, profiles in sorted(groups.items()):
            target = str(Path(temporary) / f"raw-{version}.profdata")
            failures = []
            # 先试当前工具，只在原始格式不兼容时尝试已安装的其他读取器。
            # 过程不会联网安装工具，也不调用 PATH 中来源不明的同名程序。
            for tool in candidates:
                result = subprocess.run([str(tool), "merge", "--failure-mode=any", "-o", target, *profiles],
                                        capture_output=True, text=True, timeout=600)
                if result.returncode == 0:
                    print(f"PGO raw v{version}: {len(profiles)} files via {tool}")
                    converted.append(target)
                    break
                # 每次失败都保留诊断，只有完整成功的分组才进入最终合并。
                failures.append(f"{tool}: {result.stderr[:1000]}")
            else:
                raise RuntimeError("No compatible PGO reader: " + "\n".join(failures))
        # 临时结果与最终文件分开；合并失败不能截断上一份可用输出。
        # 不能用 LLVM 22 作为最终合并器读取 LLVM 23 indexed 数据。
        # 此处严格使用配方选择的工具路径；PGO 依赖保证其支持当前格式。
        merged = Path(temporary) / "merged.profdata"
        subprocess.run([str(selected), "merge", "--failure-mode=any", "-o", str(merged), *converted], check=True)
        # 子合并与最终合并都成功后才提交产物，不复用失败过程中的临时文件。
        Path(output).write_bytes(merged.read_bytes())
    print(f"Final PGO: {selected}, {sum(map(len, groups.values()))} input files")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--profdata", required=True)
    parser.add_argument("--input-dir", required=True)
    parser.add_argument("--output", required=True)
    # 命令行要求调用方明确给出工具和目录，避免继承意外的 PATH 版本。
    args = parser.parse_args()
    merge(args.profdata, args.input_dir, args.output)
