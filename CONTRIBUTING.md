# 协作指南

## 开始

使用递归子模块克隆仓库：

```powershell
git clone --recurse-submodules https://github.com/iiitaoge/ECSR-IceFishing-Demo.git
```

从最新 `main` 创建功能分支，不直接推送 `main`。一个 Pull Request 只完成一个可命名、可验证的玩法或展示演化。

## 提交内容

Pull Request 需要说明：

- `X_t`：修改前的权威状态；
- `S_i`：System 读取与提出的 Contribution；
- `⊗`：作用的组合、顺序与冲突；
- `Φ`：产生下一状态的 Effect；
- 验证结果，以及展示变化的截图或短视频。

纯展示改动应明确说明没有新增权威业务状态。

## 验证

```powershell
./tests/Build.ps1
./tests/Verify.ps1
```

GitHub CI 会运行静态架构检查并构建可下载的 `.rbxlx`。完整 Studio 状态演化测试在本机运行。

## ECSR 依赖

不要在子模块内提交修改。确需升级框架时，新建只包含下列变化的独立 Pull Request：

```powershell
git -C vendor/ECSR fetch --tags
git -C vendor/ECSR checkout <approved-tag>
git submodule update --init --recursive
git add vendor/ECSR
```
