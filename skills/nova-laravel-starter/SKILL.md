---
name: nova-laravel-starter
description: 使用 inova/nova-laravel-starter 创建和开发 ~/project 下的 Laravel 项目。Use when 用户要求新建或修改这些 Laravel、Filament/NovaAdmin、Blade、SEO、广告、法务、内容、测试与部署代码；不默认引入多主题系统。
---

# Nova Laravel Starter 开发

> 全程使用中文回复；代码、命令、标识符和文件路径保持原样。

本 skill 是 `/home/luoxg/project` 项目的默认开发规范。它整合该目录现有项目的共同约定、Laravel 高价值工程原则，以及 `nova-laravel-themes` 中可泛化到单主题项目的前台质量要求。

## 一、适用范围

以下任务必须使用本 skill：

- 在 `/home/luoxg/project` 创建新的 Laravel 项目。
- 开发或维护该目录下现有 Laravel 项目。
- 修改 Laravel、Blade、Filament、NovaAdmin、数据库、SEO、广告、法务内容、测试或部署。
- 开发内容站、目录站、工具站及其前后台页面。

本 skill 自包含必要的 Laravel 工程规则。复杂查询、缓存、队列、调度、HTTP 和错误处理仍以本文件、当前项目模式及 `composer.lock` 对应的官方文档为准。涉及视觉设计时应用现有前端设计 skill，并优先保持项目已有设计语言。

### 多主题边界

- 默认按单主题项目开发，不创建 `Theme` Model、`theme_view()`、主题表、主题切换 helper、主题目录或多 CSS 入口。
- 只有用户明确提出“多主题、主题系统、换肤、新主题、theme、skin”，或当前项目已经存在主题系统时，才同时加载 `nova-laravel-themes`。
- 已有多主题项目中，修改共享 Blade 或 CSS 契约时必须验证全部可用主题；单主题项目不因此引入主题系统。

## 二、工作原则

1. 先读项目事实，再写代码。优先读取当前项目的 `CLAUDE.md`、`AGENTS.md`、README、`composer.json`、`composer.lock`、`package.json` 和锁文件。
2. `composer.lock` 是实际版本依据。不要从其他 project 推断 Laravel、Filament、Tailwind 或构建工具版本。
3. 遵循当前项目已有结构和命名，不从相邻项目复制整套架构。
4. 做最小正确修改，不顺手重构、不增加未要求的包和抽象。
5. 先定位现有后台能力，再新增代码。`nova-admin` 不是 Laravel Nova；它通常基于 Filament 或以内嵌 `App\NovaAdmin` 形式存在。
6. 每项工作都要有可验证目标。Bug 优先补复现测试；新行为同步补 Feature 或 Unit Test。

## 三、新项目初始化

### 3.1 唯一允许的创建方式

禁止使用 `laravel new`、`composer create-project laravel/laravel` 或手工拼空白 Laravel 项目。必须使用：

```bash
composer create-project inova/nova-laravel-starter <project-name>
```

用户未给项目名或目标路径时先确认，不能把项目误建到当前目录。默认目标位于 `/home/luoxg/project/<project-name>`。

### 3.2 初始化流程

1. 创建项目。
2. 阅读生成项目自身的说明和依赖文件，确认 Laravel、Filament、NovaAdmin、Tailwind、Vite 版本。
3. 配置 `.env` 与基础环境：`APP_NAME`、`APP_URL`、数据库、邮件、缓存、队列；不得提交真实密钥。
4. 检查日志与时区配置：
   - `config/logging.php` 默认 channel 必须配置为 `daily`（按天切分，防止日志无限膨胀撑爆磁盘）。
   - `config/app.php` 时区统一配置为 `'timezone' => 'Asia/Shanghai'`（或站点统一目标时区）。
5. 在首次 seed 前检查 `config/nova-admin.php`、静态页默认内容、广告 positions、Sitemap provider 和站点联系信息。
6. 根据生成项目脚本选择 `composer run setup`，并确认它是否执行 seed。仅迁移未 seed 时再执行 `php artisan migrate --seed`。
7. 确保 `public/favicon.ico` 或矢量 SVG favicon 存在，避免默认裸奔 404。仅当项目使用 Laravel local `public` disk，并通过 `public/storage` 对外提供上传、Logo、Favicon 或附件时执行 `php artisan storage:link`。
8. 有 `package-lock.json` 时使用 `npm ci`，然后执行 `npm run build`。
9. 确认管理员创建方式；项目提供命令时可用 `php artisan nova-admin:create-admin`。生产环境不得保留默认弱凭据或无限制快速登录。
10. 检查 `/`、`/admin`、法务页、`/sitemap.xml`、`/robots.txt`、`/ads.txt`（确保位于 `public/ads.txt`）和随机不存在 URL。
11. 运行项目已有测试、格式化和构建检查。

不得对已有数据的项目随意运行 `migrate:fresh --seed`。不得盲目执行 `nova-admin:install`；仅在包式 NovaAdmin 且配置、迁移确实未安装时执行。

## 四、现有项目识别

开始开发前判定：

- Laravel 和 PHP 实际版本。
- 后台是 `App\NovaAdmin`、`Inova\NovaAdmin`、自建 Filament，还是其他后台。
- Filament 主版本及现有 `app/Filament`、Panel Provider、权限模式。
- 前端使用 Vite 还是 Mix，Tailwind 主版本及 CSS/JS 入口。
- 是否有队列、scheduler、缓存、上传盘、外部 API、内容生成或数据抓取。
- 是否已有主题系统、广告组件、SEO helper、静态页 CMS、Sitemap provider 和 HTML 清洗器。
- 前台与后台语言。该项目族通常前台面向海外用户使用英文，后台运营界面使用中文；以项目自身规则为准。

不要把某个项目的特例推广为全局规则，例如 RSS、OpenAI 内容生成、外部图片挂载、根级 `/{slug}`、浏览器端 PDF、主题发布批次或快速登录。

## 五、Laravel 与后台开发

### 5.1 Laravel

#### 一致性优先

- 先检查相邻 Controller、Model、Request、Resource、Job 和测试的已有模式。Laravel 同一问题通常有多种正确写法，项目一致性优先于理论上的“最佳”写法。
- 使用当前 Laravel 版本可用的 API，不从其他 project 或新版本文档直接照搬。
- 优先 Laravel 官方能力和约定，不覆盖框架默认行为，不为单次调用创建抽象层。

#### 查询与 Eloquent

- 避免 N+1，按页面数据契约使用 `with()`、`withCount()` 或聚合查询；Blade 中不查询数据库。
- 对大表、重字段和明确数据契约只选择需要的列，但不要为了形式上避免 `SELECT *` 破坏 Filament、accessor 或 global scope。自定义主查询或 eager load 的 `select()` 必须保留主键、关系外键和需要的中间表字段。
- 大数据批处理使用 `chunkById()` / `lazyById()`，只读且只需模型自身字段时可使用 `cursor()`；需要关系数据时使用支持分块 eager load 的 `lazy()` / `lazyById()` 或 `chunkById()`。迭代中更新筛选字段时按稳定唯一键遍历，避免 offset 分页漏行或重复。
- 可复用筛选使用 local scope；global scope 谨慎使用，并让其存在易于发现。
- 关系方法声明明确返回类型；属性转换放在 `casts()`，日期以 Carbon 对象进入视图。
- 优先 `whereBelongsTo()` 等关系语义 API。`whereHas`、`whereIn`、join、相关子查询和拆分查询没有固定优胜者；先保证语义正确，再结合真实数据库、数据量、索引和 `EXPLAIN`/查询日志测量。
- 原始 SQL 不拼接用户输入。`WHERE`、`ORDER BY`、`JOIN` 常用列在 migration 中设计匹配索引；复合索引顺序匹配实际查询。
- 开发环境可启用 `Model::preventLazyLoading()`，尽早发现隐式查询。

#### 验证、授权与安全

- 普通 HTTP Controller 的复杂输入优先 Form Request，并只使用 `$request->validated()`；Filament、Livewire、Console 等入口使用其原生验证机制。服务层不得信任未经验证的数据。
- 所有受保护行为通过 Policy、Gate 或项目现有权限层授权，不只隐藏按钮。
- Model 明确 `$fillable` 或 `$guarded`，禁止把 `$request->all()` 直接传入写操作。
- Blade 默认使用 `{{ }}` 转义；富文本只通过项目现有白名单/清洗机制输出，不扩大 `{!! !!}` 的可信输入范围。
- 状态变更表单必须有 CSRF；登录、找回密码、公开写接口和高成本接口配置限流。
- 文件上传根据文件内容允许列表验证类型/MIME 和大小；仅在业务确实依赖时校验后缀。永远不信任客户端文件名，由应用生成名称并写入受控路径。
- `env()` 只在 config 文件中使用；业务代码通过 `config()` 读取。敏感配置不入库明文或源码。encrypted cast 字段同时加入 `$hidden` 或从 Resource 排除，并为膨胀后的密文预留列容量；需要检索时另建不可逆摘要，不查询密文本身。
- 生产密钥来自部署平台 secret store、受控环境变量或 Laravel encrypted environment；解密密钥不能与密文一起提交或写入日志。

#### 路由、控制器与架构

- 使用命名路由、隐式路由模型绑定和 scoped bindings；标准 CRUD 优先 resource route。
- 动态通配路由放在静态路由之后，并添加约束，避免吞掉后台、法务页和系统路由。
- 分页、后台列表、导出和批处理必须有符合业务语义的确定排序；排序字段可能重复时追加唯一键作为 tie-breaker。
- 控制器只负责编排请求。复杂且可复用的单一业务动作再提取为 Action；需要跨场景协作的能力才使用 Service。
- 依赖使用构造器或方法注入，不在业务深处随意调用 `app()`。
- 事件、Job 和通知只用于确实需要解耦、异步或重试的场景，不把简单同步流程拆碎。
- 使用 Laravel、`Str`、`Arr`、`Number`、`Uri` 和 Request typed input 等现有 helper，避免重复造轮子。

#### 缓存、并发与事务

- 缓存优先 `Cache::remember()`；同请求重复读取可使用项目版本支持的 memoization 能力。
- 缓存必须设计失效时机，写操作完成后清理相关 key/tag，不能只设置长 TTL 掩盖一致性问题。
- 防重复执行使用 `Cache::lock()`、数据库唯一约束或行锁；不能用“先查再写”假装原子操作。`lockForUpdate()` / `sharedLock()` 必须位于覆盖“读取、判断、写入”完整临界区的事务中，唯一约束仍是最终防线。
- 多表一致性写入使用数据库事务。事务内分发事件、Job、通知或邮件时使用 after-commit 语义，避免消费者读到未提交数据。
- 热点接口采用 stale-while-revalidate、标签或锁前先确认当前 cache driver 支持，不能假设所有环境一致。

#### 队列、事件与计划任务

- Job 设置与业务匹配的 timeout、tries/backoff；队列连接的 `retry_after` 必须大于 Job/worker timeout。
- 可能重复提交的任务使用唯一 Job、幂等业务键或数据库约束，并实现失败处理。
- 外部 API Job 使用限流和指数退避；永久性参数错误不要无意义重试。
- 事务中产生的 Job、Event、Notification、Mailable 在提交后分发。
- 可变耗时的 schedule 使用 `withoutOverlapping()`；多服务器部署按需使用 `onOneServer()`。
- 只有项目确实使用队列或 scheduler 时才增加 Supervisor、Horizon 或 cron 配置。

#### HTTP 与错误处理

- 外部 HTTP 请求必须设置连接超时、总超时和状态检查。只对连接失败、超时、限流及可恢复 5xx 等瞬时故障重试，普通 4xx 和业务拒绝不重试；有副作用的请求仅在第三方支持幂等键或操作可安全重复时自动重试。
- 并发且互不依赖的请求可使用 pool；共享限流或顺序依赖的请求不能为追求速度强行并发。
- HTTP 测试使用 `Http::fake()`，重要测试可禁止 stray requests，不能访问真实第三方服务。
- 可预期业务失败使用领域异常或明确结果，不用宽泛 `catch (\Throwable)` 吞掉故障。
- 异常在项目现有异常类或 `bootstrap/app.php` 中统一 report/render；日志附结构化上下文，但不记录密钥和敏感数据。
- API 路由返回一致 JSON 错误；生产环境不泄露堆栈、本地路径或 SQL。

#### Migration 与配置

- 新 migration 用 `php artisan make:migration` 生成。已发布 migration 不回改，使用前向 migration 修正。
- 外键优先 `constrained()`，常用查询字段按实际查询和数据库行为设计索引，避免重复索引。
- 只有未保存模型、Filament 表单或领域逻辑在写入前需要读取默认值时，才在 Model `$attributes` 镜像可稳定表达的数据库默认值；数据库是持久化默认值的最终来源。
- 一个 migration 只处理一个明确 concern，避免把大量数据修复和结构变更混在一起。
- `down()` 默认可逆；若操作有意不可逆，明确记录并通过前向修复处理。
- 配置、语言文件或常量承载可变规则和固定枚举，不在 Controller、Blade 多处硬编码。

#### 测试与代码风格

- 行为修改同步补测试：HTTP 行为放 Feature Test，纯逻辑放 Unit Test。
- 数据库测试优先 Factory、state 和关系定义，不手工堆大量无关字段。
- 使用 Event、Queue、Notification、Mail、Storage、HTTP fake 隔离边界；先完成 Factory 数据准备，再启用可能干扰模型事件的 fake。
- 实现 `ShouldQueue` 的 Mailable/Notification 使用队列断言；内容渲染测试与是否成功入队的测试分开。
- 断言业务结果和模型状态，不只断言响应 200；回归 Bug 测试必须能在修复前失败。
- PHP 遵循项目 Pint/PSR-12；类名 `PascalCase`、方法/变量 `camelCase`、数据库字段 `snake_case`。
- JS/CSS 不堆在 Blade，HTML 不放进 PHP 类；代码应自解释，注释只解释不明显的原因和约束。

### 5.2 NovaAdmin / Filament

- 优先复用已有站点设置、静态页、广告位、`ads.txt`、`robots.txt`、Sitemap 和日志能力。
- 不重复创建第二套站点设置、广告表、法务 CMS 或管理员体系。
- 业务资源放入项目已有 `app/Filament` 结构；通用后台能力留在 NovaAdmin。
- 修改后台时验证 `/admin` 鉴权、Panel 权限、表单规则、导航组、运营文案和管理员 Seeder。
- 后台标签默认中文，前台访客内容默认英文；共享组件必须先确认服务对象。

## 六、前台信息架构

本节总结自 `nova-laravel-themes` 的通用前台要求，适用于单主题与多主题项目。

### 6.1 详情入口与可点击性

- 列表、资讯流、赛程、积分榜或目录中的主要实体应能进入对应详情页。
- 首页到详情页必须由服务端输出真实 `<a href>`；禁用 JS 后仍可发现，不使用纯 `onclick` 或仅 hover 出现的入口。
- 整卡或整行可点时，最外层直接使用 `<a class="block ...">`，不要使用 `absolute inset-0` 的 stretched-link 覆盖层。
- 避免嵌套 `<a>`。需要分类独立链接时，让图片链接、标题链接和分类链接保持平级；不要再包整卡链接。
- 图片遮罩和广告不得覆盖或抢占内容链接的点击区域。
- 详情页必须有恢复路径和相关入口，不能只从导航深处到达。

### 6.2 首页优先级

- 内容站和目录站首页优先展示实际内容入口，不使用占满首屏、不可点击的大 Hero。
- 推荐顺序：`导航 -> banner1 -> 热门/最新/目录内容 -> banner2 -> 更多内容`。
- 移动端隐藏大标题、统计带等占屏但不可点击的装饰块；保留并适当加高可点击列表行，touch target 至少 44px。
- 若页面同时有主要跑量内容和辅助数据块，主要内容排在前面。优先调整 DOM 顺序，不用 CSS `order` 制造两套阅读顺序。
- 对内容密集型首页，可用服务端 HTML 中可发现的详情链接数量作为信号；`>= 15` 仅用于确实需要资讯流/目录流的站点，不强制纯工具首页凑数。

### 6.3 详情页结构

- 广告型内容详情页默认顺序：`导航 -> 面包屑 -> 详情广告 -> 标题/正文`；无广告工具页或已有其他契约的页面按实际类型调整，但不能用广告割裂导航与面包屑。
- 面包屑使用 `<nav aria-label="breadcrumb">`，并提供 `BreadcrumbList` JSON-LD。
- 文章、实体或工具详情页提供唯一标题、摘要和真正有帮助的主体内容，不制造 thin content 页面。

### 6.4 语义骨架与工具页初始态

- **降低分类器结构异常分**：严格遵循 HTML5 标准语义标签，布局骨架采用 `header > nav > main > (article > h1 + h2 + p) + footer`，避免由无语义 `<div>` 纯粹拼凑（Div-soup），保证爬虫与自动审核分类器能快速识别标准站点结构。
- **工具页与计算器 GET 初始态（抗 Thin Content）**：工具/查询/计算器类页面在初次 `GET` 访问时，**必须默认呈现一组合理的示范数据、预填案例及计算结果**，并配有详细的使用说明（How-to）、原理解析和常见问题（FAQ），严禁全空初始态或仅依赖 POST 请求渲染内容。
- **嵌入内容语境化**：页面若包含 `<iframe>`、第三方图表或嵌入式小工具，必须包裹在具有上下文说明、原创解读与操作指引的容器中，严禁无文字语境的纯嵌入页。

## 七、广告规则

- **后台配置注入原则**：广告代码（`global_head`、各 banner slots）必须由后台配置项（NovaAdmin/Filament 站点设置）注入，**严禁在 Blade 视图中硬编码 AdSense 脚本**。
- 广告通常分 `head_code` 和 `body_code`。页面渲染某个 body position 时，同页必须加载对应 head position。
- `global_head` 只在 layout 输出一次；首页和详情页广告 head code 按页面隔离，不提前加载未使用 position。
- Layout 中全局 head 之后保留页面级 head stack；沿用项目现有 `@stack('head')` / `@yield('head')` 契约。
- `banner1` 位于导航下方且首屏可见；`banner2` 与其间隔实质内容，通常约一次手机屏幕滚动后出现。
- 详情广告位于面包屑下、标题上，不能割裂导航和面包屑。
- 空白或未激活广告不渲染占位 DOM；广告不得遮挡导航、内容链接或主要操作。
- **防误触与安全边距**：广告与导航栏、操作按钮、翻页器之间必须保留至少 `24px~32px` 的视觉与点击安全间距，严禁贴近诱导误触；严禁出现“点击广告支持本站”等诱导文案；单页广告面积不得压过主体内容（内容为主、广告为辅）。
- **严禁客户端 CSS 隐藏广告**：严禁在客户端使用 `hidden`、`md:hidden` 或 CSS `display:none` 隐藏已请求的广告单元（违反 AdSense 修改代码政策）；若需分端展示不同广告位，必须在服务端（Blade/Agent）进行条件渲染。
- **非内容页全局禁放清单**：以下页面类型严禁渲染任何广告 DOM：
  1. 错误页（`404`、`500` 等）；
  2. 认证与账户页（`/login`、`/register`、`/password/*`）；
  3. 后台管理页面（`/admin/*`）；
  4. 空搜索结果页 / 筛选无数据状态；
  5. 表单提交成功/感谢页；
  6. 纯法务页（Privacy, Terms 等纯合规页不挂正文广告）。
- **`ads.txt` 规范**：限定保存到 `public/ads.txt` 文件中，确保站点根路径可直接访问。
- 新增广告位时测试 head/body sentinel、页面类型隔离、无广告 DOM 和关键 DOM 顺序。

## 八、SEO、法务与可信内容

### 8.1 SEO

新增可索引页面时同步检查：

- 唯一且描述准确的 `<title>` 和 meta description，严禁全站模板重复。
- 正确 canonical（指向自身绝对规范 URL）、Open Graph 和 Twitter metadata；`og:image` 必须为真实存在的绝对 URL。
- `robots.txt` 必须允许正常抓取，且显式放行 AdSense 爬虫：
  ```text
  User-agent: Mediapartners-Google
  Disallow:
  ```
  提审前严禁对全站挂 `noindex`（仅搜索筛选、404 等局部挂 `noindex`）。
- 完整合法的 JSON-LD 结构化数据：站点级 `WebSite`/`Organization`、列表页 `BreadcrumbList`、详情页 `Article`（或匹配类型），不虚标字段。
- Sitemap 仅收录真实发布且应索引的 URL。
- **图片防 CLS 与无障碍**：所有 `<img>` 标签必须显式指定 `width`/`height` 或 CSS `aspect-ratio` 防止布局抖动；必须配有 `alt` 属性；首屏外的图片添加 `loading="lazy"`。

### 8.2 法务与内容真实性

- **法务五件套硬门槛**：Privacy Policy、Terms of Service、About、Contact、Cookie/Disclaimer 必须全部路由可达（HTTP 200）、页脚全主题/全布局均有链接，且正文非空壳（每页 ≥ 一屏实质文字）。
- **Privacy Policy 专项条款**：必须显式声明 Google 作为第三方广告供应商会使用 Cookie 投放个性化广告，并提供 `https://policies.google.com/technologies/ads` 退出链接。
- **抗 Thin Content 量化门槛**：
  - 内容站 Seeder 必须预置 **≥ 15~20 篇**高质量实质内容，单篇正文 **≥ 300 词 / 600 汉字**，内容互不雷同且具备真实信息增量（一手经验、测试数据或独到分析），严禁仅 seed 1~2 条测试数据或纯空壳占位。
  - 工具站必须为每个工具页面提供足量的使用指南、算法/原理解析及 FAQ 说明文案。
- 不虚构公司、地址、人员、资质、实测、专家评审、发布日期、更新时间、广告、分析或 Cookie 使用情况。
- 内容 Seeder 尽量幂等，保留运营人员修改和真实发布时间；不得在重复 seed 时无条件覆盖生产内容。
- SEO、法务、广告和内容是联动系统，相关变更不能只改一张 Blade 后结束。

### 8.3 404 与错误页

- 未知 URL 必须返回真实 HTTP 404，不能把 404 Blade 通过 fallback 伪装为 200。
- 404 使用站点品牌、明确 `<h1>`、`noindex, follow`，并提供首页及 2 至 4 个高价值恢复链接。
- 404 不堆广告或营销文案。
- 500 页面减少数据库和复杂组件依赖，生产环境不泄露堆栈、路径和调试信息。

## 九、Blade、CSS 与移动端避坑

### 9.1 Blade

Blade 指令不能紧贴字母或数字：

```blade
{{-- 错误 --}}
newsroom@if ($article->category)

{{-- 正确 --}}
newsroom{{ $article->category ? ' · ' . $article->category->name : '' }}
```

修改较多 Blade 后扫描：

```bash
rg '[A-Za-z0-9]@(if|endif|else|elseif|foreach|endforeach|empty|endempty)' resources/views
```

- 可复用 UI 使用具有明确 props、slots 和 attribute bag 的 Blade component，根元素通过 `$attributes->merge()` / `class()` 保留调用方扩展能力；仅用于页面拆分且不需要独立 API 的片段可继续使用 `@include`。
- 循环中可能多次渲染的组件，其脚本或样式进入现有构建入口，或按项目契约使用 `@pushOnce` / `@once`，避免重复注入。
- 多页面共享的站点设置、导航、分类或侧栏数据通过项目已有 Service、View Composer、component 或统一 view model 提供；不要在 Controller 重复拼装，也不要让 Blade 查询数据库。

### 9.2 CSS 与资源

- 沿用当前 Vite/Mix 和 Tailwind 主版本，不擅自升级。
- CSS/JS 放入既有构建入口，不在 Blade 中塞大段样式或脚本。
- Twemoji 项目必须保留 `img.emoji { height: 1em; width: 1em; }` 等尺寸约束。
- 内联 SVG 的 `<defs id>` 在同页多实例时必须唯一。
- 多层 `background-image` 使用伪元素分层，避免多个 class 相互覆盖整个属性。
- 装饰图形优先复用 SVG Blade component/partial，避免难维护的复杂渐变技巧。
- 检查 `public/hot` 残留；生产页面不能继续引用 Vite dev server。
- 广告之后的内容不要用负 margin 上浮，以免有广告时覆盖广告。

### 9.3 移动端

- 以 375px 为基准验证，再扩展桌面端。
- 导航在小屏可展开/收起，按钮 touch target 至少 44px，层级正确，无横向溢出。
- 首屏优先放可点击内容和主要工具，不放占屏装饰。
- 卡片、表格、代码、图片和广告在窄屏不能造成横向滚动。
- 不只依赖静态审查；项目有 Playwright 或浏览器测试时复用它。

## 十、测试与完成标准

### 10.1 按变更补测试

- 公开路由：成功状态、未发布内容不可见、真实 404、工具页 GET 初次访问渲染默认案例。
- 数据库：关系、scope、约束、Seeder 充实度（≥15-20篇、字数达标）与幂等性。
- 后台：管理员权限、表单验证、资源行为。
- 前台：真实详情链接、无嵌套链接、关键 DOM 顺序、移动端导航、图片包含 `width`/`height`/`alt`。
- 法务合规：法务五件套路由均 200、各布局页脚链接齐全、Privacy Policy 含 Google Cookie 声明及退出链接。
- 广告合规：head/body 对应、页面隔离、无广告时无空 DOM、非内容页（认证/404/后台/空结果）绝无广告 DOM、`public/ads.txt` 存在且可访问。
- SEO：canonical、robots（放行 Mediapartners）、Sitemap 和三层 schema。
- 安全：富文本清洗、文件上传、授权和外部 HTTP fake。
- 多主题项目：遍历全部主题；单主题项目只验证当前前台。

### 10.2 验证命令

先读取项目脚本，再运行适用命令，不机械假设所有项目都有同一工具：

```bash
php artisan test
./vendor/bin/pint
npm run build
```

若项目已定义，再运行：

```bash
npm test
npm run test:e2e
npm run test:lighthouse
composer audit --locked
npm audit --omit=dev
```

定向测试先跑，完成前再跑合理范围的全量测试。无法运行的检查必须明确说明原因，不能宣称已验证。

### 10.3 最终检查

- 所有改动都直接服务当前需求。
- 没有覆盖用户现有改动，没有提交 `.env`、密钥或真实凭据。
- PHP 格式、测试和前端构建通过。
- 桌面与 375px 移动端主要路径可用。
- 首页、详情页、后台、法务页、系统文件和 404 行为符合项目实际需求。
- 新增配置、迁移、队列或部署步骤已在最终说明中列出。

## 十一、部署注意

- 生产环境使用 `APP_ENV=production`、`APP_DEBUG=false` 和最终 HTTPS `APP_URL`。
- 常见流程：`composer install --no-dev --optimize-autoloader`、`php artisan migrate --force`、部署已构建的前端产物、`php artisan optimize`。仅在部署流程明确要求服务器现场构建时执行 `npm ci && npm run build`。
- 仅在使用 Laravel local `public` disk 且需要 `public/storage` URL 时执行 `php artisan storage:link`。
- 有队列时部署后执行 `php artisan queue:restart`，并确保 `retry_after` 大于 worker timeout。
- 有 scheduler 时才配置 cron；不要为空项目增加 Supervisor 或 scheduler。
- PHP 代码部署后按环境 reload PHP-FPM，避免 OPcache 继续运行旧字节码。
- Composer 使用 `--no-scripts` 时检查是否需要手工执行 Filament assets 命令。

## 十二、与 nova-laravel-themes 的关系

本 skill 已吸收 `nova-laravel-themes` 中可泛化的要求：

- 真实 `<a href>` 与整卡可点击。
- 内容优先的首页及移动端首屏。
- 面包屑、广告顺序和 head/body 广告契约。
- SEO、法务、品牌化真实 404。
- Blade、Twemoji、SVG、Vite、OPcache 等避坑。
- 路由、广告、移动端、数据重置和构建验证。

以下能力没有默认复制，必须在明确需要多主题时加载 `nova-laravel-themes`：

- `Theme` Model、主题表、激活状态与缓存。
- `theme_view()`、默认主题回退及 helper autoload。
- `resources/views/themes/`、每主题 CSS 入口和主题隔离。
- 新主题注册、设计语言避让、主题 NEW 批次和全部主题遍历。
