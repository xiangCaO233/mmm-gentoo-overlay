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

源码包提供 `clang`、`pgo` 两个 USE，默认均关闭；`llvm-auto` 默认开启。`pgo` 必须同时启用 `clang`；只启用 `clang` 时优先使用构建机已安装且受支持的最高 LLVM slot 全源码构建，不采集或使用 PGO。未启用 `clang` 时保留 Portage 的编译器配置。

如需 PGO，在 `/etc/portage/package.use/musicmapmaker-next` 中加入：

```text
app-editors/musicmapmaker-next clang pgo
```

每次重新构建会先获取所选版本的源码（稳定版为固定 tag，开发版为 `main`），再从网站实时下载全部已完成的 `.profraw`，按日期及文件名平铺到本次构建的 `pgo-profiles` 目录。配置阶段按 raw 格式分组，用兼容的 `llvm-profdata` 转成 indexed 数据，再由所选 LLVM 完成最终合并，再通过 `MMM_PGO_USE=ON` 优化业务代码；第三方依赖仍从源码构建，不应用 PGO。下载、解包或合并失败时停止，不静默退回普通构建。

下载仅发生在 `src_unpack`，后续配置和编译不联网。每次构建使用下载开始时的完整采样快照，新上传数据在下次重编译时纳入。支持 LLVM 19 至 23；默认 `llvm-auto` 按版本从高到低选择已安装的兼容 Clang，不固定为 eclass 的默认 22。需要手动选择时关闭 `llvm-auto` 并设置 `llvm_slot_*`。

PGO 当前至少需要 LLVM 23，旧版编译器无法消费新格式的 indexed 数据。格式 10 使用兼容的 LLVM 22 转换，格式 11 使用 LLVM 23 转换；最终合并和业务编译使用自动选择的最高兼容 LLVM。旧工具只服务原始数据转换，不用于降级编译。任何一组无法转换都会终止，不修改原始格式号、不丢弃采样。历史 `0.6.2` 配方保留原行为，当前 `0.6.3` 与 `9999` 使用新策略。

开发主线的代码变化也可能使部分函数采样不再匹配，PGO 不保证对所有新代码都有覆盖，也不保证一定提速。

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

The source package provides `clang` and `pgo`, both disabled by default; `llvm-auto` is enabled by default. `pgo` requires `clang`. With only `clang` enabled, all sources are built with the highest installed supported Clang, without PGO instrumentation or optimization. Without `clang`, Portage's compiler configuration is preserved.

To enable PGO, add to `/etc/portage/package.use/musicmapmaker-next`:

```text
app-editors/musicmapmaker-next clang pgo
```

Each rebuild fetches the selected stable tag or development `main`, downloads a fresh archive of all completed website `.profraw` files during `src_unpack`, and flattens them into a build-local `pgo-profiles` directory using date-prefixed names. During configuration, raw profiles are converted by format group and the selected LLVM merges the resulting indexed profiles. `MMM_PGO_USE=ON` optimizes application code; dependencies are still built from source without PGO. Download, extraction or merge failures stop the build instead of silently disabling PGO. Configuration and compilation do not access the network.

Uploads completed after the download starts enter the next rebuild. LLVM 19 through 23 are supported. With default `llvm-auto`, the highest installed compatible toolchain is selected rather than the eclass default of 22. Disable `llvm-auto` and select `llvm_slot_*` to choose manually.

PGO currently requires LLVM 23 or newer to consume the indexed format. LLVM 22 converts raw version 10 and LLVM 23 converts version 11; the selected highest compatible LLVM performs the final merge and compilation. Conversion failures stop the build without discarding profiles or rewriting raw headers. This policy applies to `0.6.3` and `9999`; the historical `0.6.2` recipe retains its previous behavior. Development code may not match all released profiles, and a performance gain is not guaranteed.

### Update

```sh
emaint sync -r mmm-gentoo-overlay
emerge --ask --update app-editors/musicmapmaker-next-bin
```

Stable source versions follow normal package updates. For development builds, additionally accept `=app-editors/musicmapmaker-next-9999::mmm-gentoo-overlay **`, then fetch and rebuild explicitly:

```sh
emerge --ask --oneshot =app-editors/musicmapmaker-next-9999
```
