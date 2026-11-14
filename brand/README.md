# 莺花 LOGO

主标识：**黑胶唱片里裁出的四分音符**（`vinyl-mark.svg`）。
黑胶对应播放器本身，音符镂空露出底色，简洁、可单色、在 24px 下依然可辨认。

## 色值

| 用途 | 色值 |
| --- | --- |
| 唱片黑 | `#1A1216` |
| 唱片红 | `#C8323C` |
| 图标粉底 | `#F2538C`（渐变 `#FF9BC0 → #F2538C → #D22F68`） |
| 桃粉强调 | `#FF9CC0` |

## 构成

- 外圈唱片：`r=282`，墨黑填充，外沿一圈 `#C8323C` 细环；
- 纹路：三条同心圆以 2.6 描边做**镂空**，露出底色；
- 中心标签：`r=108` 的唱片红圆 + 内圈描边；
- 音符：四分音符形状从唱片中**镂空**，与纹路共用同一套 mask。

镂空区域是真正的透明，所以放在粉底、白底、深色底上都能自然透出背景。

## 文件

```
brand/
  vinyl-mark.svg                主标识源文件（可编辑）
  vinyl-mark.png                1024 透明底导出
  icon-vinyl-pink.png           图标：粉色渐变底 + 标识（已采用）
  icon-vinyl-white.png          图标：白底版本（备选）
  icon-vinyl-dark.png           图标：深色底版本（备选）
  icon-1024.png                 当前应用图标（= 粉色版）
  icon-foreground-1024.png      自适应图标前景层
  icon.html / icon-vinyl.html   导出用模板
```

## 已应用

- Android 启动图标：5 档 `mipmap-*/ic_launcher.png` 与 `ic_launcher_round.png`
- 自适应图标：粉色背景 `#F2538C` + 透明前景（`drawable-nodpi/ic_launcher_foreground.png`）
- 启动页：`drawable-nodpi/launch_logo.png`（白色背景上的标识）
- 应用内品牌标识：`assets/brand/logo.png`，`BrandMark` 组件统一使用

## 历史方案（保留可编辑源文件）

| 方案 | 文件 | 说明 |
| --- | --- | --- |
| A · 鸟上莲下 | `logo-a.svg` / `logo-a.png` | 莺鸟剪影 + 五瓣莲花，曾用作图标 |
| A-line · 线描莲花 | `logo-line.svg` / `logo-line.png` | 按参考素材做的粗线描莲花 + 实心鸟 |
| B · 莲花镂空鸟 | `logo-b.svg` / `logo-b.png` | 粉色莲花剪影，中央花瓣镂空鸟形 |

`preview.html` / `preview.png` 是这三套方案的白底 / 粉底 / 深色底对照图。
