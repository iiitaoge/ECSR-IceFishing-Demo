# ECSR Ice Fishing Demo

[![ECSR Fishing CI](https://github.com/iiitaoge/ECSR-IceFishing-Demo/actions/workflows/ci.yml/badge.svg)](https://github.com/iiitaoge/ECSR-IceFishing-Demo/actions/workflows/ci.yml)

一个可展示、可协作的 Roblox 破冰捕鱼纵向切片：循海鸟与声呐定位鱼群，规划航线破冰，下网捕捞，返港出售或收藏稀有鱼。

本仓库只承载捕鱼应用。ECSR 框架以 Git submodule 固定在 [`v0.1.1`](https://github.com/iiitaoge/ECSR/tree/v0.1.1)，协作者不直接修改框架仓库。

## 获取项目

```powershell
git clone --recurse-submodules https://github.com/iiitaoge/ECSR-IceFishing-Demo.git
Set-Location ECSR-IceFishing-Demo
```

如果已经普通克隆：

```powershell
git submodule update --init --recursive
```

## 构建与试玩

```powershell
./tests/Build.ps1
```

脚本会获取固定版本的 Rojo，并生成 `build/fishing-demo.rbxlx`。在 Roblox Studio 中打开该文件并点击 **Play**。

完整本地验证需要已安装 Roblox Studio：

```powershell
./tests/Verify.ps1
```

详细玩法、操作与因果闭环见 [`demo/README.md`](demo/README.md)。应用 ECSR 代码统一位于 `demo/ECSR`，平台适配位于 `demo/ECSR/Platform`。

## 协作边界

- 捕鱼状态只能位于 `demo/ECSR/Components`。
- 局部作用只能由 `demo/ECSR/Systems` 提出 Contribution。
- 组合、顺序、冲突与状态演化只能由 `demo/ECSR/Rules` 声明。
- `demo/ECSR/Platform` 只负责把输入转换为 Observation，并把只读 Component 快照机械物化为 Roblox 画面。
- `demo/ECSR` 是本应用的 ECSR 边界；其中的 Platform 可以依赖 Roblox，但 Components、Systems、Rules 仍保持平台无关。
- 不要直接编辑 `vendor/ECSR`；需要升级时，只在独立 PR 中更新子模块指针。

开始开发前请完整阅读 [`AGENTS.md`](AGENTS.md) 和 [`CONTRIBUTING.md`](CONTRIBUTING.md)。

## License

[Apache License 2.0](LICENSE)。`vendor/ECSR/vendor/Matter` 保留其上游许可证。
