# 使用与调用模板

如何调用 iLang AdSense 审核器,以及能得到什么。

## 什么时候用

- 申请 AdSense 之前,先找出并修复阻断项。
- 被拒之后(「网站尚未准备好」「内容价值偏低」、政策通知),用证据诊断原因。
- 已过审站点收到政策警告后的广告投放清理。

## 基础调用

```
审核 https://example.com 是否具备申请 AdSense 的条件。
```

审核器会抓取、把全部 29 条要求评估成判断向量、运行完整性闸门,并返回一份含执行结论、按严重度排序的发现、以及完整要求表的报告。

## 带仓库访问权

```
审核这个站点的 AdSense 过审条件。线上地址是 https://example.com,源码仓库在
./site。请检查模板和内容来源,不要只看渲染后的首页。
```

仓库访问权能把许多 `UNKNOWN` 判定升级为真实判定,因为内容来源、路由、生成逻辑都变得可检查。

## 被拒后诊断

```
我的 AdSense 申请被拒了,理由是「内容价值偏低」。审核 https://example.com,
告诉我到底哪些要求不合格,每条附上证据和具体修复方案。
```

## 广告投放清理

```
我已过审的站点收到了一条关于广告位置的 AdSense 政策警告。审核 https://example.com,
重点看 IMP 类要求,标出任何违反广告位置或无效流量政策的地方。
```

## 如何理解输出

- **执行结论** —— `READY`、`READY_AFTER_FIXES` 或 `NOT_READY`。记住这是过审条件评估,不是过审保证;最终由 Google 决定。
- **每条发现**都携带一个判断向量 `{cmp, evd, cer, imp, fix}`。看 `cmp` 判合规、看 `imp` 判对过审的影响(低 = 决定性)、看 `fix` 判修复有多便宜(高 = 举手之劳)。
- **`UNKNOWN`** 发现会告诉你补充什么访问权或证据就能解决它。提供之后重跑,判定会更锐利。
- 你收到的审核已通过 `audit_validator.py --check`,所以每条要求都被评估过——没有任何一条被悄悄跳过。

## 自己运行校验器

```bash
# 列出清单定义的每个要求 ID
python3 validator/audit_validator.py --list

# 生成空白骨架供手动填写
python3 validator/audit_validator.py --template > report.json

# 校验一份已完成的报告
python3 validator/audit_validator.py --check report.json

# 验证工具本身
python3 validator/audit_validator.py --selftest
```
