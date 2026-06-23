# LoongArch64 构建指南

本文档记录了在 LoongArch64 (loong64) 架构上编译 Clash Verge Rev 的完整流程和所需补丁。

## 环境要求

- **操作系统**: Linux (LoongArch64)
- **Rust**: nightly 工具链 (需要 `stdarch_loongarch` 特性支持 LoongArch LSX SIMD 指令)
- **Node.js**: v24+
- **pnpm**: v11+
- **系统依赖**: libwebkit2gtk-4.1-dev, libgtk-3-dev, libayatana-appindicator3-dev 等

## 编译步骤

### 1. 安装 Rust 工具链

```bash
# 安装 stable Rust（prebuild 脚本需要）
rustup toolchain install 1.95.0

# 安装 nightly Rust（编译时需要 stdarch_loongarch 特性）
rustup toolchain install nightly

# 在项目目录中覆盖为 nightly
rustup override set nightly
```

### 2. 应用 float16 crate 补丁

`float16` v0.1.5 的 LoongArch64 SIMD 实现使用了 `core::arch::loongarch64` 内联函数，
需要 nightly 编译器且需显式声明 `#![feature(stdarch_loongarch)]`。

运行补丁脚本：
```bash
bash scripts/patch-float16-loong64.sh
```

### 3. 安装前端依赖

由于 Vite 8 的依赖 rolldown 和 @tauri-apps/cli 均无 loong64 的 native binding，
需要降级到 Vite 5（使用纯 JS 的 rollup 打包器）：

```bash
pnpm install
```

关键依赖版本变更：
- `vite`: 8.0.14 → 5.4.19
- `@vitejs/plugin-legacy`: 8.0.2 → 5.4.3
- `@vitejs/plugin-react`: 6.0.2 → 4.3.4
- `vite-plugin-svgr`: 5.2.0 → 4.3.0
- 新增 `esbuild` 0.21.5 override（0.21.3 在 loong64 上会崩溃）

### 4. 创建 sidecar 占位文件

Prebuild 脚本会尝试从 GitHub 下载 mihomo 核心的 loong64 预编译二进制，
但 Alpha 版本不存在该架构的发布包（HTTP 404）。需要先创建占位文件让 prebuild
通过 sidecar 检查，正常下载 geo 数据文件：

```bash
mkdir -p src-tauri/sidecar
cd src-tauri/sidecar
for name in verge-mihomo verge-mihomo-alpha \
            clash-verge-service clash-verge-service-install \
            clash-verge-service-uninstall; do
    touch "${name}-loongarch64-unknown-linux-gnu"
    chmod 755 "${name}-loongarch64-unknown-linux-gnu"
done
```

然后运行 prebuild 下载数据文件：

```bash
cd ../..
node scripts/prebuild.mjs
```

### 5. 获取 mihomo 核心二进制

Debian 包仓库地址：https://github.com/MetaCubeX/mihomo/releases

下载稳定版 deb 包（例如 `mihomo-linux-loong64-abi2-v1.19.27.deb`），
从中提取 mihomo 二进制替换占位文件：

```bash
# 解压 deb
mkdir -p /tmp/mihomo-extract
dpkg -x mihomo-linux-loong64-abi2-*.deb /tmp/mihomo-extract/

# 替换两个位置中的 sidecar 占位文件
cp /tmp/mihomo-extract/usr/bin/mihomo \
   src-tauri/sidecar/verge-mihomo-loongarch64-unknown-linux-gnu
cp /tmp/mihomo-extract/usr/bin/mihomo \
   target/release/verge-mihomo

# 清理
rm -rf /tmp/mihomo-extract
```

> **备选方案**：若发布页无 loong64 deb 包，可从源码编译：
> ```bash
> git clone https://github.com/MetaCubeX/mihomo.git
> cd mihomo && git checkout Alpha
> make linux-loong64
> # 二进制位于 bin/mihomo-linux-loong64
> ```

### 6. 编译前端

```bash
NODE_OPTIONS='--max-old-space-size=8192' pnpm run web:build
```

### 7. 编译 Rust 后端

由于 @tauri-apps/cli 没有 loong64 native binding，直接使用 cargo 编译：

```bash
cd src-tauri
cargo build --release
```

编译产物位于 `target/release/clash-verge`。

> **重要**：首次编译时 sidecar 仍为占位文件。完成步骤 5 后需要**重新执行一次
> `cargo build --release`**，将真正的 mihomo 二进制嵌入到最终包中。

### 8. 运行

```bash
target/release/clash-verge
```

## 已知问题

### 1. Native Binding 缺失

以下 npm 包没有 loongarch64 的预编译 native 模块：

| 包名 | 影响 | 解决方案 |
|------|------|----------|
| `@tauri-apps/cli` | 无法使用 `tauri build` | 手动执行前端构建 + cargo build |
| `@rolldown/binding` (Vite 8) | 无法打包前端 | 降级到 Vite 5 (rollup) |
| `@rolldown/binding-wasm32-wasi` | WASM 不支持 loong64 SIMD | 不可用 |

### 2. mihomo 核心

mihomo 核心可以从 MetaCubeX 的 release 页面获取 loong64 的 deb 包
（如 `mihomo-linux-loong64-abi2-v1.19.27.deb`），详见步骤 5。
若当前版本未发布 loong64 包，可从源码编译：
<https://github.com/MetaCubeX/mihomo>
> 注意：需要切换到 `Alpha` 分支，`main` 分支不是代理项目代码。

### 3. clash-verge-service

service IPC 程序也没有 loong64 预编译二进制。需要从源码编译：
<https://github.com/clash-verge-rev/clash-verge-service-ipc>

### 4. Tauri Bundle 不可用

由于 @tauri-apps/cli 无 loong64 native binding，无法使用 `tauri build` 生成
deb/rpm 包。手动构建的二进制文件可直接运行，但需要手动管理依赖和服务。

## 文件变更说明

| 文件 | 变更 |
|------|------|
| `package.json` | Vite 及插件版本降级、添加 esbuild |
| `pnpm-lock.yaml` | 依赖锁定文件更新 |
| `pnpm-workspace.yaml` | 添加 esbuild 版本 override |
| `scripts/patch-float16-loong64.sh` | float16 crate 补丁脚本（新增） |
