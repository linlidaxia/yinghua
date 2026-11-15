# 自查报告

版本 1.0.19 · 交付前自测记录。按「问题 → 影响 → 处理」记录，便于复查。

---

## 一、新增能力与修复（v1.0.19）

### 1. 搜索结果歌曲数量比服务器少（243 → 40）

- **现象**：在 Navidrome 网页搜「孙燕姿」有 243 个结果，App 里只显示 40 首。
- **原因**：`search3` 请求里 `songCount` 被硬编码为 `'40'`，也没有传 `songOffset`，超出部分根本没有请求。
- **处理**：
  - `MusicSource.search` 增加 `songOffset / songCount / albumCount / artistCount` 参数，Subsonic 源透传给 `search3`；
  - 搜索页首屏请求 100 首，若返回满页则自动继续拉取，直到 300 首或结果取完；
  - 仍有更多时在列表底部显示「加载更多歌曲」，点击按 `songOffset` 继续拉取；
  - 分页结果按歌曲 id 去重（防止服务端排序波动导致重复）；
  - 标题在未取完时显示「已显示 N 首」，取完后显示总数。
- **验证**：`flutter analyze` 0 error / 0 warning；单测 47 项全过；需真机搜「孙燕姿」确认显示 243 首。

---

## 二、历史记录

### v1.0.18

### 1. 投屏不遵守「跳过片头」、手机进度与音箱不一致、拖动不回传

- **现象**：DLNA 投屏总是从 0 秒开始，歌单里设置的片头跳过没有生效；手机进度条自己在走，和音箱实际播放位置对不上；在手机上拖动进度，音箱不跟着动。
- **原因**：
  - 投屏只把音频地址推给音箱，没有把片头偏移带过去；
  - 手机进度按「音箱设备时间轴」显示，没有加回服务端已跳过的片头，于是整体偏了一个片头的时长；
  - `seek` 只改本地播放器，没有映射到投屏设备。
- **处理**：
  - 转码格式（WMA / 需要服务端转码）把片头作为 `startOffset` 交给服务端，设备 0 秒 = 片头结束；其余格式推送后对音箱 `Seek`；
  - `CastTransport` 增加 `offset`，`DlnaController` 统一做「曲目时间 ↔ 设备时间」换算，手机显示位置 = 设备位置 + offset；
  - 手机拖动进度经 `PlaybackController.seek` → `CastTransport.seek` 回传到音箱，并设 2~3 秒保护期避免设备回传旧进度导致进度条回跳；
  - 从手机切到音箱时接着手机当前进度继续，不再从头播放；
  - 单曲循环 / 上一首回到开头时，回到的是「片头结束处」而不是 0 秒。
- **验证**：单测 47 项全过；真机投屏带片头跳过、进度一致、拖动回传待复验。

### 2. 歌词校准不应全局生效

- **现象**：调过一次歌词校准后，所有歌曲都跟着偏，切歌后新歌的歌词也是错的。
- **处理**：
  - 去掉全局 `lyricOffsetMs`，改为**按歌曲**（`songLyricOffsets`）和**按歌单**（`playlistLyricOffsets`）两级存储；
  - 生效顺序：当前歌曲 → 当前队列来源歌单 → 0；
  - 播放页 / 设置页默认只校准**当前歌曲**，并提示「换到别的歌曲不受影响」；
  - 歌单页新增校准入口，可切换「当前歌曲 / 整个歌单」，切换时显示已有继承值，并支持清除；
  - 范围仍为 ±2 分钟、0.5 秒一档。
- **验证**：单测覆盖按歌曲 / 按歌单持久化、上下限收敛与清除（47 个用例全过）。

---

## 三、更早的记录

### v1.0.17

### 1. 歌词校准范围太小（有声书偏差 2 分钟）

- **现象**：有声小说的字幕与声音最多相差 2 分钟，而校准只能 ±3 秒，根本对不上。
- **处理**：
  - `SettingsStore` 偏移上限由 ±3s 放宽到 **±120s**（`lyricOffsetLimitMs`），读取旧值时同样收敛；
  - 校准弹层改为**滑杆**（-2:00 ~ +2:00，0.5 秒一档）+ 数值显示 `+1:05.5` 格式，
    保留 `-5s / -0.5s / 重置 / +0.5s / +5s` 微调按钮；
  - 设置页概览同步显示新格式与「最大 ±2 分钟」说明。
- **验证**：单测覆盖格式化与上下限收敛（47 个用例全过）。

---

### v1.0.16

### 1. 投屏后切歌手机与音箱同时出声

- **现象**：第一次投屏正常（手机静音、音箱出声），手动切下一首时手机耳机和音箱同时响。
- **原因**：投屏只在连接时调用了一次 `playback.pause()`；之后切歌走的是普通本地播放流程，
  `_loadCurrent` 直接 `player.play()`，手机播放器又启动了；`DlnaController` 只是「顺便」把新歌推给音箱。
- **处理**：
  - `PlaybackController` 新增投屏模式（`CastTransport` / `attachCast` / `detachCast`）：
    进入投屏即 `player.setVolume(0)` + `player.stop()`，此后**凡是切歌、`jumpTo`、`playSongs`
    都不再加载 / 播放本地音频**，只更新队列与 UI；
  - `play` / `pause` / `togglePlay` / `seek` / `next` / `previous` 在投屏模式下全部转发给音箱
    （AVTransport Play / Pause / Seek），单曲循环与顺序播放末尾同样走远端；
  - 通知栏 / 锁屏 / 蓝牙按键的播放控制改为回调 `PlaybackController`，避免绕过投屏模式直接启动手机播放器；
  - 投屏期间新增每秒一次的 `GetPositionInfo` + `GetTransportInfo` 轮询：
    同步手机端进度条与歌词，整集播完（`STOPPED` 或停在片尾）自动推下一集；
    通知栏状态由 `AudioHandler.externalMode` 直接跟随音箱（显示「正在播放 / 暂停」）；
  - 断开投屏时恢复本地音量，并从当前进度接着在手机上播（音源重新载入失败也不会一直静音）；
  - 迷你播放条与播放页显示「投屏中」，避免误以为手机没声音是坏了。
- **验证**：单测覆盖 UPnP 时间解析与传输状态映射（45 个用例全过）；构建产物已验签。

---

### v1.0.15

### 1. DLNA 投屏

- **实现**：
  - `DlnaDiscovery`：UDP 组播发送 M-SEARCH（`MediaRenderer:1`），收 3 次响应，
    拉取设备描述 XML，解析 `friendlyName` / `modelName` / `AVTransport` / `RenderingControl` 控制地址；
  - `DlnaClient`：SOAP 1.1 封装 `SetAVTransportURI` / `Play` / `Pause` / `Stop` / `Seek` / `SetVolume`，
    并解析 `<s:Fault>` / `<UPnPError>`；
  - DIDL-Lite 元数据带标题、歌手、专辑、封面与 `protocolInfo`（按实际格式给 `audio/mpeg`、`audio/flac` 等）；
  - `DlnaController`：连接时先暂停本机播放（避免双声），投屏中切歌自动重推；
  - 入口：播放页操作区「投屏」+ 设置 → 服务 → DLNA 投屏。
- **界面**：搜索中 / 设备列表 / 已连接（含音量滑杆、重新推送、断开投屏）/ 错误提示。
- **限制**：手机与设备需在同一局域网；部分设备不支持音量控制；演示音频是本地资源无法投屏。
- **验证**：单测覆盖设备描述解析、无 AVTransport 降级、SOAP 转义、DIDL 元数据、Seek 时间格式与 MIME；
  `tool/dlna_scan.dart` 可在真实局域网里手动扫描并打印设备状态。

### 2. 品牌 LOGO（粉色主题）

- **最终标识**：`vinyl-mark.svg` —— 黑胶唱片 + 音符镂空，外圈唱片红细环、中心红标；
  镂空处真透明，粉底 / 白底 / 深色底都能自然透出背景；
- **落地**：Android 启动图标（5 档 mipmap + round）、自适应图标前景与粉色背景 `#F2538C`、
  启动页 Logo、应用内 `BrandMark` 统一使用 `assets/brand/logo.png`；
- **备选**：早期三套「鸟 + 莲花」方案（A 填充 / A-line 线描 / B 镂空）保留在 `brand/` 与
  `brand/README.md`，可随时替换；
- **说明**：`brand/README.md` 记录了色值、构成与导出文件。

### 3. 最近播放一直为空（修复）

- **现象**：播放过多首歌后，最近播放仍然没有任何记录。
- **根因**：`Song.listFromJson()` 在「没有历史数据」时返回 `const []`（不可变列表），
  `SettingsStore.recordPlayed()` 直接对它 `removeWhere / insert`，抛出
  `Cannot remove from an unmodifiable list`；异常被 `unawaited` 吞掉，界面无提示，
  内存与磁盘都没有写入。
- **处理**：
  - `listFromJson` 统一返回可变列表（空数据、异常分支都是 `<Song>[]`）；
  - `recordPlayed` 改为防御式拷贝后再增删；
  - 顺手加固了 `recentSearches` 的同类问题（从 prefs 读出后先拷贝再修改）。
- **验证**：新增 `test/recent_played_test.dart`，覆盖「写入 → 内存可见 → 重启后仍在」；
  全部 40 个用例通过。

### 4. 后台播放被系统清理

- **原因**：
  1. `androidStopForegroundOnPause: true` —— 暂停后前台服务降级，系统可随时回收，队列与播放状态丢失；
  2. 服务未声明 `android:stopWithTask="false"`，从最近任务划掉应用会连带停止服务；
  3. Android 13+ 没有主动申请 `POST_NOTIFICATIONS`，媒体通知不显示，前台服务缺少可见入口；
  4. 国产 ROM（MIUI / EMUI / ColorOS / OriginOS 等）默认清理后台，需要把应用加入电池优化白名单。
- **处理**：
  - `AudioServiceConfig` 改为 `androidStopForegroundOnPause: false`、`androidNotificationOngoing: false`
    （保持前台服务常驻，暂停时也不降级）；
  - 服务声明补 `android:stopWithTask="false"`；
  - 启动时自动申请通知权限（Android 13+）；
  - 新增「设置 → 播放 → 后台播放保护」：展示通知权限 / 电池优化状态，提供
    「允许后台运行」（`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`）、
    「自启动设置」（按厂商逐个尝试 MIUI / EMUI / ColorOS / OriginOS / OnePlus / 三星 的页面）、
    「打开系统电池优化设置」，并按机型给出操作路径；
  - 新增 `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` 权限。
- **说明**：系统级清理策略无法 100% 由 App 兜底，白名单 + 自启动是必要步骤；
  文档与设置页都给出了对应机型的操作路径。

### 5. 流量下播放歌单里的 WMA 仍然报「无法解码」

- **现象**：歌单「盗墓笔记-七星鲁王宫」里的 wma（约 95 MB/首）播放失败，
  提示「设备无法直接解码」。
- **排查（adb + 服务端抓包）**：
  - 服务端 `stream?format=mp3&maxBitRate=320` 返回 `200 / audio/mpeg`，首字节是 `ID3`，
    说明 Navidrome 转码正常；`format=raw` 才是 `audio/x-ms-wma`（ASF 头 `30 26 b2 75`）；
  - 手机上 `dumpsys media_session` 显示 `error=null`，但播放器停在 0 秒。
- **根因**：转码出来的是**实时流**（没有 `Content-Length`、不支持 Range），
  被「边听边存」的 `LockCachingAudioSource` 接管后缓存代理无法正常工作，
  `setAudioSource` 失败，界面落到「格式不支持」的兜底文案。
- **处理**：
  - 转码曲目（`AudioFormat.needsTranscode`）跳过缓存，直接 `AudioSource.uri` 播放；
  - `setAudioSource` 失败时打印 `[playback] setAudioSource failed: id/suffix/error`，便于定位；
  - 保留直连降级与格式提示。
- **验证**：真机（OnePlus / Android 16）播放《盗墓笔记1-七星鲁王宫05》，
  `media_session` 显示 `state=PLAYING, buffered=78s, error=null`，声音正常，可拖动进度。

### 6. 有声书歌单：跳过片头片尾

- **需求**：有声书 / 广播剧每集都有片头片尾，希望按歌单统一跳过。
- **实现**：
  - `SkipConfig`（intro / outro / enabled）按歌单 id 持久化到 `SettingsStore.playlistSkips`；
  - 歌单页曲目列表上方新增「跳过头尾」胶囊，设置页为底部弹层：
    片头秒数、片尾秒数、15/30/45/60s 快捷值、启用开关，保存后应用到该歌单全部曲目；
  - `PlaybackController` 记住当前队列来自哪个歌单（`playSongs(playlistId:)`），
    载入曲目后自动 `seek(片头)`，播放到「总时长 − 片尾」时自动切下一集；
  - 单曲循环模式下会在片尾处回到片头重播；用户往回拖动后会重新允许触发。
- **验证**：真机设置 45s 片头后播放第 2 集，`media_session` 位置从 45s 起跳
  （47.5s 时已播放约 2.5s），列表胶囊显示「跳过 45/0s」；
  `SkipConfig` 与持久化有单测覆盖（42 个用例全过）。

### 7. 部分曲目跳过片头失效

- **现象**：同一歌单里有的能跳过片头，有的仍从 0 开始。
- **原因**：需要服务端转码的格式（wma / ape 等）返回的是**实时转码流**，
  不支持 HTTP Range，客户端 `seek` 无法生效；能跳过的都是 mp3/flac 这类可直接 seek 的曲目。
- **处理**：
  - 新增 `MusicSource.resolveStream(startOffset:)`：转码曲目把片头秒数通过
    Navidrome 的 `timeOffset` 参数交给服务端，从片头结束处直接开始转码；
  - 非转码曲目仍用客户端 `seek`，并在进度回调里重试（最多 6 次），
    解决「刚缓冲时 seek 被忽略」的情况；
  - 播放页在服务端跳过头尾时显示「已跳过片头 01:10」小标签，避免进度从 0 开始造成误解。
- **验证**：`timeOffset` 实测有效（同一首 55.2 MB → 7.2 MB，从 20:00 开始转码）；
  `resolveStream` 单测确认只有转码曲目带 `timeOffset`（43 个用例全过）。

### 8. 详情页没有播放控制栏

- **需求**：在歌单里点播放后，希望当前页面就能看到迷你播放条。
- **原因**：迷你播放条只挂在 `HomeShell` 的 Tab 容器里，歌单 / 专辑 / 歌手等是独立路由。
- **处理**：新增 `MiniPlayerBar`（有播放内容时才占位），挂到歌单、专辑、歌手、文件夹页面的
  `bottomNavigationBar`；点击 / 上滑仍然打开完整播放页。
- **验证**：真机在「盗墓笔记-七星鲁王宫」点播放后，列表底部立即出现迷你播放条。

---

## 二、第七轮反馈（v1.0.6）
### 1. 验证 `api.lrc.cx` 封面接口

- **实测结果**（`tool/live_cover_check.dart`，展开模板 → 跟随 302 → 校验图片）：

  | 专辑 / 歌手 | 结果 |
  | --- | --- |
  | Super Star / S.H.E | 301 → 200 `image/jpeg` 194 KB（620×620） |
  | 叶惠美 / 周杰伦 | 301 → 200 `image/jpeg` 1.90 MB（3000×3000） |
  | 七里香 / 周杰伦 | 301 → 200 `image/jpeg` 1.60 MB（3000×3000） |

  接口支持只传 `album`，也支持 `album + artist`；中文会自动 URL 编码，`size` 参数会被忽略。
- **网页预览为什么看不到**：`api.lrc.cx` 的 **301 响应没有 `Access-Control-Allow-Origin`**
  （跳转目标 mzstatic 有，但浏览器要求每一跳都带），所以 Web 端被 CORS 拦截，
  App 会自动回退到服务器封面；**Android 端由 Dio 跟随跳转，可以正常显示**。
- **顺带优化**：
  - 自定义封面失败 → 回退服务器封面（上一轮已加）；
  - Apple 图床的大图统一降到 720（新增 `ArtworkUrl.shrink`），
    1.90 MB → 179 KB，列表页加载明显更快；降级地址失败时会自动回到原尺寸；
  - 模板占位符全为空（例如既没有 album 也没有 artist）时不再发请求，直接用服务器封面。
- **验证**：34 个单测通过（新增 3 个 ArtworkUrl 用例），`flutter analyze` 无告警。

---

## 三、第六轮反馈（v1.0.5）

### 1. Super Star 没有封面

- **排查**：从调试页面读取当前配置，发现 `cover_source = custom`，
  `cover_api_url = https://api.example.com/cover?album={album}&artist={artist}` ——
  这是界面里的**示例地址**，域名本身不提供图片，所以所有封面都取不到。
- **服务器数据核对**：
  - `search3` / `getAlbum` 里 Super Star 专辑**没有 `coverArt` 字段**；
  - 但 `getCoverArt?id=<专辑 id>` 返回 **200 image/webp（69 KB）**（Navidrome 的默认封面）。
- **处理**：
  1. 自定义封面失败时**自动回退服务器封面**（`SourceRegistry.serverCoverUrl` +
     `CoverImage` 的 fallback 链），配置错误不会再让整屏变占位图；
  2. 补齐封面模板的元数据：专辑卡 / 歌单卡 / 专辑页 / 歌单页 / 歌手 / 文件夹 /
     资料库列表现在都传 `{album}`、`{artist}`、`{title}`，按名称取封面的模板不再拿到空参数；
  3. 封面配置页新增**「测试接口」**：用示例专辑实际请求一次，显示 HTTP 状态、
     Content-Type、文件大小与缩略图，可直接判断接口是否可用；
  4. 保存时拦截 `api.example.com` 示例域名并提示替换。
- **验证**：调试页面中，`api.example.com` 请求失败后自动请求 `getCoverArt`（200），
  播放页与列表均显示服务器封面；Super Star 专辑本身没有内嵌封面，所以显示的是
  Navidrome 的默认封面图，需要在文件里补图或换用真实封面接口。

---

## 四、第五轮反馈（v1.0.4）

### 1. 歌词仍然乱码（已定位到根因）

- **现场证据**（浏览器调试 + 抓取接口原文）：
  `getLyricsBySongId` 返回的 `displayArtist` / `displayTitle` 是正常中文（周杰伦 / 七里香），
  但每行歌词的字节是连续的 `EF BF BD`（U+FFFD 替换字符），约 **74%** 的字符是 `�`。
- **结论**：Navidrome 把 **GBK 编码的 `.lrc` 文件按 UTF-8 读入**，无效字节被替换成 U+FFFD 后
  才写进数据库。替换字符不可逆，**任何客户端解码都无法还原**，这不是客户端字符集问题。
- **处理**：
  - 新增 `Lyric.isCorrupted`（U+FFFD ≥ 2 且占比 ≥ 12.5% 判定为损坏）；
  - `LibraryRepository` 识别到损坏歌词时返回 `LyricFetch(corrupted: true)`；
  - `PlaybackController` 将损坏歌词视为「没有歌词」，继续走「自定义接口 → LRCLIB」；
  - 在线 / 自定义歌词同样做损坏校验，避免把坏数据传给 UI；
  - 歌词页顶部标注来源（`· LRCLIB` / `· 自定义接口`）；若最终仍无歌词，会提示
    「服务器歌词编码异常（歌词文件不是 UTF-8）」。
- **验证**：在调试页面播放《三年二班》，日志显示
  `getLyricsBySongId` → 检测损坏 → `lrclib.net/api/get` 200 → 播放页歌词预览正确显示
  「眼睛你要擦亮 记住我的模样 表情不用太紧张 我是三年二班」。
- **服务端彻底修复**：把 `.lrc` 转成 UTF-8 后重新扫描（README「关于歌词」附命令）。

---

## 五、第四轮反馈（v1.0.3）

### 1. 歌单 / 搜索结果像「乱序」，没有排序入口

- **现象**：歌单里的歌曲按「碟号 + 音轨号」重排，跨专辑时看起来毫无规律；搜索也没有排序入口。
- **原因**：`SubsonicSource._songs()` 对**所有**接口结果都按碟号 / 音轨排序，歌单和搜索结果本应保留服务器顺序。
- **处理**：
  - `_songs(raw, sortTracks: false)`：歌单、搜索结果保持服务器原序，专辑内仍按碟号 / 音轨排序；
  - 新增 `SortOrder` 与 `sortSongs / sortAlbums / sortArtists`（`lib/core/utils/sorters.dart`）；
  - 歌单页与搜索页都加了「排序」胶囊入口，可选默认顺序、标题 A→Z / Z→A、歌手、专辑、时长、年份；
  - 排序只影响展示与播放顺序（播放全部 / 随机使用排序后的列表），不改服务器数据。
- **验证**：`06_playlist_sort.png` 显示歌单默认顺序 + 排序入口；排序单测覆盖升 / 降序与「不修改入参」。

### 2. 歌词经常乱码

- **原因**：HTTP 客户端用 `ResponseType.plain`，Dio 一律按 UTF-8 解码；GBK / GB18030
  服务端的 JSON 与歌词在这一步就变成了乱码。
- **处理**：
  - 新增 `CharsetSupport`：先取字节，再按 BOM → `Content-Type` charset → 严格 UTF-8 →
    GBK/GB18030 → Shift_JIS / EUC-JP / EUC-KR → Latin-1 的顺序解码；
  - `SubsonicClient` 全量改为 `ResponseType.bytes` + 统一解码，标题、歌手、专辑、歌词一起修复；
  - 自定义歌词接口同样按字节解码；
  - 增加 `repairText()`，修复「UTF-8 文本里套着 Latin-1 形式的 GBK 乱码」；
  - 对「只有 1 个高位字节」的文本直接按 Latin-1 处理，避免 Café / Björk 被 GBK 吃字。
- **验证**：8 个字符集单测（UTF-8 / BOM / GBK / UTF-16LE / Latin-1 / 二次乱码 / 不误伤中文与西文）全部通过。

### 3. 配置封面接口后，播放界面没换封面

- **原因**：`CoverImage` 订阅的是 `SourceRegistry`，而封面配置存在 `SettingsStore`；
  保存后 `SourceRegistry` 不通知，已经构建的封面不会重新取地址。
- **处理**：
  - `SourceRegistry` 监听 `SettingsStore`，封面来源 / 模板变化时 `notifyListeners()`，
    所有 `CoverImage`（首页、歌单、迷你播放条、播放页、队列、悬浮歌词）立即重建；
  - 封面 URL 变化后 `_CachedCover.didUpdateWidget` 会重新加载，磁盘缓存按 URL 哈希天然隔离；
  - 用本地图片接口做了端到端验证：播放页黑胶中心与背景模糊都换成了自定义接口的封面。
- **验证**：截图工具支持 `?cover=<url-template>`，已实测自定义接口封面正确显示在播放页。

---

## 六、第三轮反馈（v1.0.2）

### 1. 文件夹目录浏览一直加载不出来

- **现象**：进入「文件夹」后停在加载态，或服务端目录接口长时间无响应。
- **原因**：`getMusicDirectory` 没有超时兜底；部分服务端（或含大量文件的目录）响应很慢，
  界面就一直显示 Loading；另外个别服务端并未实现 `getMusicFolders` / `getMusicDirectory`。
- **处理**：
  - 目录请求增加 25 秒超时，超时后给出明确提示并保留「重试」；
  - 错误页新增「按歌手浏览」按钮，走 `getIndexesDirectory()`（内部用 `getArtists`），
    即使服务端目录接口不可用，也能进入「歌手 → 专辑 → 歌曲」；
  - `getMusicFolders` 为空或失败时，自动返回「按歌手浏览」这一虚拟目录，不再出现空白列表；
  - `getMusicFolders` / `getMusicDirectory` 分别加 15s / 20s 超时；
  - 演示资料库补齐了按歌手进入专辑的层级，截图与本地体验一致。
- **验证**：`05_folders.png` 显示演示库目录可正常展开；`flutter analyze` 无告警。

### 2. 封面 / 歌词接口不可配置

- **处理**：新增「设置 → 接口」两个配置页：
  - **封面接口**：服务器封面（getCoverArt）或自定义图片接口，支持
    `{id}` `{size}` `{album}` `{artist}` `{title}` 占位符，自动 URL 编码；
  - **歌词接口**：在线歌词（LRCLIB）开关 + 自定义歌词接口，支持
    `{id}` `{title}` `{artist}` `{album}` `{duration}`；返回 LRC 文本或 JSON
    （自动读取 `lrc` / `lyric` / `lyrics` / `text` / `content`，兼容 `data`、`result` 包裹）；
  - 歌词获取顺序固定为「服务器 → 自定义 → LRCLIB」，自定义接口即使关掉在线歌词也会生效；
  - 配置页做了即时校验：必须 http(s)、至少一个占位符，保存后立即生效。
- **验证**：`UrlTemplate` 单测覆盖编码、缺省占位符、非法 scheme；`AppPresets` / `UrlUtils` 单测保持通过。

### 3. 需要更多 App 主题

- **处理**：新增 6 套皮肤：莺花（默认）、网易云音乐、QQ 音乐、酷我音乐、酷狗音乐、千千静听。
  - `AppThemePreset` 只定义主色 / 按下态 / 品牌浅底 / 底色 tint；
  - `AppPalette` 由皮肤 + 亮暗模式派生，通过 `AppPaletteTheme`（ThemeExtension）挂到 ThemeData；
  - 全项目 75 处硬编码品牌色改为 `palette.brand` 等语义 token，切换后导航、按钮、进度条、
    悬浮歌词、Logo、迷你播放条一起变色；
  - 设置页提供带色块的皮肤选择弹层，立即生效并持久化。
- **验证**：`04_home_qqmusic.png` 为 QQ 音乐皮肤下的首页；切换皮肤后字阶、间距、圆角不变。

---

## 七、第二轮反馈（v1.0.1）

### 1. wma 音频提示「无法播放这首歌」

- **现象**：播放《盗墓笔记》wma 音轨时失败。ExoPlayer / AVPlayer 不支持 wma 容器，直连 `stream?format=raw` 必然解码失败。
- **处理**：新增 `AudioFormat` 能力表（`lib/core/utils/audio_format.dart`）。
  - 直连白名单：mp3 / flac / aac / m4a / mp4 / wav / ogg / opus / webm / mkv；
  - 其余（wma、ape、dsf、dff、tta、wv…）自动改用 `stream?format=mp3&maxBitRate=320`，由服务端转码；
  - 下载走同一策略，落盘扩展名同步改为 `.mp3`，避免「下载回来仍然播不了」；
  - 历史遗留的不可解码本地文件会被跳过，改走串流转码；
  - 兜底错误文案直接指出格式与服务端 ffmpeg 要求。
- **验证**：`AudioFormat` 单测覆盖直连 / 转码 / 空后缀 / 大小写；`flutter analyze` 无告警。

### 2. IPv6 服务器地址无法使用

- **现象**：`http://[2409:8a62:ae76:b120:211:32ff:fe7e:1de1]:4533` 输入后报错。
- **处理**：`UrlUtils` 重写地址规整：
  - 保留标准方括号写法；
  - 自动为「八段地址 + 端口」的裸 IPv6 补方括号（`2409:…:1de1:4533` → `http://[2409:…:1de1]:4533`）；
  - 校验端口范围 1–65535；
  - `hostOf` 输出带方括号的主机名，服务器列表不再出现无法阅读的地址；
  - 登录页提示与错误文案加入 IPv6 示例；
  - 连接失败时若为 IPv6 地址，额外提示检查手机 IPv6 网络与路由器端口放行。
- **验证**：单测覆盖括号写法、裸地址、IPv4、域名与 `/rest` 尾缀；`SubsonicClient` 生成的 stream / cover URL 均为合法 IPv6 URL。

### 3. 封面缺失 / 加载慢

- **处理**：
  - `Song.coverArtId` 缺失时回退到 `albumId`，专辑 / 歌手同理回退到自身 id（Subsonic 允许用专辑 id 取封面）；
  - 新增 `CoverCache`：按 URL 做 MD5 落盘，`dart:io` 下二次进入直接读文件，离线也能显示；
  - 缓存上限 1200 张，后台按修改时间清理，不阻塞首帧；
  - 失败自动回退直连，再回退程序化占位图，任何情况下不出现空白框。
- **验证**：`flutter analyze` 通过；网页预览仍走浏览器缓存分支，截图正常。

### 4. 歌词接口

- **处理**：在原有 OpenSubsonic `getLyricsBySongId` → 旧版 `getLyrics` 之后，新增 LRCLIB 在线补全：
  - `/api/get` 精确匹配（歌名 + 歌手 + 专辑 + 时长）；
  - 未命中转 `/api/search` 模糊搜索，优先取带时间轴的版本；
  - 结果做进程内缓存，切歌不重复请求；
  - 设置页可关闭（默认开启），关闭后完全离线。
- **验证**：解析复用已有 `LyricParser`（LRC / 纯文本），单测覆盖时间轴排序与纯文本。

### 5. 定时播放

- 功能原本已实现（15 / 30 / 60 分钟、播完当前歌曲），但入口只藏在播放页操作区。
- **处理**：设置页「播放」分组新增「定时停止」，实时显示剩余时间；播放页操作区保留同一入口，两处共用同一状态。

---

## 八、构建与环境问题

### 6. Release 构建卡在 `:shared_preferences_android:compileReleaseJavaWithJavac`

- **根因**：本机 `platforms/android-36` 安装不完整（缺 `android.jar`、`core-for-system-modules.jar` 等），
  AGP 的 `androidJdkImage` provider 取不到值，Gradle 在任务图阶段就抛
  `Cannot query the value of this provider because it has no value available.`。
  凡是 `compileSdk = flutter.compileSdkVersion`（36）的模块都会失败，与 shared_preferences 本身无关。
- **处理**：从 `dl.google.com` 重新下载 `platform-36_r02.zip` 覆盖安装；NDK 28.2.13676358 也改为手动解压安装。
- **验证**：全部模块 `androidJdkImage` 均可解析，`flutter build apk --release` 成功产出 60.2 MB APK。

### 7. Gradle / AGP 版本选择

- Flutter 3.50 模板要求 Gradle 9.5.0 + AGP 9.3.1 + Kotlin 2.4.20，且 Flutter 插件会检查最低版本。
- 降级 Gradle 8.13 + AGP 8.13.1 会被 Flutter 插件拒绝；最终保持模板默认版本组合，构建通过。
- `gradle.properties` 中的 `android.newDsl=false`、`android.builtInKotlin=false` 由 Flutter 迁移器自动写入，
  当前组合下可正常构建，暂不清理。

---

## 九、代码质量

### 8. 静态分析与测试

- `flutter analyze`：0 error、0 warning（59 条 info 均为 Flutter 3.50 `material.dart` 弃用提示）。
- `flutter test`：47 个用例全部通过（格式化、LRC 解析、音频格式策略、URL / IPv6、URL 模板、主题皮肤、字符集、排序、歌词损坏判定）。
- 修复过程中清理了多处 `Provider` 类型不匹配、错误的 `duration` API 用法、无效 `const`、错误相对导入等问题。

### 9. 播放健壮性

- 播放失败保留「直连降级」路径：缓存源失败会退回 `AudioSource.uri`，仍失败才提示错误。
- 不支持的本地格式不会盲目读文件，避免必然失败的播放。
- 队列增删、随机模式、播完自动下一首均重新计算索引，避免越界。

---

## 十、仍存在的边界

| 项 | 说明 |
| --- | --- |
| DLNA | 目前是入口 + 能力检测，未实现 SSDP 发现与 AVTransport 推流 |
| CarPlay / 快捷指令 | iOS 平台能力，Android 以媒体通知、锁屏与耳机按键覆盖同类场景 |
| 评论 | Subsonic 协议无评论接口，播放页以歌曲信息替代 |
| 网页预览 | 不支持离线下载、系统通知与悬浮窗歌词，仅用于演示与截图 |
| wma 转码 | 依赖 Navidrome 端安装 ffmpeg；未安装时无法转码，界面会给出明确指引 |
| 封面缓存 | 仅在 Android / iOS 落盘，网页版依赖浏览器缓存 |

---

## 十一、交付物核对

- [x] 可安装 APK：`dist/yinghua-1.0.17.apk`（66.2 MB，已签名 `CN=YingHua`）
- [x] 界面截图：首页 / 播放页 / 歌词页 / QQ 音乐主题 / 文件夹 / 歌单排序（390×844 @2x）
- [x] 设计规范：`docs/DESIGN_SPEC.md`
- [x] 使用与构建说明：`README.md`
- [x] 分层代码：`core / data / playback / ui`，音源通过 `MusicSource` 接口隔离，便于扩展 Jellyfin / Emby
- [x] 无付费 / 会员 / 支付 / 解锁相关代码与文案
