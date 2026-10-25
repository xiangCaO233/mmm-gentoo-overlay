# Copyright 2026 xiangCaO233
# SPDX-License-Identifier: GPL-3.0-only

EAPI=8

# unpacker 只展开 DEB 数据归档；xdg 负责 Portage 合并后的桌面缓存更新。
# 桌面文件和图标沿用上游应用 ID，以匹配 Wayland 窗口身份。
inherit desktop unpacker xdg

DESCRIPTION="Rhythm game beatmap editor (upstream binary)"
HOMEPAGE="https://github.com/xiangCaO233/MusicMapMaker-Next"
# 版本与 Debian 修订共同固定下载对象，不能替换为指向最新版本的 URL。
SRC_URI="https://downloads.xiang233.top/pool/main/m/musicmapmaker-next/musicmapmaker-next_0.6.4-2+hotfix.1_amd64.deb"
# DEB 不含普通源码顶层目录，解包内容直接作为安装输入。
S="${WORKDIR}"

# 许可证来自上游 LICENSE；testing 关键字不表示已覆盖所有 Gentoo 配置。
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
# 上游 ELF 绑定 glibc ABI，直接排除 musl 配置，避免误报可安装候选。
REQUIRED_USE="elibc_glibc"
# 固定上游 ELF 不参与编译测试，也不允许 Portage 二次剥离符号。
RESTRICT="mirror strip test"

# 主程序的 DT_NEEDED 决定直接依赖；GTK 的递归依赖由 GTK 包负责。
# GLIBC_2.38、CXXABI_1.3.15 与 OPENSSL_3.2.0 来自正式发布 ELF 的版本表。
# 同一路径只允许一个提供者，强阻塞保证替换时先移除另一种包。
# SDL 音频后端会动态加载 ALSA，不能仅依靠 DT_NEEDED 判断声卡运行依赖。
RDEPEND="
	!!app-editors/musicmapmaker-next
	app-misc/ca-certificates
	>=dev-libs/openssl-3.2:0/3
	>=dev-libs/glib-2.26:2
	>=sys-devel/gcc-14[cxx]
	>=sys-libs/glibc-2.38:2.2
	media-libs/alsa-lib
	>=media-libs/fontconfig-2.12.6
	>=media-libs/libpng-1.6.46:0/16
	>=media-libs/vulkan-loader-1.2.131.2
	>=x11-libs/gtk+-3.21.5:3[X,wayland]
	x11-libs/libX11
	x11-libs/libXext
	>=dev-libs/wayland-1.20
"

# 解包由 eclass 完成；显式空阶段避免默认规则尝试构建外来归档。
src_configure() { :; }
src_compile() { :; }

# 仅安装明确审核的四类路径，不能复制整个 DEB 根目录或执行维护脚本。
src_install() {
	# /opt 下保持上游主 ELF 名称；所有写入仍发生在 Portage 暂存镜像。
	exeinto /opt/mmm
	doexe opt/mmm/MusicMapMaker-Next
	# 相对链接支持镜像迁移，并提供桌面文件引用的统一命令名。
	dosym -r /opt/mmm/MusicMapMaker-Next /usr/bin/MusicMapMaker-Next
	# 桌面文件必须与应用 ID 相同；图标只从版本化 DEB 提取。
	domenu usr/share/applications/MusicMapMaker-Next.desktop
	doicon -s scalable usr/share/icons/hicolor/scalable/apps/MusicMapMaker-Next.svg
}
