# 在 NixOS 上运行 DeepSeek Harness

[English](README.md) | 中文

使用 Nix flakes 从此 fork 构建 Linux x86_64 桌面应用。应用使用上游 Electron 桌面程序，Linux 桌面支持在此维护。

## 使用

在当前仓库中运行：

```sh
nix build
nix run
```

构建结果提供 `bin/deepseek-harness`、`bin/dsh`、应用菜单入口及 `dsh://` 协议处理程序。命令行支持 `dsh --help` 和 `dsh --version`。

NixOS 或 Home Manager flake 可以通过以下输入安装此包：

```nix
inputs.deepseek-harness = {
  url = "github:x12w/deepseek-harness-nix/codex/nix-packaging";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

在 `environment.systemPackages` 或 `home.packages` 中使用 `inputs.deepseek-harness.packages.x86_64-linux.default`。仅支持 x86_64 Linux。

在应用内配置凭据。Harness 数据默认位于 `~/.dsh`，设置 `DSH_HOME` 后则使用该目录。桌面配置位于此目录下的 `profiles/desktop`。Nix 不存储凭据，也不替换可变的用户设置。应用更新由 flake 锁文件管理。

## 维护

[`default.nix`](default.nix) 构建当前源码及固定的 pnpm 依赖。Electron 固定为 `node-addon-require-builtin` 要求的精确版本；命令行也因此使用 Electron 的 Node 模式。打包过程编译静态 Landlock 启动器，并将 Bash 可执行文件设为其 Nix store 路径。

[`primary-runtime.nix`](primary-runtime.nix) 读取上游[运行环境锁文件](../scripts/primary-runtime/lock.json)，准备 Python 文档处理环境。Node.js 和 pnpm 来自 Nix。应用将此运行环境复制到其可写的数据目录中。

合并上游修改后，核对包清单中的 pnpm 和 Electron 版本。若依赖发生变化，将 `pnpmDeps.hash` 设为空字符串，构建一次，再填入 Nix 报告的哈希值。更新使用方之前，运行 `nix flake check` 并启动桌面应用。构建过程检查命令行版本、Node 内部接口访问、PTY 执行及 Python 导入。图形界面启动需要单独进行冒烟检查。
