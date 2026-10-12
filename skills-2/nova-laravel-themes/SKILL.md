---
name: nova-laravel-themes
description: Laravel 多主题系统开发。Use ONLY when 用户明确要求多主题、主题切换、换肤、新主题、theme、skin，或当前 Laravel 项目已经存在多主题架构；负责主题基础设施、主题隔离、新主题开发与全主题验证，不处理普通单主题项目。
---

# Laravel 多主题开发

> 全程使用中文回复；代码、命令、标识符和文件路径保持原样。

本 skill 只补充多主题特有规则。Laravel、NovaAdmin/Filament、广告、SEO、法务、404、通用 Blade/CSS、移动端和部署规范由 `nova-laravel-starter` 负责，不在这里重复。

## 一、触发边界

仅在以下情况使用：

- 用户明确要求搭建多主题、主题切换或换肤系统。
- 用户要求新增、修改、删除或验证某个主题。
- 当前项目已经存在 `Theme` Model、`theme_view()`、`resources/views/themes/` 或等价多主题架构。
- 修改共享视图、组件或数据契约可能影响多个已有主题。

普通单主题项目不得因为使用本 skill 而引入主题表、主题 helper、多套视图或多 CSS 入口。

## 二、能力

| 命令意图 | 行为 |
|---|---|
| `init` | 搭建最小多主题基础设施 |
| `new <slug>` | 注册并开发一套完整新主题，同时发布本批次 `new` 标记 |
| `verify [slug]` | 验证指定主题或全部主题 |
| `list` | 列出已注册主题、激活状态和目录/构建入口状态 |

无参数时先检测项目状态。已有主题系统则沿用其实现，不另建第二套；没有主题系统时，只有用户明确要求多主题才执行 `init`。

## 三、开始前检查

1. 读取项目级 `CLAUDE.md`、`AGENTS.md` 和现有主题说明。
2. 检查 `Theme` Model、migration、Seeder、helper、控制器调用和后台主题管理。
3. 检查 `resources/views/themes/`、共享 Blade components、CSS 入口和 Vite/Mix 配置。
4. 枚举所有公开命名路由及其页面数据契约。
5. 枚举数据库中已注册主题，并核对 slug、目录和构建入口是否一致。
6. 记录每个主题的骨架、色板、字体、导航形态和签名组件，新增主题时避免重复。

以当前项目已有架构为准。下述结构仅在新建主题系统或项目没有既有约定时使用。

## 四、主题基础设施

### 4.1 最小数据模型

主题记录至少需要：

- `name`
- 唯一 `slug`
- `is_active`
- `is_new`
- 时间戳

`is_new` 是主题发布批次标记：新开发主题必须标记为 `true`，并在同一次发布中先将此前所有 `is_new = true` 重置为 `false`。不能使用 `created_at`、插入顺序或最大 ID 推断新主题。

`Theme` Model 应提供统一的激活主题解析，并在主题保存、删除或切换后清除缓存。切换主题应保证最终只有一个激活主题；存在并发切换风险时使用事务和锁。

```php
class Theme extends Model
{
    public const DEFAULT_SLUG = 'default';

    protected static function booted(): void
    {
        static::saved(fn () => Cache::forget('active_theme'));
        static::deleted(fn () => Cache::forget('active_theme'));
    }

    public static function activeSlug(): string
    {
        return Cache::remember(
            'active_theme',
            now()->addHour(),
            fn () => static::query()->where('is_active', true)->value('slug')
                ?? self::DEFAULT_SLUG,
        );
    }
}
```

不要在 Model 中用宽泛 `catch (\Throwable)` 永久掩盖数据库故障。安装期表不存在的兜底应放在明确的启动边界，或通过迁移/部署顺序保证表已存在。

### 4.2 视图解析与回退

控制器统一通过项目现有 resolver 渲染，不在各控制器手工拼主题路径。新系统可使用：

```php
function theme_view(string $view): string
{
    $slug = Theme::activeSlug();
    $name = "themes.{$slug}.{$view}";

    if ($slug !== Theme::DEFAULT_SLUG && ! view()->exists($name)) {
        return 'themes.'.Theme::DEFAULT_SLUG.".{$view}";
    }

    return $name;
}
```

规则：

- 默认主题必须拥有完整页面，承担缺失视图回退。
- resolver 只接收受控页面名，不能把用户输入直接拼进视图路径。
- helper 若通过 Composer `autoload.files` 注册，修改后必须重建 autoload。
- 项目部署流程可能只按 `composer.lock` 判断是否安装依赖时，可在 `bootstrap/app.php` 明确加载 helper；使用 `function_exists` 防止重复定义。

### 4.3 目录约定

```text
resources/views/themes/
├── default/
│   ├── layout.blade.php
│   ├── partials/
│   └── *.blade.php
└── {slug}/
    ├── layout.blade.php
    ├── partials/
    └── *.blade.php
resources/css/themes/
├── default.css
└── {slug}.css
resources/views/components/   # 跨主题共享组件
public/themes/{slug}/         # 主题专属静态资源
```

不要为了“复用”把主题专属骨架塞进共享组件。只共享数据契约稳定、视觉无关或必须全站一致的能力。

### 4.4 CSS 构建隔离

使用 Tailwind v4 + Vite 时，每个主题可使用独立 CSS 入口，并只扫描自身视图与共享组件：

```css
@import "tailwindcss";
@source "../../views/themes/{slug}/**/*.blade.php";
@source "../../views/components/**/*.blade.php";
```

每个入口必须注册到现有构建配置。不要在未确认版本时套用 Tailwind v4 语法；Tailwind v3、Mix 或其他构建方式应沿用项目已有实现。

验证构建产物确实独立，不能让一个主题依赖另一个主题碰巧生成的 class。

## 五、新主题开发

### 5.1 设计差异

新主题不是只换颜色。至少应在以下维度形成清晰差异：

- 全局页面骨架
- 导航形态
- 首页信息架构
- 字体与字号层级
- 色板和表面材质
- 卡片、列表或表格形态
- 一项可识别的签名组件

开发前用简短 ASCII 版式给用户确认方向，并对照已有主题设计清单避让。未经用户确认，不批量实现整套页面。

不变的是路由、控制器和页面数据契约。不要为了主题视觉修改业务语义或复制控制器。

### 5.2 完整覆盖

新主题必须覆盖当前项目全部公开页面类型，不能只做首页和列表页。以默认主题及路由清单建立页面矩阵，例如：

| 页面/契约 | 默认主题 | 新主题 | 回退允许 |
|---|---:|---:|---:|
| layout | 必须 | 必须 | 否 |
| home | 必须 | 必须 | 按项目决定 |
| list | 必须 | 必须 | 按项目决定 |
| detail | 必须 | 必须 | 按项目决定 |
| static page | 必须 | 必须 | 可 |
| search/empty state | 必须 | 必须 | 可 |

核心页面原则上不依赖默认主题回退，否则“新主题”只是局部换皮。允许回退的页面必须在验收报告中列明。

### 5.3 Layout 与共享契约

- 先从控制器和默认主题提取实际 section、stack、component prop 与数据变量契约。
- 所有主题实现同一语义契约，但 DOM 骨架可以不同。
- 修改共享 Blade component、CSS class 或 slot 时，必须检查全部主题调用点。
- 共享组件新增必填 prop 前先迁移所有主题，避免非激活主题上线后才报错。
- 主题专属资源必须通过当前主题路径加载，不能硬编码其他主题 slug。

### 5.4 注册与发布

- 使用前向 migration 或项目已有注册机制加入主题，不修改已发布 migration。
- migration 和 Seeder 应使用明确 slug，避免依赖插入顺序或 `created_at` 判断发布批次。
- 每次发布新主题都必须带 `new` 标记，数据字段统一使用 `themes.is_new`；字段不存在时先用独立 migration 新增非空 boolean 字段并设默认值 `false`。
- 每个发布批次必须新增独立的前向数据 migration，并严格按顺序执行：先将全部主题的 `is_new` 更新为 `false`，再仅将本批次明确列出的 slug 更新为 `true`。必须把本批次全部 slug 放在同一列表中，不能只清除某几个旧主题。
- 数据 migration 的 `down()` 不恢复旧标记，避免覆盖部署后运营人员在后台的手动调整；如项目有不同的既定回滚策略，以项目约定为准并说明差异。
- Seeder 首次创建主题时必须写入本批次 `is_new` 初始值；使用 `upsert` 或重复 seed 时，更新列不得包含 `is_new`，以保留运营人员后续调整。
- 后台已有主题管理时，确保可查看和编辑 `is_new`，并让 `is_new = true` 的主题优先展示；不要把后台排序逻辑当作发布标记的数据来源。
- Seeder 禁用 Model events 时，主题变更后必须显式清除激活主题缓存。
- 删除主题前检查其是否处于激活状态，并提供可用回退主题；不得留下数据库记录、视图目录或构建入口孤儿。

## 六、推荐 SOP

1. 盘点现有架构和全部页面契约。
2. 确认设计方向及与已有主题的差异。
3. 注册主题记录和构建入口；用独立数据 migration 先重置旧 `is_new`，再标记本批次新主题。
4. 实现独立 CSS、layout 和主题专属 partials。
5. 实现全部核心页面，记录有意使用的回退页面。
6. 逐主题执行路由、DOM、资源和视觉验证。
7. 切回原主题做反向回归，确认共享修改未破坏旧主题。
8. 运行项目测试、格式化和生产构建。

## 七、多主题验证

### 7.1 注册与解析

- [ ] 数据库主题 slug、视图目录和 CSS 入口一一对应。
- [ ] 本批次每个新主题的 `is_new` 均为 `true`，此前批次均已重置为 `false`。
- [ ] `is_new` 来自明确 slug 列表，不依赖 `created_at`、ID 或插入顺序。
- [ ] 只有一个激活主题，切换后缓存立即失效。
- [ ] 默认主题始终可用。
- [ ] 缺失的允许回退页面正确回退；不允许回退的核心页面完整存在。
- [ ] 非法或已删除 slug 不会导致任意视图加载或白屏。

### 7.2 页面契约

- [ ] 枚举全部公开命名路由，并在每个主题下请求验证。
- [ ] 每个主题的 layout 实现项目要求的 sections、stacks 和共享组件契约。
- [ ] 详情、空状态、分页、搜索和静态页没有遗漏。
- [ ] 修改共享组件后全部主题均可渲染。
- [ ] 页面数据相同时，各主题不需要控制器分支或重复业务查询。

### 7.3 隔离与构建

- [ ] 每个主题只加载自己的 CSS/JS 和静态资源。
- [ ] 使用互不重叠的 `body` 标记 class 验证主题，不用 HTML 中可能出现的 slug 字符串判断。
- [ ] 激活目标主题时其他主题标记、资源 URL 和专属组件零残留。
- [ ] 切回默认主题做反向隔离验证。
- [ ] 生产构建包含所有注册入口，且各入口不依赖其他主题扫描结果。
- [ ] 无失效资源、Vite manifest 缺项或错误的主题路径。

### 7.4 视觉与交互

- [ ] 新主题不是仅换色，骨架、信息架构和组件形态与已有主题可辨识。
- [ ] 每个主题分别验证桌面和 375px 移动端。
- [ ] 导航、弹层、分页、表单、卡片及详情入口在所有主题可用。
- [ ] 项目通用广告、SEO、法务、404 和可访问性要求在每个主题均成立。

### 7.5 数据重置与回归

- [ ] 在安全的测试数据库执行项目允许的数据初始化流程后，默认主题可用。
- [ ] 测试证明发布数据 migration 会清除旧 `is_new` 并只标记本批次明确 slug。
- [ ] 测试证明重复执行 Seeder 不会覆盖运营人员手动调整的 `is_new`。
- [ ] Seeder 不意外改变运营人员选择的激活主题。
- [ ] 原有主题测试全部通过。
- [ ] 新主题相关 Feature Test 遍历数据库中的全部主题，不只测试当前激活主题。

## 八、主题特有避坑

1. **只测试激活主题**：共享契约破坏通常潜伏在非激活主题，测试必须遍历全部注册主题。
2. **CSS 扫描串味**：主题 A 的 class 由主题 B 的入口生成，本地看似正常，独立部署后缺样式。每个入口只扫描自己的视图和明确共享目录。
3. **用 slug 搜索判断隔离**：错误页或资源路径也可能包含 slug，造成假阳性。使用主题唯一 `body` class，并先断言 HTTP 状态。
4. **Seeder 吞掉缓存事件**：使用 `WithoutModelEvents` 后手工清除主题缓存。
5. **只换色不换结构**：先维护设计占用表，再确认新主题骨架，避免批量生成同构页面。
6. **共享组件偷偷依赖主题 CSS**：共享组件需要明确的基础样式或稳定 class 契约，不能依赖某个主题私有选择器。
7. **回退掩盖未完成页面**：回退只用于明确允许的低优先级页面，核心页面缺失应让测试失败。
8. **删除激活主题**：删除前切换到有效默认主题，并同步清理缓存、构建入口和资源。
9. **新旧批次同时显示 NEW**：只给新主题写 `is_new = true` 会留下旧标记；发布 migration 必须先全量重置，再按本批次明确 slug 标记。

## 九、完成输出

完成主题任务时说明：

- 新增或修改了哪些主题。
- 主题注册、激活和回退策略。
- 本批次 `new` 标记的 slug、旧 `is_new` 重置方式及对应 migration。
- 完整实现与有意回退的页面清单。
- CSS/JS 构建入口变化。
- 已验证的主题、路由、桌面/移动端及测试命令。
- 未执行的验证及原因。
