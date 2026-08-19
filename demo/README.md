# 多鱼群破冰捕鱼 Demo

这是参考图玩法的可玩纵向切片：玩家从港口出发，在更大的 11×11 航区中使用右下角常驻雷达寻找多个鱼群，驾驶船沿海格航行并破冰。进入鱼群发现范围后，鱼群模型、稀有度与价值会显示出来，玩家按 E 获取；每个鱼群占用一个货舱格。货舱装满或航区没有剩余鱼群时返港出售，再用金币升级货舱并开始下一轮。

应用源码统一位于 `demo/ECSR`：`Components / Systems / Rules` 是平台无关的 ECSR 领域层，`Platform` 是同一应用边界内的 Roblox 适配层。`vendor/ECSR` 仍是只读框架依赖。

## 运行

```powershell
rojo build demo.project.json --output build/fishing-demo.rbxlx
```

在 Roblox Studio 打开 `build/fishing-demo.rbxlx`，点击 **Play**。也可以直接：

```powershell
rojo serve demo.project.json
```

客户端会程序化生成极地海面、浮冰、港口、渔船、多个鱼群和雷达指示，不依赖外部模型或图片资源。
玩家只操纵渔船；服务器关闭 Roblox 默认角色生成，场景中不会出现多余的人形角色。

## 展示化内容

- 全屏开场卡讲清“雷达寻找 → 发现 → 按 E 获取 → 货舱满载 → 回港出售 → 升级货舱”的核心循环。
- 顶部目标轨道、金币/燃料 HUD、0/7 起步的货舱面板、珍稀收藏和 11×11 实时小地图共同提示当前状态。
- 右下角雷达常驻显示最近未发现鱼群的方向、距离和信号强度；距离越近，信号越强。
- 已发现鱼群会显示模型、名称、稀有度和金币价值；按 E 后鱼群从场景消失并占用一个货舱格。
- `demo/ECSR/Platform/FishingPresentation.luau` 只把服务器发布的只读 Component 快照物化为画面；它不决定流程、价格、概率或结果。
- 破冰表现由独立特效层播放：冰面分裂后先被撞开，再倾斜下沉，并伴随飞溅碎冰、水滴和两圈水波；地图重绘不会提前截断动画。
- 每种鱼都有由 Roblox 基础几何组成的独立模型与配色；鱼群会在海面下巡游，获取时由网具吊入船尾，已捕获的鱼会显示在货舱中。

当前版本是无需外部资产即可直接讲解与试玩的展示型纵向切片；美术仍是程序化占位风格，方便后续替换正式模型、材质、音效与特效。雷达升级与稀有鱼概率提升保留为后续扩展点。

## 操作

- `出航`：开始新航次，重新生成多个可用鱼群、浮冰和随机渔获目录。
- `WASD`：向相邻海格航行；前方有冰时，同一 frame 会先破冰、再移动。
- `E`：在鱼群发现范围内获取一个鱼群；离得太远时无效并提示原因。
- `R`：货舱有渔获时封舱返港；货舱已满会自动进入返港提示状态。
- `出售货舱`：在港口把全部鱼群价值转换为金币并清空货舱。
- `收藏珍稀鱼`：保留 Rare/Epic 鱼群，普通鱼自动出售。
- `升级货舱`：仅能在港口且货舱清空时购买；初始容量为 7 格，金币不足时显示所需金币。
本轮已移除一键搜寻和 Q 键扫描；雷达自动寻找最近的未发现鱼群。

## ECSR 因果闭环

### `X_t`

- 根状态：`Voyage / Economy / CargoUpgrade / Hold / Collection / RngState`。
- 船：`Vessel`，其中 `capacity` 随 `CargoUpgrade` 持久化升级。
- 海图：`SeaCell / Ice / FishSchool / Signal`；`FishSchool.discovered` 控制发现前后的可见状态。
- 渔获：`FishCatch / Trophy`。
- 外部按钮与按键只形成框架 `Observation`。

### `S_i`

`{ FishingRound / ReturnIntent / IcebreakerUpgrade / CargoUpgrade } → IceBreak → VesselNavigation → VoyageArrival → FishDiscovery → FishSchoolCollection → CatchSettlement → ObservationCleanup`

每个 System 只获得只读 view 与 `emit`，不持有 World，也不保存会影响未来判断的模块级可变状态。

### `⊗`

- phase Rule 明确保证 `IceBreak` 之后才是 `Navigation`，随后是 `Arrival`、`Discovery` 和 `Collection`。
- Transaction claim 对 `voyage / vessel / ice / school / hold / economy / cargoUpgrade / fish` 的竞争进行确定性仲裁。
- 每轮所有可用鱼点都会生成独立 `FishSchool`；目录、稀有度与价值由 `RngState`、鱼点 tier 和纯 `CatalogRule` 决定。
- 破冰不再区分钻头等级或冰块等级；所有浮冰都遵循同一条“消耗燃料、撞开后通行”的规则。货舱升级价格与容量只由纯 `CargoUpgradeRule` 决定。

### `Φ`

领域作用只物化为框架通用 Effect：`Insert / Remove / Spawn / Despawn / CollectionAdd / CollectionRemove`。Matter 世界仍只由依赖中的 `vendor/ECSR/src/Rules/StateUpdateRule.luau` 写入。

`demo/ECSR/Platform` 是应用 ECSR 边界内的平台适配层：服务器把 RemoteEvent 变成 Observation，把只读 Component 快照发布给客户端；客户端只负责视觉与输入，不保存权威价格、流程、概率或胜负。

## 验证

`tests/FishingDemoConformance.server.luau` 会在 Studio 中自动验证：

- 多鱼群生成、未发现状态和远距离 E 无效；
- 进入发现范围后显示并获取鱼群，鱼群消失且每个只占一个货舱格；
- 货舱满载提示、返港出售、金币收入和货舱清空；
- 港口货舱升级、容量持久化和金币不足/非港口约束；
- 下一航次重新生成鱼群，以及破冰 → 移动 → 到达 → 发现的 phase 顺序。

完整验证入口仍是：

```powershell
./tests/Verify.ps1
```
