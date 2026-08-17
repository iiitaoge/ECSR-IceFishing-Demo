# 破冰捕鱼 Demo

这是参考图玩法的可玩纵向切片：港口出航，循海鸟寻找鱼群，用声呐确认位置，选择航线破冰前进，下网捕捞，返港后出售全部渔获，或收藏稀有鱼并自动卖出普通鱼。完成结算后可以开始下一航次；金币与收藏会持续保留。

## 运行

```powershell
rojo build demo.project.json --output build/fishing-demo.rbxlx
```

在 Roblox Studio 打开 `build/fishing-demo.rbxlx`，点击 **Play**。也可以直接：

```powershell
rojo serve demo.project.json
```

客户端会机械生成极地海面、浮冰、港口、海鸟、鱼群、声呐指示和渔船，不依赖外部模型或图片资源。

## 展示化内容

- 全屏开场卡用一屏讲清“找鱼 → 扫描 → 破冰捕捞 → 返港结算”的核心循环。
- 顶部目标轨道、资源 HUD、货舱/收藏面板和 7×7 实时小地图共同提示当前目标。
- 船体、港口、冰面、海鸟、鱼群和海面采用分层程序化造景，并加入航行尾迹、声呐脉冲和破冰碎片。
- 捕获时逐张揭示鱼种与稀有度，结算时显示金币或收藏奖励，镜头会随航次阶段平滑切换。
- `Platform/FishingPresentation.luau` 只把服务器发布的只读 Component 快照物化为画面；它不决定流程、价格、概率或结果。

当前版本是无需外部资产即可直接讲解与试玩的展示型纵向切片；美术仍是程序化占位风格，方便后续替换正式模型、材质、音效与特效。

## 操作

- `出航`：开始新航次，Rule 重新布置鱼群、海鸟线索与浮冰。
- `声呐扫描` / `Q`：显示鱼群精确方向与绿色扫描路径。
- `WASD`：向相邻海格航行；前方有冰时，同一 frame 会先破冰、再移动。
- `下网` / `F`：抵达鱼群后捕获三条确定性随机渔获。
- `返港` / `R`：装舱后切换为返航状态。
- `出售全部`：全部渔获换金币。
- `收藏稀有`：Rare/Epic 渔获转入永久收藏，普通鱼自动出售。

## ECSR 因果闭环

### `X_t`

- 根状态：`Voyage / Economy / Hold / Collection / RngState`。
- 船：`Vessel`。
- 海图：`SeaCell / Ice / FishSchool / Signal`。
- 渔获：`FishCatch / Trophy`。
- 外部按钮与按键只形成框架 `Observation`。

### `S_i`

`FishingRound → FishScan / ReturnIntent → IceBreak → VesselNavigation → VoyageArrival → NetFishing → CatchSettlement → ObservationCleanup`

每个 System 只获得只读 view 与 `emit`，不持有 World，也不保存会影响未来判断的模块级可变状态。

### `⊗`

- phase Rule 明确保证 `IceBreak` 之后才是 `Navigation`，随后才是 `Arrival`。
- Transaction claim 对 `voyage / vessel / ice / hold / economy / fish` 的竞争进行确定性仲裁。
- 稀有度只由 Component 中的 `RngState` 与纯 `CatalogRule` 决定。

### `Φ`

领域作用只物化为框架通用 Effect：`Insert / Remove / Spawn / Despawn / CollectionAdd / CollectionRemove`。Matter 世界仍只由依赖中的 `vendor/ECSR/src/Rules/StateUpdateRule.luau` 写入。

`demo/Platform` 是平台薄层：服务器把 RemoteEvent 变成 Observation，把只读 Component 快照发布给客户端；客户端只负责视觉与输入，不保存权威价格、流程、概率或胜负。

## 验证

`tests/FishingDemoConformance.server.luau` 会在 Studio 中自动跑完一次完整循环，并验证：

- 扫描显形；
- 破冰 → 移动 → 到达的 phase 因果顺序；
- 三条渔获与确定性稀有鱼；
- 返港、普通鱼收入、稀有鱼收藏；
- 第二航次保留金币/收藏。

完整验证入口仍是：

```powershell
./tests/Verify.ps1
```
