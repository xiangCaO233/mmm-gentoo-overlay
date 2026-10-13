# MusicMapMaker-Next Gentoo overlay

[中文](#中文) · [English](#english)

## 中文

提供两个包，任选其一：

- `app-editors/musicmapmaker-next-bin`：直接安装二进制版。
- `app-editors/musicmapmaker-next`：普通版本从对应正式发布 tag 全源码编译；`9999` 从最新 `main` 编译开发版。

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

如选择二进制包，将关键字配置中的包名改为 `musicmapmaker-next-bin`，关键字改为 `~amd64`，再运行：

```sh
emerge --ask app-editors/musicmapmaker-next-bin::mmm-gentoo-overlay
```

### Clang 与 PGO

源码包提供 `clang`、`pgo` 两个 USE，默认均关闭。`pgo` 必须同时启用 `clang`；只启用 `clang` 时使用系统所选 LLVM slot 的 Clang 全源码构建，不采集或使用 PGO。未启用 `clang` 时保留 Portage 的编译器配置。

如需 PGO，在 `/etc/portage/package.use/musicmapmaker-next` 中加入：

```text
app-editors/musicmapmaker-next clang pgo
```

每次重新构建会先获取所选版本的源码（稳定版为固定 tag，开发版为 `main`），再从网站实时下载全部已完成的 `.profraw`，按日期及文件名平铺到本次构建的 `pgo-profiles` 目录。配置阶段由上游 `scripts/pgo_merge.py` 调用兼容的 `llvm-profdata` 合并，再通过 `MMM_PGO_USE=ON` 优化业务代码；第三方依赖仍从源码构建，不应用 PGO。下载、解包或合并失败时停止，不静默退回普通构建。

下载仅发生在 `src_unpack`，后续配置和编译不联网。每次构建使用下载开始时的完整采样快照，新上传数据在下次重编译时纳入。支持 `llvm_slot_19` 至 `llvm_slot_23`，默认选择 22。当前原始采样为格式 10；选择 Clang 23 时额外依赖 LLVM 22，由它现场合并成 indexed `.profdata`，再交给 Clang 23 优化。其余 slot 使用同版本工具；如果服务器未来采样格式变化，需要同步更新转换工具，不能修改原始格式号或忽略不兼容文件。开发主线的代码变化也可能使部分函数采样不再匹配，PGO 不保证对所有新代码都有覆盖，也不保证一定提速。

### 更新

```sh
emaint sync -r mmm-gentoo-overlay
emerge --ask --update app-editors/musicmapmaker-next-bin
```

稳定源码版随正常更新选择最新发布版本。开发版需额外接受 `=app-editors/musicmapmaker-next-9999::mmm-gentoo-overlay **`，然后显式重新获取最新代码并编译：

```sh
emerge --ask --oneshot =app-editors/musicmapmaker-next-9999
```

## English

Choose one package:

- `app-editors/musicmapmaker-next-bin`: install the binary package.
- `app-editors/musicmapmaker-next`: ordinary versions build the matching stable release tag from source; `9999` builds the latest development `main`.

### Configure and install

With the Gentoo repository and `dev-vcs/git` already available, create `/etc/portage/repos.conf/mmm-gentoo-overlay.conf` as root using the `repos.conf` section shown above. This works without an eselect-repository public registration. Run `emaint sync -r mmm-gentoo-overlay`.

Add `app-editors/musicmapmaker-next::mmm-gentoo-overlay ~amd64` to `/etc/portage/package.accept_keywords/musicmapmaker-next`, then run:

```sh
emerge --ask app-editors/musicmapmaker-next::mmm-gentoo-overlay
```

For the binary package, use `musicmapmaker-next-bin` in both the keyword entry and the emerge command, and change its accepted keyword to `~amd64`.

### Clang and PGO

The source package provides `clang` and `pgo`, both disabled by default. `pgo` requires `clang`. With only `clang` enabled, all sources are built with the selected system LLVM slot's Clang, without PGO instrumentation or optimization. Without `clang`, Portage's compiler configuration is preserved.

To enable PGO, add to `/etc/portage/package.use/musicmapmaker-next`:

```text
app-editors/musicmapmaker-next clang pgo
```

Each rebuild fetches the selected stable tag or development `main`, downloads a fresh archive of all completed website `.profraw` files during `src_unpack`, and flattens them into a build-local `pgo-profiles` directory using date-prefixed names. During configuration, upstream `scripts/pgo_merge.py` merges the profiles with a compatible `llvm-profdata`. `MMM_PGO_USE=ON` optimizes application code; dependencies are still built from source without PGO. Download, extraction or merge failures stop the build instead of silently disabling PGO. Configuration and compilation do not access the network.

Uploads completed after the download starts enter the next rebuild. Supported slots are `llvm_slot_19` through `llvm_slot_23`, defaulting to 22. Current raw profiles use format 10. With Clang 23, LLVM 22 is an additional build dependency that converts these profiles into backward-compatible indexed `.profdata` on the build machine. Other slots use their matching tools. If the server's raw format changes, the conversion tools need updating; raw version numbers must not be patched and incompatible files must not be silently discarded. Profiles from released versions may not match every function on the development branch, and do not guarantee a performance improvement.

### Update

```sh
emaint sync -r mmm-gentoo-overlay
emerge --ask --update app-editors/musicmapmaker-next-bin
```

Stable source versions follow normal package updates. For development builds, additionally accept `=app-editors/musicmapmaker-next-9999::mmm-gentoo-overlay **`, then fetch and rebuild explicitly:

```sh
emerge --ask --oneshot =app-editors/musicmapmaker-next-9999
```
