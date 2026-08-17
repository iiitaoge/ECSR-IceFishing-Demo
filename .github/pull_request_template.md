## 展示或玩法变化

说明玩家能看到或操作到的变化。展示改动请附截图或短视频。

## 状态演化

- **X_t：** 修改前读取或新增的 Component 状态
- **S_i：** System 读取与提出的 Contribution
- **⊗：** 组合、顺序、互斥与约束
- **Φ：** 生成 `X_t+1` 的 Effect

纯展示改动请写明“无权威状态变化”。

## 验证

- [ ] `./tests/Build.ps1`
- [ ] 涉及状态演化时运行 `./tests/Verify.ps1`
- [ ] `vendor/ECSR` 没有未提交修改
- [ ] 没有把 Roblox 平台依赖放入 Components、Systems 或 Rules
