# Copyright 2026 xiangCaO233
# SPDX-License-Identifier: GPL-3.0-only

EAPI=8

# git-r3 处理主仓分支 HEAD；递归子模块单独浅克隆，避免 eclass 强制镜像全部历史。
# 在 inherit 前启用，eclass 会自动加入 Git 与 Git LFS 的构建依赖。
EGIT_LFS=1
# Python 仅服务构建生成器，由 eclass 在已有可用解释器中选择一个版本。
PYTHON_COMPAT=( python3_{11..15} )
inherit cmake desktop git-r3 python-any-r1 xdg

DESCRIPTION="Rhythm game beatmap editor"
HOMEPAGE="https://github.com/xiangCaO233/MusicMapMaker-Next"
EGIT_REPO_URI="https://github.com/xiangCaO233/MusicMapMaker-Next.git"
# 每次获取 main 开发主线最新 HEAD；子模块仍跟随该提交记录的版本。
EGIT_BRANCH="main"
# live 包没有发行版关键字，用户必须显式接受 ** 后安装。
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""
# 此初始版本与二进制包共享 glibc 范围，musl 编译支持尚未验证。
REQUIRED_USE="elibc_glibc"
# 上游测试资源不属于安装输入，关闭测试也避免额外拉取测试 LFS 对象。
RESTRICT="test"

# 项目自建音频、图形和脚本依赖；这里仅声明剩余宿主系统接口。
# X11 与 Wayland 同时构建，与上游 GLFW 默认双后端保持一致。
# GIO 提供桌面主题通知，GTK 提供原生文件对话框，它们不由子模块替代。
# curl 的源码包装器固定使用 OpenSSL，不能仅声明 mbedTLS 满足 TLS 需求。
# libpng 为 FreeType 的 PNG 字形提供系统接口，不与内置图标解析混为一谈。
# Vulkan loader 是运行接口，GPU 驱动的选择留给用户现有系统配置。
RDEPEND="
	!!app-editors/musicmapmaker-next-bin
	app-misc/ca-certificates
	dev-libs/glib:2
	dev-libs/openssl:0/3
	dev-libs/wayland
	media-libs/alsa-lib
	media-libs/libpng:0/16
	media-libs/vulkan-loader
	sys-libs/glibc:2.2
	x11-libs/gtk+:3[X,wayland]
	x11-libs/libICE
	x11-libs/libSM
	x11-libs/libX11
	x11-libs/libXcursor
	x11-libs/libXext
	x11-libs/libXi
	x11-libs/libXinerama
	x11-libs/libXrandr
	x11-libs/libxkbcommon
"
# Vulkan 头和 Wayland 协议是编译接口，不需要随主可执行文件分发。
# 不使用主仓的预编译 Vulkan 或 GTK 二进制，头与运行库均来自目标系统。
DEPEND="${RDEPEND}
	dev-util/vulkan-headers
	dev-libs/wayland-protocols
"
# CMake、Meson 和 Make 分别服务主工程及音频子工程；nasm 服务音频汇编。
# 版本最低值来自主工程 cmake_minimum_required，不能只依赖 eclass 默认值。
# 主生成器使用 Ninja，音频 ExternalProject 仍有独立的 Make 构建步骤。
# Meson 配置 Rubber Band，不能因顶层工程使用 CMake 而忽略它。
# Perl 和 Python 服务子工程生成工具；这些工具不会安装到应用目录。
# Wayland scanner 在构建时生成协议代码，无需成为主程序运行依赖。
BDEPEND="${PYTHON_DEPS}
	>=dev-build/cmake-3.31
	dev-build/make
	dev-build/meson
	dev-build/ninja
	dev-lang/perl
	dev-lang/nasm
	dev-util/wayland-scanner
	virtual/pkgconfig
"

# Git 配置环境只影响本阶段和子进程，不修改用户 Git 或 Portage 配置。
src_unpack() {
	# git-r3 的子模块路径强制 mirror，不能仅靠 EGIT_CLONE_TYPE 限制历史。
	# 仅在此阶段禁用其子模块处理；下方由 Git 按 gitlink 固定提交递归检出。
	local EGIT_SUBMODULES=()
	local EGIT_CLONE_TYPE=shallow
	# git-r3 的裸缓存 HEAD 可能指向不存在的默认分支，LFS prune 会因此失败。
	# single 仍只取当前提交的 LFS 对象，但不自动清理缓存，与 Git 历史深度无关。
	local EGIT_LFS_CLONE_TYPE=single
	# 白名单覆盖内置运行资源和桌面图标；预编译库和测试资源保留 LFS 指针。
	# 同样的过滤同时作用于递归子模块，不能意外拉取 ICE 预编译依赖。
	# fetchinclude 同时约束 fetch 与 smudge，checkout 不能再下载黑名单对象。
	# 包只在 unpack 阶段联网取源码，后续构建不得依赖资源同步访问网络。
	local -x GIT_CONFIG_COUNT=2
	local -x GIT_CONFIG_KEY_0=lfs.fetchinclude
	local -x GIT_CONFIG_VALUE_0='assets/**,Modules/Main/src/logo.*'
	local -x GIT_CONFIG_KEY_1=lfs.fetchexclude
	local -x GIT_CONFIG_VALUE_1='3rdpty/prebuilts/**,3rdpty/**/prebuilts/**,tests/data/**'
	git-r3_src_unpack
	# 不使用 --remote，确保所有层级仍遵循各自父仓记录的提交。
	# 固定提交不在分支顶端时 Git 会额外按提交获取，深度仍限制为一层。
	# 禁止隐式 smudge 联网，随后只显式获取白名单内的子模块 LFS 资源。
	GIT_LFS_SKIP_SMUDGE=1 git -C "${S}" submodule update \
		--init --recursive --checkout --depth 1 --single-branch \
		|| die "Shallow submodule checkout failed"
	# 主仓 LFS 由 git-r3 处理；子模块共享本阶段的 include/exclude 环境配置。
	# 全部资源下载保持在 unpack 阶段，失败不得退回完整历史克隆。
	git -C "${S}" submodule foreach --recursive 'git lfs pull' \
		|| die "Submodule LFS resource checkout failed"
}

# 显式选择所有依赖从固定子模块源码构建，禁止预编译库回退或 PGO 下载。
src_configure() {
	# 子模块库采用静态偏好，不等于静态 glibc；宿主图形接口仍动态链接。
	# 关闭 Clang ThinLTO 避免上游优化策略额外要求不声明的 LLVM 链接工具。
	local mycmakeargs=(
		-DSOURCES_BUILD=ON
		-DPROJECT_LINKAGE=static
		-DICE_LINKAGE=static
		# Gentoo 直接安装本机构建结果，无需 DEB 打包工具或 APT 信任材料。
		-DMMM_ENABLE_DEB_PACKAGING=OFF
		-DBUILD_TESTING=OFF
		-DICE_BUILD_TESTS=OFF
		-DMMM_PGO_INSTRUMENT=OFF
		-DMMM_PGO_USE=OFF
		-DMMM_SYNC_TRANSLATIONS_AND_DEFAULT_SKIN=OFF
		-DMMM_DISABLE_CLANG_LTO=ON
	)
	# CMake eclass 保留 Portage 的编译器、用户优化参数和出源码树构建约定。
	cmake_src_configure
}

# 只编译主程序及其依赖，避免构建不属于此包的辅助目标。
# 关闭测试时不运行 CTest；完整 Gentoo 编译验收仍需单独完成。
src_compile() {
	cmake_src_compile MusicMapMaker-Next
}

# 手工安装主 ELF 与桌面资源，避免子项目 install 规则泄漏库、头或工具。
src_install() {
	# ELF 在本机编译后进入同一运行路径，两种包因此必须互斥。
	# 不调用递归 cmake install，固定子模块的安装目标也不能写入镜像。
	exeinto /opt/mmm
	doexe "${BUILD_DIR}/bin/MusicMapMaker-Next"
	dosym -r /opt/mmm/MusicMapMaker-Next /usr/bin/MusicMapMaker-Next
	# SVG 与 PNG 名称沿用应用 ID；xdg eclass 负责合并后的缓存刷新。
	# 资源默认同步由应用首次启动负责，安装阶段不创建任何用户配置目录。
	domenu Modules/Main/src/MusicMapMaker-Next.desktop
	newicon -s scalable Modules/Main/src/logo.svg MusicMapMaker-Next.svg
	newicon -s 512 assets/skins/mmm-default/resources/image/logo.png MusicMapMaker-Next.png
}
