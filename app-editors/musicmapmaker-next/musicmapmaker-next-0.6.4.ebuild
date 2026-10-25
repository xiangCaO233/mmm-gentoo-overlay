# Copyright 2026 xiangCaO233
# SPDX-License-Identifier: GPL-3.0-only

EAPI=8

# git-r3 处理主仓分支 HEAD；递归子模块单独浅克隆，避免 eclass 强制镜像全部历史。
# 在 inherit 前启用，eclass 会自动加入 Git 与 Git LFS 的构建依赖。
EGIT_LFS=1
# Python 仅服务构建生成器，由 eclass 在已有可用解释器中选择一个版本。
PYTHON_COMPAT=( python3_{11..15} )
# LLVM 仅在 clang USE 开启时成为依赖；原始数据另由兼容的旧工具转换。
LLVM_COMPAT=( {19..23} )
LLVM_OPTIONAL=1
inherit cmake desktop git-r3 llvm-r2 python-any-r1 xdg

DESCRIPTION="Rhythm game beatmap editor"
HOMEPAGE="https://github.com/xiangCaO233/MusicMapMaker-Next"
EGIT_REPO_URI="https://github.com/xiangCaO233/MusicMapMaker-Next.git"
# 正式版本只获取对应不可变 tag；子模块跟随该 tag 记录的提交。
EGIT_COMMIT="refs/tags/v${PV}"
# 固定正式 tag 的源码包使用测试关键字，与开发版的 ** 区分。
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
# 此初始版本与二进制包共享 glibc 范围，musl 编译支持尚未验证。
IUSE="clang pgo +llvm-auto"
REQUIRED_USE="elibc_glibc pgo? ( clang !llvm-auto? ( llvm_slot_23 ) ) clang? ( !llvm-auto? ( ${LLVM_REQUIRED_USE} ) )"
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
# 输出静态候选依赖，元数据阶段禁止查询已安装软件影响依赖内容。
# minimum 为最低支持 slot；PGO 当前 indexed 格式要求编译工具至少为 23。
# 候选逆序使依赖解析优先保留已安装的高版本，实际选择在 pkg_setup 复核。
# 不在这里使用 has_version；静态 BDEPEND 必须能在其他用户机器一致生成。
# 只有 pkg_setup 读取已安装数据库，防止生成依赖缓存后锁死当前主机版本。
source_llvm_auto_deps() {
	local minimum=${1} index slot
	echo '|| ('
	for (( index=${#LLVM_COMPAT[@]}-1; index>=0; --index )); do
		slot=${LLVM_COMPAT[index]}
		(( slot >= minimum )) || continue
		echo "( llvm-core/clang:${slot} pgo? ( llvm-core/llvm:${slot} ) )"
	done
	echo ')'
}

# CMake、Meson 和 Make 分别服务主工程及音频子工程；nasm 服务音频汇编。
# 版本最低值来自主工程 cmake_minimum_required，不能只依赖 eclass 默认值。
# 主生成器使用 Ninja，音频 ExternalProject 仍有独立的 Make 构建步骤。
# Meson 配置 Rubber Band，不能因顶层工程使用 CMake 而忽略它。
# Perl 和 Python 服务子工程生成工具；这些工具不会安装到应用目录。
# Wayland scanner 在构建时生成协议代码，无需成为主程序运行依赖。
# LLVM 23 的 raw 格式为 11；额外用 LLVM 22 将网站格式 10 转为 indexed profdata。
# 自动与手动分支互斥，不把 eclass 默认 slot 作为额外固定依赖。
BDEPEND="${PYTHON_DEPS}
	>=dev-build/cmake-3.31
	dev-build/make
	dev-build/meson
	dev-build/ninja
	dev-lang/perl
	dev-lang/nasm
	dev-util/wayland-scanner
	virtual/pkgconfig
	clang? (
		llvm-auto? (
			pgo? ( $(source_llvm_auto_deps 23) )
			!pgo? ( $(source_llvm_auto_deps 19) )
		)
		!llvm-auto? ( $(llvm_gen_dep '
			llvm-core/clang:${LLVM_SLOT}
			pgo? ( llvm-core/llvm:${LLVM_SLOT} )
		') )
	)
	pgo? ( net-misc/curl[ssl] llvm-core/llvm:22 )
"

# 选择构建机已安装的最高兼容工具链，不因 eclass 默认 slot 而降级。
# 只有关闭 llvm-auto 才遵循用户显式选择的 llvm_slot_*，兼顾手动回退。
# PGO 的最终 indexed 数据不能反向交给旧编译器，故该模式至少使用 LLVM 23。
source_select_llvm() {
	use llvm-auto || return 0
	local index slot
	for (( index=${#LLVM_COMPAT[@]}-1; index>=0; --index )); do
		slot=${LLVM_COMPAT[index]}
		if use pgo; then
			(( slot >= 23 )) || continue
			has_version -b "llvm-core/llvm:${slot}" || continue
		fi
		has_version -b "llvm-core/clang:${slot}" || continue
		# 通过 BDEPEND 的已安装数据库检查后发布给后续所有构建阶段。
		# llvm-r2 的路径及 ABI 设置仍由既有 eclass 负责，不手工替换系统软链接。
		export LLVM_SLOT=${slot}
		einfo "自动选择已安装的最高兼容 LLVM ${LLVM_SLOT}"
		return
	done
	die "No installed compatible LLVM toolchain; resolve BDEPEND first"
}

# 可选 LLVM 不自动导出 setup；显式保留 Python 解释器选择和 LLVM slot 设置。
pkg_setup() {
	python-any-r1_pkg_setup
	if use clang; then
		source_select_llvm
		llvm-r2_pkg_setup
	fi
}

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
	if use pgo; then
		# 此 live 端点每次实时归档，不能放入 SRC_URI 缓存为固定历史 distfile。
		# 所有网络访问限定于 unpack；后续配置只消费本次下载的本地快照。
		curl --fail --location --retry 3 --connect-timeout 30 --max-time 600 \
			--output "${T}/pgo-profiles.tar.gz" \
			https://mmm.xiang233.top/api/performance/download \
			|| die "PGO profile download failed"
		# 只读取普通 profraw 成员并平铺，不能直接解压远程归档中的任意路径。
		"${PYTHON}" "${FILESDIR}/pgo-flatten.py" \
			"${T}/pgo-profiles.tar.gz" "${WORKDIR}/pgo-profiles" \
			|| die "PGO profile extraction failed"
	fi
}

# 过渡期 main 尚未包含 develop 的耗时开关，先补齐同一开关再关闭诊断。
src_prepare() {
	cmake_src_prepare
	# 新上游已提供开关时不重复打补丁，避免未来更新出现重复应用冲突。
	if ! grep -q 'option(MMM_ENABLE_BUILD_TIMING' "${S}/cmake/project-configure.cmake"; then
		eapply "${FILESDIR}/0001-build-timing-option.patch"
	fi
}

# 所有依赖仍从固定子模块源码构建；PGO 配置阶段禁止再次联网。
src_configure() {
	if use clang; then
		# 绝对路径固定系统 slot 的工具，递归 CMake、Meson 和 Make 同样继承。
		local llvm_bin="$(get_llvm_prefix -b)/bin"
		export CC="${llvm_bin}/clang" CXX="${llvm_bin}/clang++"
		export AR="${llvm_bin}/llvm-ar" RANLIB="${llvm_bin}/llvm-ranlib"
	fi
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
		# 打包不采集编译耗时，也不执行链接后的耗时排序报告。
		-DMMM_ENABLE_BUILD_TIMING=OFF
		-DMMM_PGO_USE=$(usex pgo ON OFF)
		-DMMM_SYNC_TRANSLATIONS_AND_DEFAULT_SKIN=OFF
		-DMMM_DISABLE_CLANG_LTO=ON
	)
	if use pgo; then
		# 原始采样按版本分别读取，最终 indexed 数据由当前 LLVM 合并。
		# 旧 LLVM 仅作 raw 兼容转换，不参与本包编译或最终优化数据生成。
		# 当前阶段只消费 unpack 已下载的文件，不重新请求服务器数据。
		# 最终合并器和 CC/CXX 来自同一个自动或手动选择的 LLVM slot。
		local profdata_bin="${llvm_bin}/llvm-profdata"
		"${PYTHON}" "${FILESDIR}/pgo-merge.py" \
			--profdata "${profdata_bin}" \
			--input-dir "${WORKDIR}/pgo-profiles" \
			--output "${WORKDIR}/pgo-merged.profdata" \
			|| die "PGO version-compatible merge failed"
		mycmakeargs+=(
			-DMMM_PGO_DATA="${WORKDIR}/pgo-merged.profdata"
			-DLLVM_PROFDATA="${profdata_bin}"
			-DPython3_EXECUTABLE="${PYTHON}"
		)
	fi
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
