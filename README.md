# MusicMapMaker-Next Gentoo overlay

[中文](#中文) · [English](#english)

## 中文

提供两个包，任选其一：

- `app-editors/musicmapmaker-next-bin`：直接安装二进制版。
- `app-editors/musicmapmaker-next`：从最新 `main` 分支源码编译，属于可能领先于正式发布的开发版。

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
app-editors/musicmapmaker-next::mmm-gentoo-overlay **
```

源码安装：

```sh
emerge --ask app-editors/musicmapmaker-next::mmm-gentoo-overlay
```

如选择二进制包，将关键字配置中的包名改为 `musicmapmaker-next-bin`，关键字改为 `~amd64`，再运行：

```sh
emerge --ask app-editors/musicmapmaker-next-bin::mmm-gentoo-overlay
```

### 更新

```sh
emaint sync -r mmm-gentoo-overlay
emerge --ask --update app-editors/musicmapmaker-next-bin
```

源码版重新获取最新代码并编译：

```sh
emerge --ask --oneshot app-editors/musicmapmaker-next
```

## English

Choose one package:

- `app-editors/musicmapmaker-next-bin`: install the binary package.
- `app-editors/musicmapmaker-next`: compile the latest `main` branch source; this development build may be ahead of the latest release.

### Configure and install

With the Gentoo repository and `dev-vcs/git` already available, create `/etc/portage/repos.conf/mmm-gentoo-overlay.conf` as root using the `repos.conf` section shown above. This works without an eselect-repository public registration. Run `emaint sync -r mmm-gentoo-overlay`.

Add `app-editors/musicmapmaker-next::mmm-gentoo-overlay **` to `/etc/portage/package.accept_keywords/musicmapmaker-next`, then run:

```sh
emerge --ask app-editors/musicmapmaker-next::mmm-gentoo-overlay
```

For the binary package, use `musicmapmaker-next-bin` in both the keyword entry and the emerge command, and change its accepted keyword to `~amd64`.

### Update

```sh
emaint sync -r mmm-gentoo-overlay
emerge --ask --update app-editors/musicmapmaker-next-bin
```

To fetch the latest source and rebuild:

```sh
emerge --ask --oneshot app-editors/musicmapmaker-next
```
