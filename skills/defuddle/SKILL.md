---
name: defuddle
description: >-
  Defuddle CLIでWebページ本文をクリーンなmarkdown抽出（WebFetch代替・省トークン）。URL読取・記事・ブログ・docsに。
  NOT for: .md終わりURL→WebFetch。Triggers(kepano-obsidian-skills bundle): obsidian-skillsを使って,obsidian-skills,URLを読んで,記事を取り込んで,記事を抽出,ブログを取得,ウェブページをきれいに,Webページから本文だけ,ノイズ除去,defuddle
---

# Defuddle

## 発火・詳細（description から移設 2026-07-03）

Extract clean markdown content from web pages using Defuddle CLI, removing clutter and navigation to save tokens. Use instead of WebFetch when the user provides a URL to read or analyze, for online documentation, articles, blog posts, or any standard web page. Do NOT use for URLs ending in .md — those are already markdown, use WebFetch directly. Triggers on (kepano-obsidian-skills bundle): 「obsidian-skills を使って」「obsidian-skills」「URL を読んで」「記事を取り込んで」「記事を抽出」「ブログを取得」「ウェブページをきれいに」「Webページから本文だけ」「ノイズ除去」「defuddle」.

Use Defuddle CLI to extract clean readable content from web pages. Prefer over WebFetch for standard web pages — it removes navigation, ads, and clutter, reducing token usage.

If not installed: `npm install -g defuddle`

## Usage

Always use `--md` for markdown output:

```bash
defuddle parse <url> --md
```

Save to file:

```bash
defuddle parse <url> --md -o content.md
```

Extract specific metadata:

```bash
defuddle parse <url> -p title
defuddle parse <url> -p description
defuddle parse <url> -p domain
```

## Output formats

| Flag | Format |
|------|--------|
| `--md` | Markdown (default choice) |
| `--json` | JSON with both HTML and markdown |
| (none) | HTML |
| `-p <name>` | Specific metadata property |
