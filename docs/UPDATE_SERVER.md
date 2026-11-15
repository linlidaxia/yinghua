# 自建更新服务器（群晖 NAS）

GitHub Release 在国内经常只有几十 KB/s，66 MB 的安装包要下半小时以上，还容易中途断流。
把更新包放到自己的 NAS 上，App 按 IPv6 直连下载，通常几秒到几十秒就能完成，而且不依赖任何第三方服务。

App 支持两种更新源，可在 **设置 → 服务 → 更新源** 切换：

| 更新源 | 说明 |
| --- | --- |
| GitHub Release | 读取公开仓库的 `/releases/latest`，直连太慢时自动走加速镜像 |
| 自建清单 | 读取一个 JSON，按里面的 `apk` 地址下载，适合 NAS / 对象存储 |

两种源共用同一套弹窗、下载进度、SHA-256 校验与安装流程。

---

## 1. 需要准备什么

- 群晖 NAS 已能通过 IPv6 访问（Navidrome 能连上就说明网络已通）
- 一个 Web 服务：**Web Station**（推荐）或 Docker 里的 nginx
- 两个文件：
  - `yinghua-<版本>.apk`
  - `update.json`

## 2. 用 Web Station 提供文件（推荐）

1. **套件中心** 安装并打开 **Web Station**，启用默认站点。
2. **File Station** 打开 `web` 共享文件夹（没有就新建一个），在里面建 `yinghua` 目录：
   ```
   /web/yinghua/
   ```
3. 把 APK 与 `update.json` 放进这个目录。
4. **控制面板 → 安全性 → 防火墙** 放行 Web Station 使用的端口（默认 80 / 443，
   如果 80 被 DSM 占用，可在 Web Station → 网页服务 → 编辑里改成 8080 等）。
5. 手机浏览器打开验证：
   ```
   http://[2409:xxxx:xxxx::1]/yinghua/update.json
   ```
   IPv6 地址必须带方括号。能看到 JSON 就说明通了。

> 默认站点根目录就是 `web`，所以 `update.json` 的访问路径是 `/yinghua/update.json`。
> 如果用了「虚拟主机」，路径按虚拟主机的文档根目录计算。

### 用 Docker nginx 代替 Web Station

```bash
docker run -d --name yinghua-update \
  --restart unless-stopped \
  -p 8088:80 \
  -v /volume1/web/yinghua:/usr/share/nginx/html:ro \
  nginx:alpine
```

访问地址变成 `http://[IPv6]:8088/update.json`。群晖 Docker 默认使用 bridge 网络，
端口映射在 IPv6 下是否可用取决于 DSM 版本；不通时优先用 Web Station 的原生 nginx。

## 3. update.json 格式

```json
{
  "version": "1.0.22",
  "notes": "本次更新内容，App 会原样显示在更新弹窗里",
  "apk": "yinghua-1.0.22.apk",
  "size": 69643090,
  "sha256": "76fdb19c7035fea950e314ddc97586c01b1a12bb614b6e87c52c8bd8679cc5b7",
  "published_at": "2026-11-15T12:00:00Z"
}
```

- `version`：必须，语义化版本，例如 `1.0.22`
- `apk`：必须，可以是相对文件名（相对 `update.json` 所在目录），也可以是完整 URL
- `size` / `sha256`：强烈建议填写；大小不符或哈希不符时 App 会拒绝安装
- `notes`：可选，纯文本或 Markdown 都按纯文本显示
- `published_at`：可选
- 也兼容外层再包一层 `{"latest": { ... }}`

App 的判定规则：清单里的 `version` 比当前安装版本新才提示；相同或更旧时提示「已是最新版本」。

## 4. 发布新版本

构建完成后（`dist/yinghua-X.Y.Z.apk` 已存在）：

```powershell
# 只生成到 dist/nas/，再用 File Station 拖到 NAS
pwsh tool/publish_nas.ps1 1.0.21

# 直接写入已映射的共享目录
pwsh tool/publish_nas.ps1 1.0.21 -Dest '\\DiskStation\web\yinghua'

# 或通过 SSH 推送（NAS 需开启 SSH）
pwsh tool/publish_nas.ps1 1.0.21 -SshTarget 'admin@diskstation.local' -RemoteDir '/volume1/web/yinghua'
```

脚本会：

1. 从 `CHANGELOG.md` 读取 `## vX.Y.Z` 章节作为 `notes`
2. 计算大小与 SHA-256
3. 生成无 BOM 的 `update.json`
4. 复制 / 上传 APK 与清单

> 建议保留旧版本的 APK 一段时间，方便回滚；App 只读 `update.json`，旧文件不影响检测。

## 5. 在 App 里启用

1. 打开 **设置 → 服务 → 更新源**
2. 选择「自建清单（NAS / 对象存储）」
3. 填入：
   ```
   http://[2409:xxxx:xxxx::1]:8080/yinghua/update.json
   ```
4. 点「测试清单」，应显示「成功 · 最新版本 X.Y.Z」
5. 保存

之后启动检测、设置页「检查更新」都会走 NAS；下载时不再经过 GitHub。

## 6. 注意事项

- **必须能匿名访问**：清单和 APK 不要开 DSM 登录鉴权，App 不带账号密码请求。
  Web Station 的静态文件默认就是匿名的。
- **APK 必须用同一套签名**：`android/app/yinghua-release.jks`；换签名会导致覆盖安装失败。
- **IPv6 地址会变**：运营商前缀变化后要在 App 里改地址，建议给 NAS 配 DDNS 域名，
  清单地址用域名（`http://nas.example.com:8080/yinghua/update.json`）。
- **HTTP 明文可以接受**：App 下载后会校验 SHA-256，内容被篡改会被拒绝；
  在意隐私可以给 Web Station 配 HTTPS 证书。
- **别把整个 NAS 目录暴露出去**：只放行 `yinghua` 这一个子目录。
- **更新源不可用不会影响使用**：检测失败只在手动检测时提示，自动检测静默跳过。

## 7. 其他可选方案

| 方案 | 优点 | 代价 |
| --- | --- | --- |
| 群晖 NAS + 清单（本文） | 免费、速度最快、完全自控 | 需要 NAS 在线，IPv6 地址要维护 |
| 阿里云 OSS / 腾讯云 COS + CDN | 全国速度稳定，HTTPS 现成 | 按流量计费，需备案域名（走 CDN 时） |
| GitHub Release + 加速镜像 | 已有，零维护 | 镜像稳定性不可控，速度看运气 |
| 蒲公英 / fir.im 等分发平台 | 上传即用，有二维码 | 需要注册，免费额度有限，隐私性一般 |

如果 NAS 长期在线，推荐「NAS 主 + GitHub 兜底」：日常走 NAS，出差或 NAS 维护时临时切回 GitHub。
