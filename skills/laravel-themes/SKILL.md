---
name: laravel-themes
description: Laravel 多主题/多皮肤系统开发 skill。搭建主题切换基础设施、开发新主题、验证主题质量。适用于站群多套前台皮肤的 Laravel 项目。
---

# Laravel 多主题系统开发 Skill

> **输出语言：本 skill 全程用中文回复**（叙述、报告、结论一律中文），代码 / 命令 / 文件路径保持原样。

为 Laravel 项目搭建和开发多主题（多皮肤）前台系统。适用场景：站群需要多套视觉差异化的前台、同一数据多套呈现方式。

触发词：新主题、主题系统、多皮肤、换肤、theme、skin

---

## 一、Skill 能力

| 命令 | 说明 |
|------|------|
| `/laravel-themes init` | 在当前项目搭建多主题基础设施（Model、helper、migration、目录结构） |
| `/laravel-themes new <slug>` | 开发一个新主题（从选型到验证的完整流程） |
| `/laravel-themes verify <slug>` | 对已有主题运行质量验证清单 |
| `/laravel-themes list` | 列出当前项目所有已注册主题及状态 |

无参数调用时，自动检测项目状态：无主题系统则引导 init，有则提供 new/verify 选择。

---

## 二、核心架构（init 时搭建）

### 2.1 主题解析函数 `theme_view()`

控制器统一使用 `view(theme_view('page_name'))` 渲染，解析流程：
1. 读取激活主题 slug（缓存 1h，Model saved/deleted 事件自动清缓存）
2. 拼视图名 `themes.{slug}.{page_name}`
3. 激活主题缺该视图 → 回退默认主题，避免白屏

```php
// app/Support/helpers.php — composer autoload.files 注册
function theme_view(string $view): string
{
    $slug = Theme::activeSlug();
    $name = "themes.{$slug}.{$view}";
    if ($slug !== Theme::DEFAULT_SLUG && !view()->exists($name)) {
        return 'themes.' . Theme::DEFAULT_SLUG . ".{$view}";
    }
    return $name;
}
```

**关键**：同时在 `bootstrap/app.php` 顶部 `require_once` 此文件作为兜底——部署脚本按 `composer.lock` 哈希判断是否重建 autoload，`autoload.files` 段变更不改 lock hash，会导致 `autoload_files.php` 过期、函数未定义。`function_exists` 守卫保证双重加载安全。

### 2.2 Theme Model

```php
class Theme extends Model
{
    const DEFAULT_SLUG = 'your-default-theme';

    protected static function booted(): void
    {
        static::saved(fn () => Cache::forget('active_theme'));
        static::deleted(fn () => Cache::forget('active_theme'));
    }

    public static function activeSlug(): string
    {
        try {
            return static::getActive()?->slug ?? self::DEFAULT_SLUG;
        } catch (\Throwable) {
            return self::DEFAULT_SLUG; // themes 表不存在时兜底
        }
    }

    public function activate(): void
    {
        static::where('id', '!=', $this->id)->update(['is_active' => false]);
        $this->update(['is_active' => true]); // saved 事件自动清缓存
    }
}
```

### 2.3 目录规范

```
resources/views/themes/
├── {default-slug}/          # 默认主题（回退兜底）
│   ├── layout.blade.php     # 全局骨架
│   ├── partials/            # 主题私有部件
│   └── {pages}.blade.php    # 业务页面
├── {theme-2}/
│   ├── layout.blade.php
│   ├── partials/
│   └── {pages}.blade.php
resources/css/themes/
├── {default-slug}.css        # 可选，默认主题可用 app.css
├── {theme-2}.css             # 每主题独立 CSS 入口
resources/views/components/   # 全局共享组件（如广告位），不按主题拆
public/themes/{slug}/         # 主题静态资源（图片、favicon）
```

### 2.4 CSS 构建隔离（Tailwind v4 + Vite）

每主题独立 CSS 入口注册进 `vite.config.js`，`@source` 只扫本主题视图 + 共享组件目录，避免多主题 class 并集膨胀：

```css
/* resources/css/themes/{slug}.css */
@import "tailwindcss";
@source "../../views/themes/{slug}/**/*.blade.php";
@source "../../views/components/**/*.blade.php";

@theme {
  --color-primary: #your-color;
  /* ... */
}
```

Layout 中引用本主题 CSS：`@vite(['resources/css/themes/{slug}.css', 'resources/js/app.js'])`

---

## 三、新主题开发流程（`/laravel-themes new`）

### 核心原则

1. **新主题 = 同类型的"新网站"，不是换皮**——每个主题必须做到全局骨架不同、页面信息架构不同、文案体系全新、组件形态不同。不变的只有：路由、控制器、数据契约。
2. **视觉基调先对齐**——用 AskUserQuestion 带 ASCII 版式预览（底色基调、导航形态、首屏构成、强调色）让用户选方向。纯文字描述选型用户理解偏差大，渲染出来才发现不符预期。
3. **记录已占用设计语言**——维护一份各主题的骨架/色板/字体/签名组件占用表，新主题立项时参照避让。
4. **移动端优先**——每个主题开发时先以 375px 宽度布局，桌面端扩展。导航必须实现汉堡菜单（hamburger menu），JS 控制展开/收起，touch target ≥ 44px，菜单层 z-index 不被压。
5. **详情页要"列表点了就进"，且机器可自动点击遍历**——凡是列表/赛程/积分榜/对阵图里出现的实体名（球队、球员、文章），默认就该是进对应详情页的链接，像资讯站那样整项可点；不要把详情入口只埋在导航深处某个列表页。详情页常承载 banner 广告与 SEO 落地，入口可达性直接决定 PV。做法：让渲染实体名的 partial/组件**默认从 `$model->slug` 自动建链**（根节点 `<span>`→`<a>` + 主题色 hover），嵌套在已有 `<a>` 内的场景传 `link=false` 关闭，避免非法嵌套 `<a>`。
   **关键：首页进详情页的入口必须是真实 `<a href>`，机器（爬虫/自动点击器）能直接发现并点击**——不要用纯 JS `onclick`/`div` 跳转、不要把链接藏在需要 hover 才出现的层、广告位插入后不得遮挡或抢占卡片的可点击区域（广告 `z-index` 不压在卡片链接之上）。判据：禁用 JS、纯解析 HTML 时，首页到详情页的链接依然存在且可遍历。
   **整块（整行/整卡）可点：让容器元素本身就是 `<a>`，不要用 stretched-link 覆盖层。** 赛程行、卡片这类"点哪都进详情"的块，把最外层容器直接写成 `<a href>`（`<div>`/`<article>` → `<a class="block ...">`），内部所有内容（队名、比分、场馆、组名）作为它的子 `<span>`/`<div>`，天然整块可点、点击冒泡到 `<a>`、无死角。**避免** `<article class="relative">` 里塞一个 `absolute inset-0` 的空 `<a>` 覆盖层——覆盖层方案会因内部 `relative z-*` 子元素、后渲染的场馆行等盖在链接之上，留下点不进的死区（真实翻车：venue 行点击落空）。一行两队时约定整块进主队详情（`homeTeam`），客队名作 `<span>` 不再单独建链，避免中间产生点击死区与嵌套 `<a>`。
6. **详情页必须有面包屑，且广告在面包屑之下**——所有详情页（文章/球队/球员）顶部紧跟导航放面包屑（`Home › 列表 › 当前页`），帮助定位与回退、利于 SEO。**顺序固定：导航 → 面包屑 → banner 广告 → 标题/正文**。广告绝不能插在导航和面包屑之间——那样会把面包屑和它所属的内容割裂，用户先看到的是与页面无关的广告（反例见下图式布局：导航→广告→面包屑→标题，是错的）。面包屑用 `<nav aria-label="breadcrumb">` + JSON-LD `BreadcrumbList` 结构化数据。
7. **首页不要 hero 区域**——首页第一屏直接进入实际内容（列表/赛程/资讯卡片等），不做大幅 hero/横幅/首屏大图。理由：hero 占满首屏却无可点链接，把真正能进详情页、能承载广告的内容挤到折叠线以下，拉低首屏 PV 与广告可见性。首页顶部顺序应为 `导航 → banner1 广告 → 实际内容`，让用户和爬虫一进站就看到可点击的详情入口。

8. **移动端首屏隐藏"占屏不可点"的装饰/统计块**——大 section 标题（如 "MATCHDAY BOARD"、"FULL SCHEDULE"）和数字统计带（如 72 场/48 队/12 组）在桌面是有效信息，但在移动端把真正可点的列表内容挤下折叠线，且它们本身不可点、对首屏 PV 无贡献。做法：给这些块加 `hidden md:block`（flex/grid 容器用 `hidden md:flex`/`hidden md:grid`），移动端不渲染、桌面端保留。目标：移动端首屏顺序为 `导航 → banner1 → 日期 → 列表行`，像资讯站一样一落手就点到内容。**列表行本身在移动端反而要加高**（如 `py-4`，桌面 `sm:py-3.5`），把 touch target 做大更好点。判据：375px 下折叠线以内出现的应是可点列表行，而非纯装饰标题或数据带。
9. **首页采用“资讯流/目录流”可点击密度，不采用营销页首屏**——参考 `https://evcar.termo.onl/index.html` 的有效部分：顶部广告后立即进入 Hot/Recent/Category 列表，图片、标题、列表行、侧栏热门项都能进入详情或分类；用户和机器不需要先越过大段品牌说明、搜索表单、统计带、装饰横幅。迁移到 Laravel 主题时要做成服务端渲染的真实 `<a href>`，不要照搬纯 JS 挂载；首屏优先出现“多条详情入口”，不是单个搜索框。推荐首页结构：`导航 → banner1 → 热门详情卡/列表（整卡 <a>）→ banner2 → 分组目录/最新列表 → 侧栏/补充入口`。图片和标题可以各自是链接，整卡可点时外层直接用 `<a>`，不要嵌套 `<a>`；分类标签如果需要单独链接，则不要放在整卡 `<a>` 内，改为卡片外的辅助链接或传 `link=false`。

   **该站实测拆解（可直接套用的三个套路）：**
   - **统一卡片解剖，一个 partial 三种尺寸变体**。全站每个区块（头条大卡、最新、分类区、侧栏热门）都是同一结构，只换尺寸类（`post-thumb` / `post-sm` / `post-widget`）：
     ```
     .post
     ├── <a class="post-img" href="详情页"><img loading="lazy"></a>   ← 图片整块可点
     └── .post-body
         ├── .post-category → <a href="分类页">              ← 分类独立链接，与详情链接平级不嵌套
         ├── <h3 class="post-title"><a href="详情页">        ← 标题可点，与图片同一目标
         └── ul.post-meta（作者/日期，不建链）
     ```
     图片和标题各自是 `<a>` 指向同一详情页——每张卡给机器两个入口、给用户"点图或点字都进"的体验，同时分类链接不必被排除在外（对比整卡 `<a>` 方案的取舍：需要分类可点时选这套，不需要时选整卡 `<a>`）。Laravel 落地：一个 `post-card.blade.php` 接 `size` 参数出三种变体，别每个区块写一套卡片。
   - **首屏 = 1 大 + 2 小头条区**。8/4 分栏：左侧一张大图卡（`title-lg`），右侧纵排两张小卡——导航+广告之后立刻 3 个详情入口，没有任何 hero/口号。
   - **入口数量堆到 20+**。首页纵向堆区块：头条 3 + 最新 4（两列）+ 每个分类区 3（三列）× N + 侧栏热门 8 + Load More；每卡 2 链接，首页详情入口轻松过 20。验证时可用 4.1 的 `curl | grep -oc` 直接数：首页详情链接数少于 15 就该怀疑可点密度不够。

10. **首页把"跑量目标"内容排在"辅助数据块"之前——全端换序，而非隐藏**——当主题首页同时有跑量目标（文章列表）和辅助数据块（车辆规格表 / 参数榜 / 遥测条）时，把文章列表排在辅助块**之前**。哪怕辅助块本身是可点的 `<a>`（不算"占屏不可点装饰"，不适用原则 #8 的 `hidden md:*`），排在文章前也会在移动端把文章挤下折叠线，直接压低文章 PV——用户点辅助块进的是低价值页，不是要跑量的文章详情。做法优先级：
    - **首选：直接调 DOM 顺序**（文章 section 挪到辅助 section 之前），桌面/移动一致，无 CSS hack。辅助块只是下沉，入口仍保留可达。
    - 仅当用户明确要求"桌面保持辅助块在上、只移动端换序"时，才用 CSS `order`；注意夹在两块之间的 `home_banner2` 会被卷进 flex 容器，需一并处理。
    - **换序后同步修 banner2 与标题链接**：banner2 保持"夹在首个内容块之后、与 banner1 隔实质内容"（原则见 4.3），换序后首个内容块变成文章列表，banner2 落到文章列表之后即可。原本挂在辅助块标题上的"All vehicles"类链接要跟着辅助块走，别遗留在文章标题上造成语义错位或指向无关列表。
    - 判据：375px 下 `导航 → banner1 → 文章列表行`，车辆/参数表出现在文章流之后。真实案例：volt-grid / night-dash 首页原为「车辆表 → 文章」，移动端车辆表占满首屏、文章被推到折叠线下，改为「文章 → 车辆表」全端换序修复。

11. **品牌化错误页是主题完整度的一部分，但必须保留错误语义**——每套主题至少提供与当前主题一致的 404：复用 Logo、字体、色板和导航，说明页面不存在，并给出首页、核心工具/列表、联系页等恢复入口。恢复入口必须是服务端输出的真实 `<a href>`。品牌化 404 是低成本的专业度与信任信号，不是 AdSense 的核心通过条件，但能避免默认 Laravel 页面暴露“未完工”感。
    - 使用 `resources/views/errors/404.blade.php` 承接框架异常；多主题项目可在其中 `@extends(theme_view('layout'))` 或包含当前主题的错误页 partial。
    - **不得**为了品牌化新增一个返回 200 的 fallback 页面；未知 URL 必须保持 HTTP 404。
    - 输出 `<meta name="robots" content="noindex, follow">`，不让错误 URL 入索引，同时允许爬虫发现恢复链接。
    - 404 页面保留清晰 `<h1>`、站点导航和 2–4 个高价值恢复入口；不堆营销文案、广告或大幅装饰。
    - 500 等故障页避免依赖数据库配置和复杂组件，防止错误处理中再次抛错；生产环境不得泄露堆栈、路径或调试信息。

### SOP 步骤

```
1. 定基调 → 验证：用户从 ASCII 预览中拍板
2. 注册主题 → 验证：migration 幂等插入 themes 记录，migrate 通过
3. 建 CSS → 验证：vite.config 注册入口，npm run build 产物独立
4. 写 layout → 验证：sections 契约齐全（title/meta/content/banner_ad/head stack），且 `<x-ad-head position="global_head" />` 后有 `@stack('head')`
5. 写 partials → 验证：主题专属组件渲染正确
6. 写业务页面 → 验证：所有路由 200，信息架构与其他主题差异化；每个 `<x-ad-body position="...">` 都有同页 `@push('head')` 中的对应 `<x-ad-head position="...">`
7. Blade 指令审计 → 验证：grep 无紧贴单词的指令（见避坑 #1）
8. 构建 → 验证：各 CSS 产物独立且体积正常
9. 全面验证 → 验证：走验证清单
10. 提交
```

---

## 四、验证清单（`/laravel-themes verify`）

以下逐项检查，缺一不可：

### 4.1 路由完整性与详情页入口
- [ ] 激活目标主题后，所有前台路由返回 200
- [ ] 详情页路由有数据时正常渲染（无数据可临时造测试记录）
- [ ] 详情页入口可达：列表/赛程/积分榜/对阵图里的实体名（球队/球员/文章）都是进详情页的链接，不只埋在导航深处。检查命令：`curl -s <列表页url> | grep -oc 'href="[^"]*<详情前缀>/[a-z]'` 应 > 0
- [ ] 机器可点击遍历：首页进详情页是真实 `<a href>`，不靠 JS/onclick；广告位插入后未遮挡/抢占卡片可点击区域。判据：上一条 `curl`（纯 HTML、无 JS 执行）能数到首页→详情页链接
- [ ] 无嵌套 `<a>`：实体名 partial 自动建链后，逐页扫描页面无 `<a>` 内再含 `<a>`（已在外层链接里的调用点须传 `link=false`）
- [ ] 整块可点无死角：赛程行/卡片的最外层容器本身是 `<a>`（非 stretched-link 覆盖层），行/卡内含的场馆、组名、比分等全在该 `<a>` 内。检查：列表容器的直接子元素应全是 `<a>`（`curl` 抓取后确认行容器下无游离于链接外的 `<div>`/`<p>` 兄弟）
- [ ] 首页可点密度足够：移动端 375px 下，`导航 → banner1` 后应立即出现热门/最新/目录列表中的多条详情入口；不要先出现大段介绍、搜索表单、统计带、纯分类跳转或装饰模块。参考资讯流首页做法：Hot/Recent/Category 多区块连续给详情链接，图片/标题/整行都能进入详情。量化判据：`curl -s <首页url> | grep -oc 'href="[^"]*<详情前缀>'` ≥ 15，低于此值视为可点密度不足。
- [ ] 首页详情链接服务端可见：即使设计参考了 JS 挂载型站点，Laravel 主题也必须 SSR 输出真实详情 `<a href>`；禁用 JS 或纯 `curl` 首页时，仍能数到详情链接。不能只在前端请求完成后才生成详情入口。

### 4.2 主题隔离
- [ ] 目标主题的 body 标记类命中，其他主题标记零残留
- [ ] 切回默认主题验证反向隔离
- [ ] 标记用 body 上的 CSS 类（如 `theme-xxx-bg`），不用 URL slug——错误页会把视图路径打进 HTML，slug 匹配会假阳性

### 4.3 广告位

**位置规范：**
- **列表/首页 banner1**：导航栏正下方，内容区中间——第一屏内可见，无需滚动
- **列表/首页 banner2**：手机端（375px 基准）用户滑动一次（约一屏高度）后应看到——即 `top ≈ 100vh`，不得紧贴 banner1。**banner1 与 banner2 之间必须隔着实质内容**（hero 或第一屏列表/赛程），不能两个 banner 同屏相邻。若首页删掉 hero，banner2 不要留在内容顶部紧贴 banner1，应下沉到首个内容块（如第一组赛程）之后——用 `@if ($loop->first)` 在列表循环第一项后插入最省事
- **详情页 banner**：放在**面包屑之下、标题之上**。顺序固定 `导航 → 面包屑 → 广告 → 标题/正文`。禁止把广告插在导航与面包屑之间（会割裂面包屑与内容，详见核心原则 #6）

- [ ] 所有广告 slot 位置正确（先 seed 测试广告数据）
- [ ] 每个正文广告都有对应 head code：页面里出现 `<x-ad-body position="home_banner1">` / `detail_banner1` 等时，同一 Blade 页必须 `@push('head')` 输出同 position 的 `<x-ad-head ...>`；只在 layout 输出 `global_head` 不够
- [ ] layout 的 `<head>` 契约完整：`<x-ad-head position="global_head" />` 后必须有 `@stack('head')`，再保留 `@yield('head')` 兼容旧页面；否则页面级 `@push('head')` 永远不会渲染
- [ ] head/body 广告隔离正确：访问首页时只能看到 home 广告 head code，不能混入 detail；访问详情页时只能看到 detail 广告 head code，不能混入 home。测试时给 `AdSpot` 写不同 sentinel（如 `window.homeBanner1HeadLoaded` / `window.detailBanner1HeadLoaded`）并断言 `assertSee` / `assertDontSee`
- [ ] 375px 宽度下 banner1 在第一屏内，banner2 在第一屏外（约一屏滚动后才出现）
- [ ] 移动端两个 banner 之间有足够内容间距，不能紧贴同屏
- [ ] 广告组件无广告时不渲染 DOM
- [ ] 详情页 DOM 顺序为 `导航 → 面包屑 → 广告 → 标题/正文`，广告未插在导航与面包屑之间
- [ ] 首页无 hero 区域：首屏（375px 下约 100vh 内）即出现可点击的详情入口与 banner1，无大幅 hero/横幅占满首屏
- [ ] 每个详情页都有面包屑（`<nav aria-label="breadcrumb">` + JSON-LD BreadcrumbList）

### 4.4 SEO
- [ ] title / meta description / canonical
- [ ] JSON-LD（WebSite + 文章页 NewsArticle）
- [ ] noindex 逻辑（搜索结果页等）
- [ ] 页脚法务页面链接完整
- [ ] 随机访问不存在的 URL 返回真实 HTTP 404，而非 200/302 伪错误页
- [ ] 404 使用当前主题骨架，包含明确 H1、导航及首页/核心内容恢复链接
- [ ] 404 输出 `noindex, follow`，且生产页面不暴露 Laravel 默认错误样式、堆栈或本地路径

**404 机器验证：**
```bash
curl -sS -o /tmp/theme-404.html -w '%{http_code}\n' https://example.com/__missing_page__
grep -Eio '<meta[^>]+name="robots"[^>]+noindex[^>]*>|<a[^>]+href="[^"]+"' /tmp/theme-404.html
```
第一条必须输出 `404`；第二条应同时命中 noindex 与可恢复的真实链接。

### 4.5 移动端
- [ ] 汉堡按钮可见且可点击（touch target ≥ 44px），点击后菜单展开/收起正常
- [ ] 菜单展开时覆盖正确（z-index 不被其他元素压住），点击外部或关闭按钮可收起
- [ ] 导航可用，无横向溢出（overflow-x 无滚动条）
- [ ] emoji 正常大小（Twemoji 的 `img.emoji` 尺寸规则）
- [ ] 移动端首屏无占屏不可点的装饰块：大 section 标题、数字统计带在 375px 下隐藏（`hidden md:*`），折叠线以内出现的是可点列表行而非纯装饰
- [ ] 列表行移动端加高、touch target 够大（如行 `py-4`、卡片 `p-5`），桌面可收窄（`sm:py-3.5`）
- [ ] 375px 基准宽度实测，不依赖桌面端 devtools 模拟

### 4.6 数据重置验证
- [ ] `migrate:fresh --seed` 后首页正常（排除依赖非 seeder 数据的假象）

---

## 五、避坑清单

按严重程度排序，开发新主题前通读一遍。

### 坑 1（致命）：Blade 指令紧贴单词不编译

```blade
{{-- 错误：newsroom@if(...) — @if 紧跟字母，不编译为指令 --}}
newsroom@if ($article->category) {{ $article->category->name }} @endif

{{-- 正确：用三元拼接 --}}
newsroom{{ $article->category ? ' · ' . $article->category->name : '' }}
```

更隐蔽的变体：`UTC@if ($f->venue)` 中 `@if` 不编译，但句尾的 `@endif` 在 `}}` 之后（非单词字符）会正常编译——多余的 endif 把外层 if 提前关闭，下一个 `@else` 直接 ParseError，整页 500。

**机器审计命令**（构建前必跑）：
```bash
grep -rnE '[A-Za-z0-9]@(if|endif|else|elseif|foreach|endforeach|empty|endempty)' resources/views/themes/{slug}/
```

### 坑 2：Twemoji 巨图

Twemoji 把 emoji 替换成 `<img class="emoji">`，CSS 缺 `img.emoji { height:1em; width:1em; }` 时原图尺寸渲染。新主题 CSS 独立拆分时极易漏带此规则。

### 坑 3：DatabaseSeeder 的 `WithoutModelEvents` 吃掉缓存清除

Model 靠 saved 事件清缓存，Seeder 带 WithoutModelEvents 时事件全部失效。Seeder 改主题数据后必须手动 `Cache::forget('active_theme')`。

### 坑 4：广告位后紧邻区块禁用负边距上浮

无广告时广告组件不渲染 DOM，负边距效果正常；有广告时负边距压住的是广告内容。此 bug 仅投放广告后显形。

### 坑 5：`public/hot` 残留导致背景图 404

`npm run dev` 留下的 `public/hot` 文件使 `@vite` 指向 dev server，CSS 内 `url('/...')` 以 dev server origin 解析。页面其他样式正常，仅背景图/字体等引用路径资源 404，极具迷惑性。验证前先确认 `<link rel="stylesheet">` 不指向 5173。

### 坑 6：SVG 渐变 id 重复

组件每次 include 内联 `<defs id="...">`，同页多实例 id 冲突。给渐变 id 加唯一后缀参数。

### 坑 7：部署后 OPcache 跑旧字节码

改 PHP 代码上线必须 reload php-fpm + `queue:restart`。

### 坑 8：多个 CSS 类同时设 `background-image` 整组覆盖

叠加纹理用 `::before/::after` 伪元素铺层，不要依赖多类叠加 background-image。

### 坑 9：花哨 CSS 技巧不如内联 SVG partial

装饰件（旗帜、纹理、图标）优先 SVG Blade partial（参数化颜色/尺寸），CSS 渐变技巧只用于大色块背景。

### 坑 10：广告 body 加了，head code 没跟着进页面

广告通常分两段：`body_code` 渲染在页面可见位置，`head_code` 需要进 `<head>`。只在页面中写 `<x-ad-body position="detail_banner1" />`，但忘记在同页加：

```blade
@push('head')
    <x-ad-head position="detail_banner1" />
@endpush
```

会导致广告容器看起来存在，但广告脚本/预加载/验证代码没加载。真实翻车（提交 `61993c9c`）：所有主题页面都有 body 广告位，却缺页面级 head code，最后需要逐页补 `@push('head')`，并在各 layout 中补 `@stack('head')`。

**规则**：
- `global_head` 只放 layout，全站只输出一次。
- `home_banner*` 只在首页 `@push('head')`。
- `detail_banner*` 只在国家页、工具页、专题页等实际渲染 detail body 广告的页面 `@push('head')`。
- 同一页面 body 用到哪些广告 position，head 就登记哪些 position；不要预先塞未渲染的广告 head，避免跨页面广告脚本污染。

**机器审计命令**（先人工看差异，再补测试）：
```bash
grep -Rho "<x-ad-body position=\"[^\"]*\"" resources/views/themes/{slug}/ | sort -u
grep -Rho "<x-ad-head position=\"[^\"]*\"" resources/views/themes/{slug}/ | sort -u
```

并加 Feature Test：创建 `home_banner1` 与 `detail_banner1` 的 `AdSpot`，分别写不同 `head_code` sentinel，断言首页只出现 home sentinel，详情页只出现 detail sentinel。

### 坑 11：stretched-link 覆盖层留点击死区

想让整卡可点时，别在 `<article class="relative">` 里放一个 `absolute inset-0` 的空 `<a>` 覆盖层。卡内的 `relative z-*` 子元素、以及在覆盖 `<a>` 之后渲染的场馆/说明行会盖在链接之上，那片区域点击落空——移动端尤其明显（真实翻车：venue 行点不进详情）。正解是把容器本身写成 `<a class="block ...">`，内容全部作为其子元素，天然整块可点、无层级坑。

### 坑 12：验证脚本中错误页含主题路径字符串

500 错误页把出错视图路径打进 HTML，如果用主题 slug 做"本主题标记"，500 页面照样命中。标记用 body 上的背景类（互不为子串），HTTP 非 200 直接跳过内容断言。

### 坑 13：品牌化 404 被 fallback 伪装成 200

`Route::fallback(fn () => view('errors.404'))` 默认可能返回 200；页面看似正确，但搜索引擎会把无效 URL 当正常内容，形成 soft 404。优先让 Laravel 异常渲染自动加载 `resources/views/errors/404.blade.php`；若必须自定义 fallback，显式返回 `response()->view('errors.404', status: 404)`。无论实现方式，都要用 `curl -w '%{http_code}'` 验证状态，不能只看浏览器画面。

---

## 六、layout 契约模板

新主题的 `layout.blade.php` 必须实现以下 sections（具体骨架自由发挥）：

```blade
{{-- 必须的 yield/section --}}
@yield('title')             {{-- 页面标题 --}}
@yield('meta_description')  {{-- meta description --}}
@hasSection('noindex') <meta name="robots" content="noindex"> @endif
@yield('eyebrow')           {{-- 页面副标题 --}}
@yield('heading')           {{-- 页面主标题 --}}
@yield('banner_ad')         {{-- 导航栏正下方广告位 --}}
@yield('content')           {{-- 主内容区 --}}
@stack('head')              {{-- 页面级 head 注入 --}}

{{-- 必须的全局元素 --}}
{{-- 1. global_head 广告（<head> 末尾） --}}
{{-- 2. canonical URL --}}
{{-- 3. JSON-LD（WebSite） --}}
{{-- 4. 主题 favicon --}}
{{-- 5. Twemoji 脚本 + img.emoji CSS --}}
{{-- 6. 页脚法务页面链接 --}}
```

---

## 七、使用方式

### 在新项目中搭建
```
/laravel-themes init
```
自动生成：Theme Model、helpers.php（含 bootstrap 兜底加载）、基础 migration、默认主题目录骨架、vite.config 入口。

### 在已有主题项目中新增主题
```
/laravel-themes new cyberpunk
```
走完整 SOP：选型 → 注册 → CSS → layout → 页面 → 审计 → 验证。

### 验证已有主题质量
```
/laravel-themes verify stadium-night
```
逐项走验证清单，输出通过/未通过报告。
