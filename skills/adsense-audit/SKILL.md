---
name: adsense-audit
description: 站在 Google AdSense 审核员视角体检 Laravel 网站。检查 thin content / low value、法务五件套、SEO、favicon、日志时区、广告位合规等会导致拒审的问题。上线提审前 / 被拒后定位用。
---

# AdSense 审核体检 Skill

> **输出语言：本 skill 全程用中文回复**（叙述、报告、结论一律中文），代码 / 命令 / 文件路径保持原样。

站在 Google AdSense 审核员视角，对 Laravel 建站项目做提审前体检 / 被拒后定位。
**不重复 `laravel-themes`**：广告位实现、主题互斥、favicon 渲染、SEO sections 由它负责，本 skill 只做审核员视角的内容/合规判定，相关项一律引用 `[[laravel-themes]]`。

触发词：adsense、审核、提审、被拒、thin content、low value、法务、合规、policy

---

## 一、Skill 能力

| 命令 | 说明 |
|------|------|
| `/adsense-audit` | 全量体检，逐项出报告（默认） |
| `/adsense-audit fix` | 体检 + 致命缺项直接补（仅限法务页、favicon、robots/sitemap 这类无歧义缺失） |
| `/adsense-audit content` | 只查内容质量（thin / low value / 原创度） |
| `/adsense-audit legal` | 只查法务五件套 |

**产出形式**：逐项 `✅ 通过 / ⚠️ 警告 / ❌ 拒审风险`，每条带文件位置 + 修复建议。
默认只报告不改代码；`fix` 模式下仅对**无歧义的致命缺项**动手（法务页缺失、favicon 缺失、robots/sitemap 缺失），其余仍只报告——内容质量这类需要人判断的绝不自动生成。

---

## 二、AdSense 审核员视角：拒审三大主因

审核时按"如果我是审核员，这站为什么该拒"的逻辑走，主因排序：

### 2.1 Thin content（内容单薄）— 头号杀手

判定信号（命中任一即 ❌）：
- 总页面数 < 15~20 篇实质内容（采集/列表页不算）
- 单篇正文 < 300 词 / 600 汉字
- 大量页面正文几乎相同（模板填充、参数拼接出来的伪页面）
- 首页/分类页能进，但点进去全是空壳详情页（无数据的 detail 路由）

检查动作：
```bash
# 统计有实质内容的视图/路由数量，人工抽查正文长度
# 抽 5 个详情页路由，确认正文字数达标且各不相同
```
- [ ] 实质内容页 ≥ 15~20
- [ ] 抽查详情页正文字数达标、内容互不雷同
- [ ] 无"有路由无数据"的空壳页（`migrate:fresh --seed` 后逐路由验证，见 [[laravel-themes]] 验证清单 4.6）

### 2.2 Low value content（低价值）

- 内容是纯聚合/采集，无原创增量（审核员能一眼看出是搬运）
- 工具站只有功能没有说明性内容（计算器类必须配解释文案）
- AI 批量生成痕迹明显、无事实校验
- 关键词堆砌、为 SEO 而写的口水文

- [ ] 每类页面有"对用户的独特价值"能一句话说清
- [ ] 工具/计算类页面配有足量说明、用法、背景文案
- [ ] 无明显采集/AI 批量痕迹

### 2.3 缺导航与必要页面（站点不完整）

- [ ] 主导航能到达所有主要内容区
- [ ] 法务五件套齐全且页脚可达（见第三节）
- [ ] 无大量 404 / 占位页 / "Coming soon"
- [ ] favicon 存在（手写 SVG 即可，实现见 [[laravel-themes]]）

---

## 三、法务五件套（提审硬门槛）

缺任一即高概率拒审。逐项确认**页面存在 + 路由可达 + 页脚有链接 + 内容非空壳**：

| # | 页面 | 必须包含 |
|---|------|---------|
| 1 | Privacy Policy 隐私政策 | 数据收集说明、Cookie、**第三方广告商(Google)使用 Cookie**、DoubleClick DART cookie 说明、用户选择退出方式 |
| 2 | Terms of Service 服务条款 | 使用条款、免责、知识产权 |
| 3 | About 关于我们 | 站点真实定位、运营方信息（非空模板） |
| 4 | Contact 联系方式 | 真实可达的联系方式（邮箱/表单） |
| 5 | Cookie / Disclaimer 声明 | Cookie 使用说明（GDPR 区需 Cookie 同意横幅） |

**AdSense 专项**：隐私政策必须显式提到 Google 作为第三方广告供应商会使用 Cookie 投放个性化广告，并给出 `https://policies.google.com/technologies/ads` 退出链接——这是 AdSense 政策原文要求，审核员会查。

检查动作：
```bash
# 确认五个法务路由存在
grep -rnE "privacy|terms|about|contact|cookie|disclaimer" routes/
# 确认页脚有全部链接
grep -rniE "privacy|terms|about|contact" resources/views/themes/*/
```
- [ ] 五个页面路由均返回 200
- [ ] 内容非占位/非空（每页 ≥ 一屏实质文字）
- [ ] **每个已注册主题的页脚都有完整法务链接**（多主题易漏，逐主题查，见 [[laravel-themes]]）
- [ ] 隐私政策含 Google 第三方广告 Cookie 条款 + 退出链接

> `fix` 模式：法务页完全缺失时，按上表生成合规模板（中英按站点语言），内容需用户后续核对真实信息——生成后明确提示"占位信息待替换"。

---

## 四、SEO 与可索引性

`laravel-themes` 验证清单 4.4 已覆盖 title/meta/canonical/JSON-LD/noindex 的**实现**，本节只补**审核员/SEO 角度的增量检查**，不重复实现细节。

### 4.1 可索引性（提审硬底线）

- [ ] `robots.txt` 存在且未全站 `Disallow: /`
- [ ] `sitemap.xml` 存在并列出主要内容页
- [ ] 提审前**未**对全站挂 noindex（搜索结果页等局部 noindex 正常）
- [ ] canonical 指向自身规范 URL，无跨域错指
- [ ] 每页 title/description 唯一，非模板填充重复
- [ ] 无大面积重复内容（同内容多 URL 未做 canonical 归并）

```bash
# 抽查 title/description 是否雷同
grep -rn "meta name=\"description\"" resources/views/themes/*/ | sort | uniq -c
```

### 4.2 结构化数据 / Schema

JSON-LD 的渲染实现归 `[[laravel-themes]]`，本节查**类型完整性与正确性**：

- [ ] 文章/详情页有 `Article`（或 `BlogPosting`/`NewsArticle`）schema，含 headline/datePublished/author
- [ ] 列表/层级页有 `BreadcrumbList`（与页面真实面包屑一致）
- [ ] 站点级有 `Organization` 或 `WebSite`（含 name/url/logo）
- [ ] JSON-LD 语法合法、字段与页面可见内容一致（无"为 schema 而 schema"的虚标）

```bash
# 抽查各类 schema 是否存在
grep -rnoE '"@type"\s*:\s*"[A-Za-z]+"' resources/views/themes/*/ | sort | uniq -c
```

### 4.3 社交 / head 元标签

- [ ] `<meta charset>` 与 `<meta name="viewport">` 存在（移动端友好基础）
- [ ] Open Graph：`og:title` / `og:description` / `og:image` / `og:url` / `og:type` 齐全
- [ ] Twitter Card：`twitter:card`（summary_large_image）+ 配图
- [ ] `og:image` 为真实可访问的绝对 URL，非占位/404

```bash
grep -rniE 'og:(title|description|image|url|type)|twitter:card|name="viewport"' resources/views/themes/*/ | grep -c .
```

### 4.4 内链与 URL 结构

- [ ] URL 语义化（含关键词、无冗长 query 参数堆叠）
- [ ] 详情页之间有内链 / 相关推荐，无孤立页（仅 sitemap 可达不算）
- [ ] 面包屑导航存在且层级正确
- [ ] 多语言站点用 `hreflang` 标注各语言版本（单语言可跳过）

### 4.5 性能 / Core Web Vitals（Google 排名信号）

审核不卡性能，但 LCP/CLS/INP 影响后续排名与收益，提审阶段顺手查：

- [ ] 图片有 `width`/`height` 或 `aspect-ratio`（防 CLS 布局抖动）
- [ ] 首屏外图片 `loading="lazy"`
- [ ] 所有内容图片有 `alt`（无障碍 + 图片 SEO）
- [ ] 无明显阻塞渲染的大型同步脚本（广告代码异步加载）

```bash
# 抽查图片是否缺 alt / lazy
grep -rnoE '<img[^>]*>' resources/views/themes/*/ | grep -viE 'alt=' | head
```

> 提升自然流量是长期收益，**提审阶段优先保证"能被正确索引、无重复、无误 noindex"**；4.2–4.5 多为警告级（⚠️），缺失影响排名而非直接拒审，按此定级。

### 4.6 深度 SEO 交给外部专用 skill

本 skill 定位是 **AdSense 提审 gate**，SEO 只查"会不会拖累提审/收益"，**不做**关键词研究、排名追踪、backlinks、GEO/AEO 等增长侧工作。这些深度 SEO 已由 **`claude-seo` 插件**（已安装）覆盖，按需求直接调对应命令：

| 需求 | 命令 |
|------|------|
| 全站审计（含健康分、并行 specialist） | `/seo audit <url>` |
| 单页深度分析 | `/seo page <url>` |
| 技术 SEO（9 类：可爬/可索引/CWV/JS 渲染…） | `/seo technical <url>` |
| Schema 检测/校验/生成 | `/seo schema <url>` |
| 内容质量 / E-E-A-T | `/seo content <url>` |
| GEO / AI Overviews 引用度 | `/seo geo <url>` |
| 图片 SEO（alt/尺寸/WebP/CLS） | `/seo images <url>` |
| hreflang / 多语言 | `/seo hreflang <url>` |

> 体检中若发现 SEO 问题超出 4.1–4.5 范围（关键词/排名/外链/GEO/i18n 等增长侧），在报告里**提示用户改跑对应 `/seo …` 命令**，本 skill 不越界自行实现。
> 备选（未装）：轻量逐页 [aevans-eng/seo-skill](https://github.com/aevans-eng/seo-skill)、取证向 [Bhanunamikaze/Agentic-SEO-Skill](https://github.com/Bhanunamikaze/Agentic-SEO-Skill)。

---

## 五、广告代码与广告位（提审/投放阶段）

广告位**位置规范与实现**归 `[[laravel-themes]]`（banner1 导航下方、banner2 移动端第二屏、无广告不渲染 DOM）。本节只查 **AdSense 政策相关**的广告合规：

- [ ] 提审阶段广告代码可挂（ads.txt + 验证代码），但**审核中不强求广告填充**
- [ ] `ads.txt` 放在站点根 `public/ads.txt`，含正确 publisher ID
- [ ] 广告不与导航/按钮贴太近造成误点（政策禁止诱导点击）
- [ ] 单页广告不超内容（审核员看"内容为主、广告为辅"）
- [ ] 移动端 banner2 不在首屏堆叠（见 [[laravel-themes]] 4.3）
- [ ] 无"请点击广告"等诱导文案

```bash
ls public/ads.txt 2>/dev/null && cat public/ads.txt
```

---

## 六、后台与基础设施（nova-admin 基座）

后台用 `nbutl/nova-admin`，广告代码后台加载。审核相关基础项：

- [ ] 广告代码由后台配置项注入（global_head / banner slots），非硬编码
- [ ] 后台仅激活一个主题（主题互斥，见 [[laravel-themes]]）

### 日志规范（按天 + 时区）
- [ ] `config/logging.php` 默认 channel 为 `daily`（按天存储）
- [ ] `config/app.php` 时区 `timezone => 'Asia/Shanghai'`

```bash
grep -n "'default'" config/logging.php          # 期望 daily
grep -n "timezone" config/app.php               # 期望 Asia/Shanghai
grep -n "channel.*daily\|'daily'" config/logging.php
```
> `fix` 模式：时区/日志 channel 配错可直接改这两个配置值（无歧义）。

---

## 七、体检报告模板

全量体检输出按此结构，每条带文件位置：

```
## AdSense 提审体检报告 — {站点名} {日期}

### ❌ 拒审风险（必须修复）
- [thin content] 详情页仅 12 篇，正文均 < 200 字  → resources/views/themes/x/article.blade.php
- [法务] 隐私政策缺 Google 广告 Cookie 条款      → resources/views/.../privacy.blade.php

### ⚠️ 警告（建议修复）
- [SEO] 8 个页面 description 重复               → ...

### ✅ 通过
- 法务五件套路由齐全且 200
- 日志按天存储、时区 Asia/Shanghai
- favicon 存在

### 结论：暂不建议提审 / 可提审
```

---

## 八、使用方式

```
/adsense-audit          # 全量体检，出报告
/adsense-audit fix      # 体检并自动补法务页/favicon/robots 等无歧义缺项
/adsense-audit content  # 只查内容质量
/adsense-audit legal    # 只查法务五件套
```

体检完成后给出明确结论：**可提审 / 暂不建议提审 + 阻塞项清单**。
