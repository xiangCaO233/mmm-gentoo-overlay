# MusicMapMaker-Next Gentoo overlay

[中文](#中文) · [English](#english)

## 中文

此独立 overlay 提供两种互斥的 `~amd64` 包：

- `app-editors/musicmapmaker-next`：固定 [0.6.2 源码提交](https://github.com/xiangCaO233/MusicMapMaker-Next/commit/eac67c6d3bf9c077f0e9c664688f0cf8ab827a05)，递归获取固定子模块并在本机编译。
- `app-editors/musicmapmaker-next-bin`：从 [版本化 DEB](https://mmm.xiang233.top/apt/pool/main/m/musicmapmaker-next/musicmapmaker-next_0.6.2-1_amd64.deb) 提取上游已编译的主程序。

两个 0.6.2 包使用同一源码提交 `eac67c6d3bf9c077f0e9c664688f0cf8ab827a05`；二进制 DEB 在 Debian 13 的现有构建环境中由 GCC 14.2.0 生成，其 `build-info.json` 记录了该提交。

两种包均只安装 `/opt/mmm/MusicMapMaker-Next` 主可执行文件、`/usr/bin/MusicMapMaker-Next` 链接、桌面入口与 SVG 图标；源码包还提供 PNG 回退图标。首次启动由应用自己的资源同步流程准备用户资源。二进制包不执行 Debian 维护脚本，不安装 APT 软件源或公钥。

### 注册与安装

需要已有 Gentoo 主仓以及 `dev-vcs/git`。以 root 创建 `/etc/portage/repos.conf/mmm-gentoo-overlay.conf`，内容如下；本仓无需在 eselect-repository 的公共列表中登记：

```ini
[mmm-gentoo-overlay]
location = /var/db/repos/mmm-gentoo-overlay
sync-type = git
sync-uri = https://github.com/xiangCaO233/mmm-gentoo-overlay.git
auto-sync = yes
```

同步：

```sh
emaint sync -r mmm-gentoo-overlay
```

在 `/etc/portage/package.accept_keywords/musicmapmaker-next` 中按所选包加入一行：

```text
app-editors/musicmapmaker-next::mmm-gentoo-overlay ~amd64
```

源码安装：

```sh
emerge --ask app-editors/musicmapmaker-next::mmm-gentoo-overlay
```

如选择二进制包，将关键字配置中的包名改为 `musicmapmaker-next-bin`，再运行：

```sh
emerge --ask app-editors/musicmapmaker-next-bin::mmm-gentoo-overlay
```

### 兼容范围

二进制包使用上游 amd64 GNU/Linux ELF，要求 glibc ≥ 2.38、GCC ≥ 14 的 libstdc++（含 `GLIBCXX_3.4.31` 与 `CXXABI_1.3.15`）、OpenSSL ≥ 3.2、libpng ≥ 1.6.46、GTK 3 和 Vulkan loader。还需安装适合硬件的 Vulkan 驱动并提供图形会话；它不面向 musl、非 amd64 或 Gentoo Prefix。

源码包要求 CMake ≥ 3.31 和能处理上游 Linux C++26 配置的现代 C++ 工具链。它采用 `SOURCES_BUILD=ON`、静态依赖偏好，关闭测试、PGO 和构建期用户资源同步；Git LFS 仅取 `assets/**` 与主程序图标，排除预编译库和测试数据。第三方依赖从固定子模块源码构建，系统 GTK、Vulkan、OpenSSL 等接口仍由 Portage 提供。

`~amd64` 表示本 overlay 的测试关键字。当前 ebuild 未完成 Gentoo 原生完整源码构建和图形会话运行验证；静态检查不能替代这两个边界。源码包固定提交，但 `git-r3` 仍将 VCS 获取标为 `live`，因此 pkgcheck 会报告 `VisibleVcsPkg`；这不表示它跟随最新分支。包许可证来自上游 `LICENSE`（GPL-3），第三方组件继续适用各自上游许可证。

## English

This independent overlay provides two mutually exclusive `~amd64` packages:

- `app-editors/musicmapmaker-next` builds the [fixed 0.6.2 source commit](https://github.com/xiangCaO233/MusicMapMaker-Next/commit/eac67c6d3bf9c077f0e9c664688f0cf8ab827a05) and its pinned recursive submodules locally.
- `app-editors/musicmapmaker-next-bin` extracts the upstream executable from the [versioned DEB](https://mmm.xiang233.top/apt/pool/main/m/musicmapmaker-next/musicmapmaker-next_0.6.2-1_amd64.deb).

Both 0.6.2 packages use source commit `eac67c6d3bf9c077f0e9c664688f0cf8ab827a05`. The binary DEB was produced in the existing Debian 13 build environment using GCC 14.2.0; its `build-info.json` records this commit.

Both install only the main executable at `/opt/mmm/MusicMapMaker-Next`, its `/usr/bin/MusicMapMaker-Next` symlink, a desktop entry, and an SVG icon; the source package also supplies a PNG fallback icon. The application's own first-start resource synchronization prepares user assets. The binary ebuild does not run Debian maintainer scripts or install APT sources or signing keys.

### Configure and install

With the Gentoo repository and `dev-vcs/git` already available, create `/etc/portage/repos.conf/mmm-gentoo-overlay.conf` as root using the `repos.conf` section shown above. This works without an eselect-repository public registration. Run `emaint sync -r mmm-gentoo-overlay`.

Add `app-editors/musicmapmaker-next::mmm-gentoo-overlay ~amd64` to `/etc/portage/package.accept_keywords/musicmapmaker-next`, then run:

```sh
emerge --ask app-editors/musicmapmaker-next::mmm-gentoo-overlay
```

For the binary package, use `musicmapmaker-next-bin` in both the keyword entry and the emerge command.

### Compatibility

The binary package is the upstream amd64 GNU/Linux ELF. It requires glibc ≥ 2.38, GCC ≥ 14's libstdc++ with `GLIBCXX_3.4.31` and `CXXABI_1.3.15`, OpenSSL ≥ 3.2, libpng ≥ 1.6.46, GTK 3, and the Vulkan loader. A graphics session and a hardware-appropriate Vulkan driver are also required. musl, other architectures, and Gentoo Prefix are outside its target scope.

The source package requires CMake ≥ 3.31 and a modern C++ toolchain supporting upstream's Linux C++26 configuration. It enables `SOURCES_BUILD=ON` and static dependency preference, with tests, PGO, and build-time user asset synchronization disabled. Git LFS fetches runtime `assets/**` and application icons while excluding prebuilt libraries and test data. Bundled dependencies build from pinned submodule sources; Portage supplies system interfaces such as GTK, Vulkan, and OpenSSL.

`~amd64` is this overlay's testing keyword. A full native Gentoo source build and graphical runtime verification are still pending; static checks do not establish either result. The source commit is fixed, but `git-r3` still marks VCS fetching as `live`, producing pkgcheck's `VisibleVcsPkg` warning; the package does not follow the newest branch commit. The package license follows upstream `LICENSE` (GPL-3), and third-party components retain their upstream licenses.

## Maintenance references / 维护参考

- [Gentoo EAPI documentation](https://devmanual.gentoo.org/ebuild-writing/eapi/index.html)
- [unpacker.eclass](https://devmanual.gentoo.org/eclass-reference/unpacker.eclass/index.html), [desktop.eclass](https://devmanual.gentoo.org/eclass-reference/desktop.eclass/index.html), [xdg.eclass](https://devmanual.gentoo.org/eclass-reference/xdg.eclass/index.html)
- [git-r3.eclass](https://devmanual.gentoo.org/eclass-reference/git-r3.eclass/index.html), [cmake.eclass](https://devmanual.gentoo.org/eclass-reference/cmake.eclass/index.html)
- [Git LFS configuration](https://github.com/git-lfs/git-lfs/blob/main/docs/man/git-lfs-config.adoc)
