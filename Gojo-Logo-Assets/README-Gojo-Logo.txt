Gojo Logo Assets

SVG 是源文件，Gojo.icns 由 Scripts/make-icon.sh 从这些矢量图导出。

Files:
- gojo-logo.svg          主图标（完整版），用于 128px 及以上尺寸
- gojo-logo-small.svg    光学优化的小尺寸源，用于 16-64px 渲染
- gojo-logo-mono.svg     单色版本
- gojo-wordmark.svg      横向「图标 + Gojo」组合标
- gojo-wordmark-mono.svg 单色横向组合标

Brand colors:
- Ink:       #111318
- Surface:   #0D0F14 - #20242D
- Core blue: #1261C9 - #D9F3FF
- White:     #FFFFFF

Concept:
- G 门户 = Gojo，一条连续的几何路径
- 外环   = 领域 / 工作空间 (Domain / Workspace)
- 中心   = AI Agent
- 同心圆 = 领域展开 (Domain Expansion)

生成 icns:
  ./Scripts/make-icon.sh
16/32/64px 使用 gojo-logo-small.svg，128px 及以上使用 gojo-logo.svg。
