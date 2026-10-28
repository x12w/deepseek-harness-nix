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

## Linux 窗口外观

应用菜单使用上游 Harness 图标。包将 SVG 安装到 `hicolor/scalable/apps`，并在 `pixmaps` 中提供 PNG 后备图标；两者均命名为 `deepseek-harness`，与桌面入口一致。

主窗口复用上游 40px 的一体式标题栏，保留原生窗口控件以及本地化的“应用”“编辑”菜单。标题栏背景与按钮颜色跟随应用主题，Linux 同时使用现有的圆角工作区和侧栏布局。欢迎窗口使用一体式标题栏及不透明的深浅色背景。窗口阴影与外侧圆角由合成器负责。

标题栏复用 `preload-windows.ts` 及其上游 `data-windows-titlebar` 标记，使对话框和浮动面板沿用相同的避让区域。原生更新浮层也为标题栏保留空间。共享的 [Web 样式参考](../docs/web-styling.zh.md)和 `ui-theme` 仍负责视觉规范；此 fork 不另设主题或引入 UI 依赖。

## 维护

[`default.nix`](default.nix) 构建当前源码及固定的 pnpm 依赖。Electron 固定为 `node-addon-require-builtin` 要求的精确版本；命令行也因此使用 Electron 的 Node 模式。打包过程编译静态 Landlock 启动器，并将 Bash 可执行文件设为其 Nix store 路径。

[`primary-runtime.nix`](primary-runtime.nix) 读取上游[运行环境锁文件](../scripts/primary-runtime/lock.json)，准备 Python 文档处理环境。Node.js 和 pnpm 来自 Nix。应用将此运行环境复制到其可写的数据目录中。

合并上游修改后，核对包清单中的 pnpm 和 Electron 版本。若依赖发生变化，将 `pnpmDeps.hash` 设为空字符串，构建一次，再填入 Nix 报告的哈希值。更新使用方之前，运行 `nix flake check` 并启动桌面应用。构建过程检查命令行版本、Node 内部接口访问、PTY 执行及 Python 导入。图形界面启动需要单独进行冒烟检查。
