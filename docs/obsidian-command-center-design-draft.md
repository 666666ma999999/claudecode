# Claude Code + Obsidian Vault 連携アーキテクチャ設計（codex draft / 未承認）

## 1. アーキテクチャ全体図
**推奨案は「vault 正典・project 作業写し・外部同期」の3層**です。Claude Code は原則 `~/Desktop/prm/<name>/` で動き、`plan.md`/`tasks/*.md` は project に一時ミラーを持たせ、同期プロセスが vault へ反映します。これなら `cwd` 制約を破らず、vault を論理的 SSoT にできます。

```text
Obsidian Vault (SSoT)
  └─ projects/<slug>/COMMAND-CENTER/
       ├─ COMMAND-CENTER.md
       ├─ plan.md
       ├─ tasks/
       ├─ session/
       └─ links -> wiki/ specs

          ▲ pull/push (copy only, no symlink)
          │
      syncctl / hooks / watcher
          │
          ▼

Project Root (working mirror)
  ~/Desktop/prm/<slug>/
    ├─ plan.md
    ├─ tasks/
    ├─ .ccsync/
    │   ├─ state.json
    │   ├─ lock.json
    │   └─ COMMAND-CENTER.local.md
    └─ code/
```

**代替案**: Claude に vault 例外編集を許可する運用。実装は簡単ですが、`cwd` 制約と衝突しやすく、誤編集範囲も広がるので管理者モードに限定すべきです。

## 2. ディレクトリ設計
### vault
| パス | 用途 |
|---|---|
| `projects/<slug>/COMMAND-CENTER/COMMAND-CENTER.md` | 司令塔 |
| `projects/<slug>/COMMAND-CENTER/plan.md` | 正典 plan |
| `projects/<slug>/COMMAND-CENTER/tasks/*.md` | 正典 task |
| `projects/<slug>/COMMAND-CENTER/session/` | lock, sync state, handoff |
| `wiki/projects/<slug>/specs/` | 仕様 |
| `wiki/projects/<slug>/decisions/` | ADR/意思決定 |
| `wiki/shared/` | 横断知識 |
| `archive/legacy-wiki-142/` | 既存142件の凍結保管 |

### project
| パス | 用途 |
|---|---|
| `plan.md` | mirror |
| `tasks/*.md` | mirror |
| `.ccsync/state.json` | 最終 pull/push hash |
| `.ccsync/lock.json` | セッション所有者 |
| `.ccsync/COMMAND-CENTER.local.md` | 読み取り用 mirror |

**命名規約**: vault slug = repo 名と一致、task は `YYYYMMDD-<topic>.md`。

## 3. 同期方式
**推奨同期方向**: `vault -> project` を SessionStart 時に必須、`project -> vault` を task/plan 変更時に即時 push。
**競合解決**: 単純マージ禁止、単一 writer lease を採用します。

| 条件 | 動作 |
|---|---|
| lock なし | `pull` 実行可 |
| 自分の lock あり | `push` 可 |
| 他者 lock あり | project 側編集は可、vault 反映は拒否 |
| vault が pull 後に更新済み | `conflicts/<ts>-<file>.md` を vault に退避して停止 |

```bash
# syncctl pull <slug>
rsync -a --delete "$VAULT/projects/$SLUG/COMMAND-CENTER/tasks/" "$PROJ/tasks/"
cp "$VAULT/projects/$SLUG/COMMAND-CENTER/plan.md" "$PROJ/plan.md"
cp "$VAULT/projects/$SLUG/COMMAND-CENTER/COMMAND-CENTER.md" "$PROJ/.ccsync/COMMAND-CENTER.local.md"
```

```bash
# syncctl push <slug>
cp "$PROJ/plan.md" "$VAULT/projects/$SLUG/COMMAND-CENTER/plan.md"
rsync -a "$PROJ/tasks/" "$VAULT/projects/$SLUG/COMMAND-CENTER/tasks/"
```

## 4. COMMAND-CENTER 仕様
`COMMAND-CENTER.md` は「人が読むダッシュボード」で、plan/task そのものは別ファイルに分離します。

```md
---
project: salesmtg
repo: ~/Desktop/prm/salesmtg
canonical: ~/Documents/Obsidian Vault/projects/salesmtg/COMMAND-CENTER
status: active
active_task: 20260508-sync-redesign
last_sync_at: 2026-05-08T16:30:00+09:00
---

# COMMAND CENTER
## Mission
## Current Focus
## Session Start
## Active Links
- [[plan]]
- [[tasks/20260508-sync-redesign]]
- [[../../../wiki/projects/salesmtg/specs/api-overview]]

## Risks
## Next Switch Handoff
```

**SessionStart**: local mirror の `COMMAND-CENTER.local.md` を表示。現行の hardcoded 1件読込は廃止。
**切替**: `switch-project <slug>` で lock 切替、pull、local COMMAND-CENTER 更新。

## 5. 記憶層設計
| 層 | 保存先 | 保持内容 |
|---|---|---|
| 短期 | `tasks/*.md`, `session/` | handoff, blockers, 今日の進捗 |
| 中期 | `wiki/projects/<slug>/specs`, `decisions` | プロジェクト仕様、意思決定 |
| 長期 | `wiki/shared/` | 再利用知識、横断パターン |
| 最小メモリ | `MEMORY.md`, Memory MCP | ポインタ、運用 invariant のみ |

**判定フロー**:
- 次セッションだけ必要 → task
- このプロジェクトで継続参照 → `wiki/projects/<slug>/...`
- 他案件にも再利用 → `wiki/shared/`

## 6. ワークフロー
1. **新規立上げ**: `bootstrap-project <slug>` で vault COMMAND-CENTER 雛形、wiki/projects 配下、project mirror を生成。
2. **日常開発**: SessionStart で `pull` → `COMMAND-CENTER.local.md` 表示 → Claude は code + mirror 更新 → PostToolUse で `push`。
3. **切替**: 現 project を `handoff` 更新 → lock 解放 → 次 project を `pull`。
4. **知識蓄積**: task 完了時に `promote-knowledge` で task から wiki/specs or decisions へ昇格。
5. **完了**: task archive、COMMAND-CENTER `active_task` 更新。

## 7. ルール改訂提案
- `rules/05-plan-task-md.md`: 「project root は mirror、canonical は vault COMMAND-CENTER 配下」と明記。
- `rules/40-obsidian.md`: `wiki/`/`refs/` 二系統中心から「COMMAND-CENTER + centralized wiki」へ全面改訂。
- `CLAUDE.md`: `cwd 内のみ` を「Claude 自身は project root を主作業場、vault 書き込みは sync 経由が原則」に差し替え。
- 新規 `rules/41-vault-sync.md`: lock, conflict, hash, push/pull 手順。
- 新規 `rules/42-command-center.md`: frontmatter, required sections, switch protocol。
- 新規 `rules/43-knowledge-promotion.md`: task から wiki への昇格基準。

## 8. マイグレーション計画
| 対象 | 方針 |
|---|---|
| `report/salesmtg` | 先行パイロット。新構造を先に適用 |
| `wiki/` 142件 | `archive/legacy-wiki-142/` に凍結し、参照頻度上位だけ再配置 |
| `obsidian-now-done` | 新規投入停止。必要な証跡だけ `archive/evidence/` へ移管 |

1. `salesmtg` で 1週間運用し、hook と同期競合を検証。
2. 既存 142 件は一括移植しない。リンク集だけ作り、再利用時に昇格。
3. `refs/` は legacy 扱いで読み取り専用化。

## 9. 失敗モードと対策
| 失敗モード | 対策 |
|---|---|
| vault と project が分岐 | hash + lock + conflict copy |
| 別 project の司令塔を読む | slug 明示の `switch-project` のみ許可 |
| stale mirror で着手 | SessionStart `pull` を必須化 |
| lock 取りっぱなし | TTL 付き lock、期限切れは警告 |
| hook 過多で遅い | 「司令塔必須セット」と legacy を分離 |
| hardcoded 単一 COMMAND-CENTER | slug 解決型に置換 |
| Docker 実行文脈と仕様がずれる | COMMAND-CENTER に `docker compose` コマンドを固定記載 |

## 10. 成功基準
1. 任意の project で SessionStart 後 5 秒以内に正しい `COMMAND-CENTER.local.md` が表示される。
2. `plan.md`/`tasks/*.md` の vault-project 差分が通常運用で 0 件を維持する。
3. 他 project の COMMAND-CENTER を誤読したセッションが 0 件。
4. task 完了後 24 時間以内に wiki/specs or decisions へ知識昇格される率が 80% 以上。
5. `salesmtg` パイロットで lock conflict による手動復旧が週 1 回未満。
6. hook 実行時間の p95 が現状比 30% 以上悪化しない。
7. `MEMORY.md` が 50 行未満、実質ポインタ専用で維持される。
