---
name: git-commit
description: Git commit with auto-generated message. Use when the user says "提交", "commit", "git commit", or "git:commit".
---

## Instructions

1. Run `git status` to see untracked and modified files
2. Run `git diff` (staged + unstaged) to understand all changes
3. Run `git log --oneline -5` to see recent commit message style
4. Based on the changes, draft a commit message following the rules below
5. Stage only the relevant changed files by name (do NOT use `git add -A` or `git add .`)
6. Create the commit using a HEREDOC for the message
7. Show the result with `git log --oneline -1`

## Commit message rules

- **始终使用中文撰写提交信息**（无论最近提交是什么语言）
- Subject line: **50 chars or less**. State WHAT changed, not HOW.
- If multiple files changed for the same purpose, summarize the purpose — don't list files
- Body (optional): only when the subject alone is ambiguous. Max 2 lines, focus on WHY
- No scope prefixes (feat/fix/chore) unless the repo already uses them
- **禁止添加 Claude 署名**（`Co-Authored-By: Claude ...` 等 trailer），即使最近提交里有也不要模仿
- Prefer a single line commit. Multi-line only when changes span unrelated concerns that can't be summarized in one phrase

**Bad:** `更新用户认证模块以处理令牌刷新的边界情况并增加错误日志`
**Good:** `修复令牌刷新边界情况`

Do NOT push to remote. Do NOT commit .env or credential files.
