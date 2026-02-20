# 要素検知カタログ

> web-form-detector スキルのリファレンス。
> セレクタパターンの詳細一覧。

---

## 要素検知カタログ

### 1. ボタン系

#### 送信ボタン

```javascript
const submitButtons = await page.locator([
  'input[type="submit"]',
  'button[type="submit"]',
  'button:has-text("送信")',
  'button:has-text("登録")',
  'button:has-text("確定")',
  'button:has-text("Submit")',
  'button:has-text("Save")'
].join(', ')).all();
```

#### 通常ボタン

```javascript
const buttons = await page.locator([
  'button:not([type="submit"])',
  'input[type="button"]',
  '[role="button"]',
  '.btn',
  '.button'
].join(', ')).all();
```

#### リンクボタン（ボタン風リンク）

```javascript
const linkButtons = await page.locator([
  'a.btn',
  'a.button',
  'a[role="button"]',
  'a:has-text("ダウンロード")',
  'a:has-text("詳細")',
  'a:has-text("編集")',
  'a:has-text("削除")'
].join(', ')).all();
```

#### アイコンボタン

```javascript
const iconButtons = await page.locator([
  'button:has(svg)',
  'button:has(i.fa)',
  'button:has(i.icon)',
  '[class*="icon-button"]',
  '[aria-label]:not(:has-text(.))'  // テキストなしでaria-labelあり
].join(', ')).all();
```

#### トグルボタン・スイッチ

```javascript
const toggles = await page.locator([
  '[role="switch"]',
  'input[type="checkbox"][role="switch"]',
  '.toggle',
  '.switch'
].join(', ')).all();
```

---

### 2. 入力系

#### テキスト入力

```javascript
const textInputs = await page.locator([
  'input[type="text"]',
  'input[type="email"]',
  'input[type="tel"]',
  'input[type="url"]',
  'input[type="search"]',
  'input:not([type])',  // type未指定はtext扱い
  'textarea'
].join(', ')).all();
```

#### パスワード入力

```javascript
const passwordInputs = await page.locator('input[type="password"]').all();
```

#### 数値入力

```javascript
const numberInputs = await page.locator([
  'input[type="number"]',
  'input[type="range"]'
].join(', ')).all();
```

#### 日付・時刻入力

```javascript
const dateInputs = await page.locator([
  'input[type="date"]',
  'input[type="time"]',
  'input[type="datetime-local"]',
  'input[type="month"]',
  'input[type="week"]',
  '[class*="datepicker"]',
  '[class*="calendar"]'
].join(', ')).all();
```

#### ファイル入力

```javascript
const fileInputs = await page.locator('input[type="file"]').all();
// accepts属性で対応ファイル形式を確認
const accepts = await fileInputs[0]?.getAttribute('accept');
```

---

### 3. 選択系

#### チェックボックス

```javascript
const checkboxes = await page.locator([
  'input[type="checkbox"]',
  '[role="checkbox"]'
].join(', ')).all();
```

#### ラジオボタン

```javascript
const radios = await page.locator([
  'input[type="radio"]',
  '[role="radio"]'
].join(', ')).all();
```

#### ドロップダウン（セレクト）

```javascript
const selects = await page.locator('select').all();

// オプション取得
for (const select of selects) {
  const options = await select.locator('option').allTextContents();
  const selected = await select.locator('option:checked').textContent();
}
```

#### カスタムドロップダウン

```javascript
const customSelects = await page.locator([
  '[role="listbox"]',
  '[role="combobox"]',
  '.dropdown',
  '.select2',
  '[class*="dropdown"]'
].join(', ')).all();
```

#### オートコンプリート

```javascript
const autocomplete = await page.locator([
  'input[list]',
  '[role="combobox"][aria-autocomplete]',
  '.autocomplete',
  '[class*="typeahead"]'
].join(', ')).all();
```

---

### 4. ナビゲーション系

#### リンク

```javascript
const links = await page.locator('a[href]').all();

// 外部リンク
const externalLinks = await page.locator('a[target="_blank"]').all();

// ダウンロードリンク
const downloadLinks = await page.locator('a[download]').all();
```

#### タブ

```javascript
const tabs = await page.locator([
  '[role="tab"]',
  '.tab',
  '.nav-tab',
  '[class*="tab-item"]'
].join(', ')).all();
```

#### メニュー

```javascript
const menus = await page.locator([
  '[role="menu"]',
  '[role="menubar"]',
  'nav',
  '.menu',
  '.navbar'
].join(', ')).all();

// メニュー項目
const menuItems = await page.locator('[role="menuitem"]').all();
```

#### ページネーション

```javascript
const pagination = await page.locator([
  '.pagination',
  '[role="navigation"] a',
  'a:has-text("次へ")',
  'a:has-text("前へ")',
  'a:has-text("Next")',
  'a:has-text("Prev")'
].join(', ')).all();
```

---

### 5. モーダル・ダイアログ系

#### モーダル

```javascript
const modals = await page.locator([
  '[role="dialog"]',
  '.modal',
  '.dialog',
  '[class*="modal"]'
].join(', ')).all();
```

#### アラート

```javascript
const alerts = await page.locator([
  '[role="alert"]',
  '.alert',
  '.notification',
  '.toast'
].join(', ')).all();
```

#### 確認ダイアログ

```javascript
// ブラウザネイティブダイアログ
page.on('dialog', async dialog => {
  console.log(dialog.type());  // alert, confirm, prompt
  console.log(dialog.message());
  await dialog.accept();  // or dialog.dismiss()
});
```

---

### 6. 特殊要素

#### 非表示の要素

```javascript
// 隠れているが存在する要素
const hidden = await page.locator('[style*="display: none"], [hidden], .hidden').all();

// 表示させてからクリック
await page.locator('.hidden-menu').evaluate(el => el.style.display = 'block');
```

#### iframeの要素

```javascript
// iframe内の要素にアクセス
const frame = page.frameLocator('iframe#content');
const button = frame.locator('button');
await button.click();
```

#### Shadow DOM

```javascript
// Shadow DOM内の要素
const shadowHost = page.locator('custom-element');
const shadowButton = shadowHost.locator('button');  // Playwright自動対応
```

#### 動的生成要素

```javascript
// 要素が出現するまで待機
await page.waitForSelector('.dynamic-content', { state: 'visible' });

// または特定のテキストが出現するまで
await page.waitForSelector('text=読み込み完了');
```

---

## 検知結果フォーマット

```javascript
{
  url: "http://example.com/page",
  timestamp: "2026-01-22T11:00:00",
  elements: {
    buttons: {
      submit: [
        { ref: "e10", text: "送信", type: "submit" }
      ],
      normal: [
        { ref: "e11", text: "キャンセル", class: "btn-secondary" }
      ],
      icon: [
        { ref: "e12", ariaLabel: "閉じる", hasIcon: true }
      ]
    },
    inputs: {
      text: [
        { ref: "e20", name: "title", placeholder: "タイトル" }
      ],
      file: [
        { ref: "e21", accepts: ".csv,.xlsx" }
      ],
      date: [
        { ref: "e22", name: "publish_date" }
      ]
    },
    selects: [
      { ref: "e30", name: "category", optionCount: 10 }
    ],
    links: {
      download: [
        { ref: "e40", text: "CSVダウンロード", href: "#" }
      ],
      navigation: [
        { ref: "e41", text: "次のページ" }
      ]
    }
  },
  summary: {
    totalInteractive: 15,
    forms: 1,
    clickable: 8,
    fillable: 5
  }
}
```

---

## 多要素タイプ一括入力パターン

### 問題

フォームフィールドのHTML要素タイプが不明な場合がある：
- `guide` → `input`か`textarea`か不明
- `affinity` → `input`か`select`か不明

### 解決策：全要素タイプを順番に検索

```javascript
// page.evaluate用 - 全フィールドを一括入力
const result = await page.evaluate((fields) => {
    let filled = 0;
    let notFound = [];

    for (const [name, value] of Object.entries(fields)) {
        // input → textarea → select の順に検索
        let element = document.querySelector(`input[name='${name}']`);
        if (!element) {
            element = document.querySelector(`textarea[name='${name}']`);
        }
        if (!element) {
            element = document.querySelector(`select[name='${name}']`);
        }

        if (element) {
            element.value = value;
            element.dispatchEvent(new Event('input', { bubbles: true }));
            element.dispatchEvent(new Event('change', { bubbles: true }));
            filled++;
        } else {
            notFound.push(name);
        }
    }
    return { filled, notFound };
}, fieldsToFill);

// 結果を検証
if (result.notFound.length > 0) {
    console.warn(`入力失敗: ${result.notFound.join(', ')}`);
}
```

### フォーム構造の事前調査

```javascript
// 入力前にフォームの全フィールドを調査
const formStructure = await page.evaluate(() => {
    const result = { inputs: [], textareas: [], selects: [] };

    document.querySelectorAll('input[name]').forEach(el => {
        result.inputs.push({
            name: el.name,
            type: el.type,
            value: el.value.substring(0, 50)
        });
    });

    document.querySelectorAll('textarea[name]').forEach(el => {
        result.textareas.push({
            name: el.name,
            value: el.value.substring(0, 50)
        });
    });

    document.querySelectorAll('select[name]').forEach(el => {
        result.selects.push({
            name: el.name,
            value: el.value
        });
    });

    return result;
});

console.log('INPUT:', formStructure.inputs.map(i => i.name));
console.log('TEXTAREA:', formStructure.textareas.map(t => t.name));
console.log('SELECT:', formStructure.selects.map(s => s.name));
```
