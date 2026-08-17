# ECSR 捕鱼 Demo 协作宪法

本仓库实现破冰捕鱼应用，不重新实现或修改 ECSR 框架。`vendor/ECSR` 是固定版本的只读 Git submodule；任何框架演化必须在 `iiitaoge/ECSR` 独立提出。

## 唯一本体

运行时业务对象只有 `Components / Systems / Rules`；应用的 Roblox 边界适配位于同一 ECSR 应用目录下的 `Platform`：

- `demo/ECSR/Components` 保存会影响未来的全部捕鱼世界状态。
- `demo/ECSR/Systems` 只读取同一份只读快照并产生 Contribution。
- `demo/ECSR/Rules` 声明组合、顺序、优先级、冲突、约束与 Effect。
- `demo/ECSR/Platform` 只把 Roblox 输入/网络转换为 Observation，或把服务器发布的只读快照机械物化为 Roblox 画面。

Entity 只是数字 ID。Matter 是存储底座，Contribution 是瞬时作用值；两者都不是第四种业务本体。

```text
C_i     = S_i(X_t)
C*      = Rules.Compose({ C_i })
X_t+1   = Rules.Update(X_t, C*)
```

## 权限边界

- 不在业务层创建 Manager、Service、Controller、Store、EventBus 或 Scheduler。
- `demo/ECSR/Components / Systems / Rules` 不得依赖 Roblox 平台对象。
- System 不得持有 World 或影响未来判断的模块级可变状态。
- Matter 写入只允许发生在依赖的 `vendor/ECSR/src/Rules/StateUpdateRule.luau`。
- `demo/ECSR/Platform` 只形成 Observation 或机械物化服务器发布的只读快照；不得决定捕鱼流程、价格、概率或胜负。
- 不直接编辑 `vendor/ECSR`、`.gitmodules` 或 ECSR 子模块指针；依赖升级必须单独提交并由仓库所有者批准。

## 修改协议

实现需求前明确写出：

1. `X_t`：读取或新增哪些 Component 状态？
2. `S_i`：哪些 System 读取哪些状态并提出什么 Contribution？
3. `⊗`：Contribution 如何组合、排序、互斥或受约束？
4. `Φ`：组合结果通过哪些 Effect 生成什么 `X_t+1`？

提交前至少运行 `./tests/Build.ps1`；涉及状态演化时运行 `./tests/Verify.ps1`。
