# 判断 Schema —— `AUDIT_JUDGE_v1`

I-Lang v5.0 判断层针对 AdSense 过审审核的领域剖面。这是每一条判定必须满足的契约。

## 从 I-Lang v5.0 继承的设计

三条原则原样沿用:

1. **统一极性。** 每个维度都在 `[0.00, 1.00]` 区间,且方向统一——**1.00 永远代表最有利于过审的条件**。没有任何维度是「越高越糟」的,而消除这种歧义正是判断层的意义所在。
2. **屏障独立于分数。** 单个硬性违规一票否决站点结论,无论其他项分数多高。加权平均描述整体面貌,但永远不能覆盖一个屏障。这是 v5.0 规则「拒绝是结构性的,不会被平均洗掉」在 AdSense 领域的形态。
3. **判定全程留痕。** 每条判定记录它的完整向量、证据、官方依据。「为什么」是可重建、可争议的,绝不是一个孤零零的标签。

## 5 维判断向量

审核中评估的每条要求,产出一条含以下五个维度的记录:

| key | 维度 | 它回答什么 | 极性 |
|---|---|---|---|
| `cmp` | 合规度 compliance | 站点是否满足这条要求? | 1.00 = 完全满足 |
| `evd` | 证据 evidence | 这个判断背后的证据有多扎实? | 1.00 = 直接观测、无歧义 |
| `cer` | 确定性 certainty | 评估本身有多确信? | 1.00 = 无需任何解读 |
| `imp` | 过审影响 approval_impact | 这条要求对过审的影响有多大? | 1.00 = 与过审无关;0.00 = 决定性 |
| `fix` | 修复成本 fix_cost | 若不合规,修复起来有多便宜? | 1.00 = 举手之劳;0.00 = 结构性重建 |

注意 `imp` 和 `fix` 的极性是刻意设计的:高即有利。`imp=1.00` 的要求不可能威胁过审;`fix=1.00` 的问题可被轻松消除。这让整个向量单调——越高永远越安全——这正是屏障逻辑和未来任何可学映射得以良定义的前提。

## 单条判定 verdict

由向量出发,每条判定携带且仅携带一个 verdict:

| verdict | 含义 | 典型向量特征 |
|---|---|---|
| `PASS` | 有证据支撑,要求已满足 | `cmp` 高、`evd` 高 |
| `BLOCKER` | 硬性违规;一票否决申请 | `cmp` 低、`imp` 低(决定性) |
| `HIGH` | 对过审/广告投放有实质风险 | `cmp` 低、`imp` 中 |
| `MEDIUM` | 申请前应修复的质量/抓取/披露缺口 | `cmp` 中、`imp` 中高 |
| `UNKNOWN` | 现有访问权无法验证 | `evd` 低或 `cer` 低 |
| `NA` | 要求确实不适用 | 陈述站点条件 |

`UNKNOWN` 不是软化版的 `PASS`。它明确记录缺什么访问权或证据,以便一旦获得就能转为真实判定。

## 站点级聚合(屏障规则)

执行结论是推导出来的,绝不靠平均堆出来:

```
if 任意判定.verdict == BLOCKER:
    site = NOT_READY                      # 屏障否决,无条件
elif 任意判定.verdict == HIGH:
    site = READY_AFTER_FIXES              # 每个 HIGH 必须修复或明确接受
elif 任意判定.verdict in {MEDIUM, UNKNOWN}:
    site = READY_AFTER_FIXES              # 申请前先解决缺口
else:                                     # 全部 PASS / NA
    site = READY
```

三个站点结论:`READY`、`READY_AFTER_FIXES`、`NOT_READY`。校验器会从各条判定重新推算这个结论,并驳回任何站点结论与之不符的报告——人写的结论不能与它自己的判定自相矛盾。

## 记录格式

每条要求一个 JSON 对象:

```json
{
  "id": "OWN-02",
  "verdict": "BLOCKER",
  "v": {
    "cmp": 0.00,
    "evd": 0.95,
    "cer": 0.90,
    "imp": 0.10,
    "fix": 0.70
  },
  "issue": "robots.txt 禁止了 Mediapartners-Google, 导致 AdSense 无法抓取任何页面",
  "evidence": "GET /robots.txt 返回 'User-agent: Mediapartners-Google\\nDisallow: /'",
  "basis": "AdSense 爬虫访问要求 —— 见 requirements.md OWN-02",
  "fix": "移除 Mediapartners-Google 的 Disallow 块, 或为该 user-agent 添加 'Allow: /'"
}
```

`audit_validator.py` 强制的字段规则:

- `id` 必须存在于 `requirements.md`,且在整份报告中恰好出现一次。
- `verdict` 必须是上述六个值之一。
- `v` 必须包含全部五个 key,每个是 `[0.00, 1.00]` 区间内的浮点数。
- `issue`、`evidence`、`basis`、`fix` 是非空字符串,唯一例外:`verdict` 为 `PASS` 或 `NA` 时 `fix` 可为空。
- 向量/判定自洽:`PASS` 不可带 `cmp < 0.5`;`BLOCKER` 不可带 `cmp > 0.5`。判定必须与它自己的向量一致。

## 为何是五维而非十一维

完整的 v5.0 流形有 11 个维度,覆盖自主行动的一般空间。AdSense 审核是一个有界子空间:v5.0 的若干维度(主权 sovereignty、外部性 externality、漂移 drift)在审核判定间不发生变化,只会是恒定噪声。`AUDIT_JUDGE_v1` 只保留在本领域内真正会变动的维度。这正是「领域剖面」的含义——一个忠实的投影,而非另一套系统。
