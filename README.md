# NOVA Video Player (KidPlayer) 开发环境搭建与 APK 编译指南

> 适用场景：Windows 电脑 + WSL2 Ubuntu，项目代码与 Android SDK 放在 E 盘。
> 本文档基于 2026-09-27 实测通过的完整流程（含网络问题的解决方案）。
> 项目本地路径：`E:\KidPlayer`（WSL 内为 `/mnt/e/KidPlayer`）

---

## 一、项目概览

| 项 | 说明 |
|---|---|
| 项目 | NOVA Video Player（开源 Android 视频播放器，Archos 社区版 fork）|
| 地址 | https://github.com/nova-video-player/aos-AVP |
| 结构 | 主仓库 + 21 个 git 子模块 |
| 语言 | Java（UI）+ C/C++（FFmpeg/dav1d/opus 等原生引擎，NDK 构建）|
| 构建 | Gradle 9.5 + AGP 9.3.2，compileSdk 37，JDK 17 |
| 核心模块 | `Video/`（主 App UI）、`MediaLib/`（媒体库）、`FileCoreLibrary/`（文件管理）、`native/avos/`（多媒体引擎）|
| 分支 | 本仓库为个人 fork（`LeonLee666/KidPlayer`，`kid` 分支），子模块 gitlinks 已锁定 v6.4-lint 构建组合（commit `c804185`），`Video` 指向含儿童观看限制功能的 `kid` 分支 |

## 二、从零搭建（按顺序执行）

### 步骤 1：克隆主仓库与子模块（Windows 侧，Git Bash）

```bash
cd /e/
git clone -b kid https://github.com/LeonLee666/KidPlayer.git
cd KidPlayer
bash init-submodules.sh        # 逐个克隆21个子模块，网络失败自动重试
```

> 本 fork 的子模块 gitlinks 已锁定官方 CI v6.4-lint 构建组合并指定了分支，**克隆后无需再手动切 v6.4-lint 分支**（`No rule to make target 'native_libyuv'` 是旧版上游 aos-AVP 的问题）。

**注意 WSL 内 git 行尾配置**（2026-09-27 实测）：子模块如果在 WSL 内以 `core.autocrlf=true` 克隆，全部脚本会被转成 CRLF，`gradlew` 报 `/usr/bin/env: 'sh\r': No such file or directory`、make 报 `-f: command not found`。根治方法：

```bash
# 克隆子模块前，在 WSL 内把行尾策略改为 input（检出不做 CRLF 转换）
wsl.exe -d Ubuntu -- bash -c "git config --global core.autocrlf input"
```

若已经用 autocrlf=true 克隆过，修复方法见步骤 6。

### 步骤 2：WSL 内安装系统依赖

> wsl.exe 若被 WorkBuddy 安全策略拦截，需先在 安全中心 → 命令安全 → 程序黑名单 中移除 wsl.exe。

```bash
# Windows 侧执行（Git Bash），以 root 进入 WSL 避免交互式 sudo 密码卡死
wsl.exe -d Ubuntu -u root -- bash -c "apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openjdk-17-jdk-headless ninja-build meson nasm maven file wget curl unzip git pkg-config"
```

验证：`wsl.exe -d Ubuntu -- bash -c "java -version"` 应显示 17.x（若系统默认是 21，`build-apk.sh` 内已硬编码 `JAVA_HOME` 指向 17，无需切换默认），且 `which ninja meson nasm mvn` 全部有输出。

### 步骤 3：配置 git 镜像重写（dav1d 源在 WSL 内不可达）

```bash
wsl.exe -d Ubuntu -- bash -c "bash /mnt/e/KidPlayer/git-mirror-setup.sh"
```

该脚本把 `code.videolan.org/videolan/dav1d` 重写到 GitHub 官方镜像。**每次新建/重置 WSL 环境都要重跑一次。**

### 步骤 4：安装 Android SDK（E 盘内，Linux 版组件）

> `sdk-setup.sh` 脚本随仓库提供（2026-09-27 重建），若不存在可从本仓库恢复，或按内含组件清单手动 `sdkmanager` 安装。

```bash
# Windows 侧下载 cmdline-tools（放 E 盘，Linux 版！）
curl -L -o cmdtools.zip "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
cd /e/KidPlayer/android-sdk && mkdir -p cmdline-tools
unzip cmdtools.zip -d /tmp/ct && mv /tmp/ct/cmdline-tools cmdline-tools/latest && rm -rf /tmp/ct cmdtools.zip

# WSL 内安装组件（licenses → platform/build-tools/NDK/CMake）
wsl.exe -d Ubuntu -- bash -c "cd /mnt/e/KidPlayer && bash sdk-setup.sh"
```

需要装齐（sdk-setup.sh 已含）：`platform-tools`、`build-tools;36.0.0`、`platforms;android-36`、`platforms;android-37.0`（注意是 **37.0** 不是 37！）、`ndk;27.2.12479018`、`cmake;3.22.1`。全套装完约 3.4GB（NDK 单独占 2GB），下载安装约 20 分钟。

### 步骤 4.5：初始化 git 子模块（若步骤 1 在 Windows 侧未完成）

`Video/` 目录为空时 `build-apk.sh` 直接失败。在 WSL 内补跑：

```bash
wsl.exe -d Ubuntu -- bash -c "cd /mnt/e/KidPlayer && bash init-submodules.sh"
```

- 带自动重试（默认 5 轮），直到提示"全部 21 个子模块初始化完成"。
- 已知坑：`native/prebuilt/torrentd` 报 `Fetched ... did not contain 09f3733`（upstream 历史变更，默认拉取策略拿不到固定提交），手动修复：
  ```bash
  wsl.exe -d Ubuntu -- bash -c "cd /mnt/e/KidPlayer/native/prebuilt/torrentd && git fetch origin 09f3733cf236128be6267b3af972e848acbd5a7a && git checkout 09f3733cf236128be6267b3af972e848acbd5a7a"
  ```
- 验证：`wsl.exe -d Ubuntu -- bash -c "cd /mnt/e/KidPlayer && git submodule status"` 输出不应有 `-` 前缀行（`+` 前缀正常，表示检出与记录 SHA 不同，不影响构建）。

### 步骤 5：Gradle 与 Maven 镜像配置（应对 WSL 网络不稳）

WSL2 的 TCP 443 会被间歇性阻断（连 services.gradle.org、maven.aliyun.com 都可能超时），三件套必须配：

```bash
# 1) Gradle 离线包：Windows 侧下载（WSL 内下不动），wrapper 指向本地文件
curl -L -o /e/gradle-9.5.0-all.zip "https://mirrors.cloud.tencent.com/gradle/gradle-9.5.0-all.zip"
# Video/gradle/wrapper/gradle-wrapper.properties 中：
#   distributionUrl=file\:/mnt/e/gradle-9.5.0-all.zip

# 2) Maven 阿里云镜像 + 重试参数（部署到 WSL 的 ~/.gradle）
wsl.exe -d Ubuntu -- bash -c "mkdir -p ~/.gradle && cp /mnt/e/KidPlayer/init.gradle ~/.gradle/init.gradle && cp /mnt/e/KidPlayer/gradle-global.properties ~/.gradle/gradle.properties"

# 3) 缺失依赖补入 mavenLocal（阿里云仓库缺 sardine-android 和 trakt-java 的 jar）
wsl.exe -d Ubuntu -- bash -c "mkdir -p ~/.m2/repository/com/github/nova-video-player/sardine-android/v0.9-nova ~/.m2/repository/com/uwetrottmann/trakt5/trakt-java/6.21.0 && cp /mnt/e/KidPlayer/patch-maven/com/github/nova-video-player/sardine-android/v0.9-nova/* ~/.m2/repository/com/github/nova-video-player/sardine-android/v0.9-nova/ && cp /mnt/e/KidPlayer/patch-maven/trakt-java-6.21.0.* ~/.m2/repository/com/uwetrottmann/trakt5/trakt-java/6.21.0/"
```

> 注意：trakt-java 的 jar/pom 在 `patch-maven/` 根部，sardine 在 `patch-maven/com/.../v0.9-nova/`，复制时路径别搞混。

### 步骤 6：修复 CRLF 与 repo 布局（首次必做）

```bash
# 脚本 CRLF 修复（Windows 克隆的仓库行尾是 CRLF，WSL 内 make 会报 "-f: command not found"）
wsl.exe -d Ubuntu -- bash -c "cd /mnt/e/KidPlayer && find . -path ./.git -prune -o -type f \( -name '*.sh' -o -name '*.mk' -o -name 'Makefile' \) -print0 | xargs -0 -r sed -i 's/\r\$//'"

# AVP 目录（repo 工具布局需要，git clone 没有这个目录）
cd /e/KidPlayer && rm -f AVP && mkdir AVP && cp core.mk android-setup.sh android-setup-light.sh AVP/
```

**CRLF 的根治方法（2026-09-27 实测）**：如果子模块是在 WSL 内以 `core.autocrlf=true` 克隆的，仅对 `*.sh/*.mk/Makefile` 做 sed 修复不够（`gradlew` 也会挂：`/usr/bin/env: 'sh\r'`）。根治：

```bash
# 1) 改行尾策略并重新检出（主仓库 + 所有子模块一次性根治）
wsl.exe -d Ubuntu -- bash -c "git config --global core.autocrlf input && cd /mnt/e/KidPlayer && git config core.autocrlf input && git rm -q --cached -r . 2>/dev/null; git reset -q --hard && git submodule foreach --recursive 'git rm -q --cached -r . 2>/dev/null; git reset -q --hard'"

# 2) reset 后 wrapper 修改会被撤销！必须重新设置本地 Gradle 离线包指向
wsl.exe -d Ubuntu -- bash -c "sed -i 's|distributionUrl=.*|distributionUrl=file\\:/mnt/e/gradle-9.5.0-all.zip|' /mnt/e/KidPlayer/Video/gradle/wrapper/gradle-wrapper.properties"
```

### 步骤 7：编译 + 签名

```bash
wsl.exe -d Ubuntu -- bash -c "cd /mnt/e/KidPlayer && bash build-apk.sh release && bash sign-apk.sh"
```

- 产物：`E:\KidPlayer\org.courville.nova-6050001-6.5.1-universal-release-signed.apk`（约 81MB，universal 含 4 种 CPU 架构）
- 首次编译约 30 分钟（2026-09-27 实测 26 分钟，含原生库构建），增量编译约 9-10 分钟
- 签名密钥：`nova-release.keystore`（alias=`nova`，密码 `nova123456`）。**后续版本必须用同一密钥，否则无法覆盖安装**
- 签名时 apksigner 会对 META-INF 下多个未保护条目打 WARNING（app-metadata、SENTRY notices 等），属正常现象，不影响安装使用

---

## 三、常用操作速查

```bash
# 增量编译 + 签名（日常开发就用这一条）
wsl.exe -d Ubuntu -- bash -c "cd /mnt/e/KidPlayer && bash build-apk.sh release && bash sign-apk.sh"

# Debug 版
wsl.exe -d Ubuntu -- bash -c "cd /mnt/e/KidPlayer && bash build-apk.sh debug"

# 安装到已连接设备（WSL 内 adb 不可直达 Windows 的设备，建议 Windows 侧 adb install）
adb install -r E:\KidPlayer\org.courville.nova-6050001-6.5.1-universal-release-signed.apk

# 原生库完整重建（FFmpeg/dav1d 版本更新后）
wsl.exe -d Ubuntu -- bash -c "cd /mnt/e/KidPlayer && make clean_prebuilt"
```

## 四、问题排查

| 症状 | 原因与解决 |
|---|---|
| `No rule to make target 'native_libyuv'` | 上游 aos-AVP 的旧问题（子模块 SHA 不匹配）→ 本 fork 已锁定组合，无需处理；若出现则见步骤 1 |
| `fatal: unable to access ... videolan.org` | WSL 网络不通该域 → 跑 `git-mirror-setup.sh` |
| Gradle 下载 `Connection timed out` | WSL 443 被间歇阻断 → 用离线包 `E:\gradle-9.5.0-all.zip` + wrapper `file:/` 指向 |
| Maven 依赖解析失败/超时 | 同上 → 确认 `~/.gradle/init.gradle`（阿里云优先）和 `gradle.properties`（180s 超时+10次重试）已部署 |
| `Could not find sardine-android / trakt-java` | 阿里云仓库缺 jar → `patch-maven/` 补入 `~/.m2`（见步骤 5.3），并删 `~/.gradle/caches/modules-2/files-2.1/com.uwetrottmann.trakt5` 等缓存 |
| 脚本报 `-f: command not found`、`AVP: Not a directory` | CRLF 污染 / AVP 布局缺失 → 见步骤 6 |
| `/usr/bin/env: 'sh\r': No such file or directory` | `gradlew` 等脚本被 `core.autocrlf=true` 转成 CRLF → 见步骤 6 的根治方法（autocrlf=input + 重新检出） |
| `Fetched ... did not contain <commit>`（torrentd）| upstream 历史变更 → 按 SHA 手动 fetch + checkout，见步骤 4.5 |
| `Video/` 目录为空、编译直接失败 | 子模块未初始化 → 见步骤 4.5 |
| `attribute android:showSeekBarValue is private` | 偏好 XML 中该属性必须用 `app:` 命名空间 |
| sdkmanager 找不到 `platforms;android-37` | 版本号是 `android-37.0`（带小数点）|
| apt 安装卡住无输出 | sudo 在等密码 → 一律用 `wsl.exe -d Ubuntu -u root` 执行 |
| WSL 网络全断（curl 全 000）| WSL2 NAT 故障 → `wsl.exe --shutdown` 后重试（ICMP 通不代表 443 通）|

## 五、目录与资产索引

```
E:\KidPlayer\
├── android-sdk\              # Android SDK（Linux 版组件，E盘内，约 3.4GB）
├── patch-maven\              # 缺失依赖补丁（sardine-android、trakt-java）
├── Video\src\main\java\com\archos\mediacenter\video\player\kidslimit\
│                             # ★ 儿童观看限制功能源码（自研）
├── build-apk.sh              # 编译脚本（WSL 内运行）
├── sign-apk.sh               # 签名脚本（zipalign + apksigner）
├── init-submodules.sh        # 子模块初始化（带重试）
├── sdk-setup.sh              # SDK 组件安装脚本（2026-09-27 重建入库）
├── git-mirror-setup.sh       # git 镜像重写（新 WSL 环境必跑）
├── init.gradle               # Maven 镜像配置（部署到 WSL ~/.gradle）
├── gradle-global.properties  # Gradle 超时重试参数（部署到 WSL ~/.gradle）
├── nova-release.keystore     # 签名密钥（务必备份，勿外泄）
└── org.courville.nova-6050001-6.5.1-universal-release-signed.apk  # 最新产物

E:\gradle-9.5.0-all.zip       # Gradle 离线包（wrapper 引用，勿删）
```

## 六、儿童观看限制功能（自研）备忘

- 源码：`Video/src/main/java/com/archos/mediacenter/video/player/kidslimit/`（4 个类）
- 逻辑：每日 N 轮 × 每轮 M 分钟，到点强制休息 X 分钟（全屏遮罩倒计时），休息结束点屏幕恢复；轮次用完当日禁播，次日 00:00 懒重置
- 设置：设置页第一位"儿童观看限制"；启用需设家长 PIN（SHA-256），改参数/关闭/重置均需 PIN
- 计时口径：仅真实播放中的墙钟时间（暂停/缓冲不计）；elapsedRealtime 交叉校验防改系统时间
- 状态持久化：`nova_kids_limit_state.xml`（独立文件）；配置存默认 SharedPreferences
- 历史版本修复：① 休息结束未推进轮次导致倒计时死循环 ② tick 与停止回调双重计时 ③ SeekBar 改 ListPreference（TV 适配）
```
