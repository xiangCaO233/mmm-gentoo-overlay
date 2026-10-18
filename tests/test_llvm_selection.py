"""验证两种配方在自动与手动模式中选用正确的已安装工具链。"""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]

# 测试只模拟包管理器已安装数据库，不改宿主 LLVM 或 Portage 配置。
# 全部元数据函数由桩提供，真实选择函数仍从完整 ebuild 加载。
HARNESS = r'''
inherit() { :; }
llvm_gen_dep() { :; }
use() { [[ " ${FLAGS} " == *" $1 "* ]]; }
has_version() { [[ " ${INSTALLED} " == *" $2 "* ]]; }
einfo() { :; }
die() { echo "$*" >&2; exit 90; }
source "$1"
LLVM_SLOT=22
source_select_llvm
printf '%s' "$LLVM_SLOT"
'''


class LlvmSelectionTest(unittest.TestCase):
    """稳定版与开发版使用相同工具链契约，分别执行每种候选情况。"""

    def choose(self, flags, installed):
        # 独立 Bash 进程避免上一用例的 LLVM_SLOT 泄漏到下一个用例。
        # source 只执行静态元数据；不会下载源码或启动实际编译。
        results = []
        for version in ("0.6.3", "9999"):
            recipe = ROOT / f"app-editors/musicmapmaker-next/musicmapmaker-next-{version}.ebuild"
            results.append(subprocess.run(
                ["bash", "-c", HARNESS, "test", str(recipe)],
                env={"PATH": "/usr/bin:/bin", "FLAGS": flags, "INSTALLED": installed},
                capture_output=True, text=True))
        return results

    def test_highest_installed(self):
        # 高、低版本共存时不沿用 eclass 的默认 22。
        for result in self.choose("llvm-auto", "llvm-core/clang:22 llvm-core/clang:23"):
            self.assertEqual((result.returncode, result.stdout), (0, "23"))

    def test_older_installed_without_pgo(self):
        # 未安装 23 且不启用 PGO 时可以使用已有的旧版本，不强装最高可用版。
        for result in self.choose("llvm-auto", "llvm-core/clang:20 llvm-core/clang:22"):
            self.assertEqual((result.returncode, result.stdout), (0, "22"))

    def test_manual_slot(self):
        # 关闭自动模式才保留手动 slot，自动模式不读取这种回退选择。
        for result in self.choose("", "llvm-core/clang:22 llvm-core/clang:23"):
            self.assertEqual((result.returncode, result.stdout), (0, "22"))

    def test_pgo_requires_matching_tools(self):
        # PGO 除编译器外还要求同 slot 的工具，不能混用新编译器与旧合并器。
        for result in self.choose("llvm-auto pgo", "llvm-core/clang:23 llvm-core/llvm:23"):
            self.assertEqual((result.returncode, result.stdout), (0, "23"))

    def test_missing_pgo_tool_fails(self):
        # 无法满足当前 indexed 格式时必须失败，不能静默退回 LLVM 22 或关闭 PGO。
        for result in self.choose("llvm-auto pgo", "llvm-core/clang:23 llvm-core/llvm:22"):
            self.assertEqual(result.returncode, 90)


if __name__ == "__main__":
    unittest.main()
