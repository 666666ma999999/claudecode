# Skills Manifest

外部スキル（symlink）と自作スキル（local）のインベントリ。
バージョン管理は `~/.agents/.skill-lock.json` のハッシュで追跡。

## External Skills（外部導入 — symlink via ~/.agents/skills/）

### trailofbits/skills — セキュリティツール群
| スキル | ハッシュ | 導入日 |
|--------|---------|--------|
| agentic-actions-auditor | `764ce77` | 2026-03-27 |
| differential-review | `0879a9b` | 2026-03-27 |
| semgrep | `7be6fe5` | 2026-03-27 |
| semgrep-rule-creator | `13ebbb6` | 2026-03-27 |
| supply-chain-risk-auditor | `d150815` | 2026-03-27 |
| variant-analysis | `107574a` | 2026-03-27 |

### Lum1104/Understand-Anything — コードベース可視化
| スキル | ハッシュ | 導入日 |
|--------|---------|--------|
| understand | `6bed69b` | 2026-03-27 |
| understand-chat | `5e511bd` | 2026-03-27 |
| understand-dashboard | `77029c9` | 2026-03-27 |
| understand-diff | `aa7fba4` | 2026-03-27 |
| understand-explain | `2e71576` | 2026-03-27 |
| understand-onboard | `2cdaea2` | 2026-03-27 |

### 単体導入
| スキル | ソース | ハッシュ | 導入日 |
|--------|--------|---------|--------|
| humanizer-ja | gonta223/humanizer-ja | `a1e3436` | 2026-03-27 |
| find-skills | vercel-labs/skills | `c2f3117` | 2026-02-12 |

### npx skills 経由だが local コピー済み
| スキル | ソース | ハッシュ | 導入日 |
|--------|--------|---------|--------|
| health | tw93/claude-health | `058768d` | 2026-03-26 |
| frontend-design | anthropics/claude-code | `3bd61ba` | 2026-03-26 |
| gog-cli | intellectronica/agent-skills | `9133282` | 2026-03-26 |

## Local Skills（自作 — ~/.claude/skills/ 直接配置）

| スキル | カテゴリ |
|--------|---------|
| be-extension-pattern | アーキテクチャ |
| capture-improvement | ワークフロー |
| codebase-investigation | 調査 |
| config-placement-guide | 設定 |
| data-visualization | データ |
| debugging-guide | デバッグ |
| execution-patterns | ワークフロー |
| fe-be-extension-coordination | アーキテクチャ |
| fe-extension-pattern | アーキテクチャ |
| fetch-bookmarks | データ収集 |
| git-safety-reference | セキュリティ |
| implementation-checklist | ワークフロー |
| max-scroll-scrape | データ収集 |
| notification-alert | システム |
| opponent-review | レビュー |
| organize-desktop | ユーティリティ |
| project-bootstrap | プロジェクト管理 |
| project-recall | プロジェクト管理 |
| refactoring-guide | コード品質 |
| refactoring-safety | コード品質 |
| retitle-product | ビジネス |
| sales-analysis | データ |
| salesmtg-dashboard-qa | ビジネス |
| salesmtg-data-audit | ビジネス |
| secret-management | セキュリティ |
| security-twin-audit | セキュリティ |
| skill-creator | メタ |
| skill-lifecycle-reference | メタ |
| task-planner | ワークフロー |
| task-progress | ワークフロー |
| test-fixing | テスト |
| tool-selection-reference | ワークフロー |

## 更新手順

```bash
# 全外部スキルを最新に更新
npx skills update -g

# 特定スキルのみ更新
npx skills update <skill-name> -g

# ハッシュ確認（lock file）
cat ~/.agents/.skill-lock.json | jq '.skills.<name>.skillFolderHash'
```
