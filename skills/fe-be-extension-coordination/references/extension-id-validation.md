fe-be-extension-coordination の詳細（本文から 2026-07-11 P8 分離・内容不変）

## 3. 一貫したExtension ID

### 命名規則

| 項目 | ルール | 例 |
|------|--------|-----|
| Extension ID | kebab-case | `user-management` |
| FE ディレクトリ | kebab-case | `extensions/user-management/` |
| BE ディレクトリ (Python) | snake_case | `extensions/user_management/` |
| BE ディレクトリ (Node.js) | kebab-case | `extensions/user-management/` |
| API prefix | kebab-case | `/api/user-management/` |
| Event prefix | kebab-case + colon | `user:created` |
| DB table prefix | snake_case | `ext_user_management_*` |
| EXTENSION_IDS key | UPPER_SNAKE_CASE | `USER_MANAGEMENT` |

### CI検証スクリプト

```typescript
// scripts/validate-extension-ids.ts
import { EXTENSION_IDS } from 'extension-contracts';
import fs from 'fs';
import yaml from 'js-yaml';

// 1. FE extensions check
const feExtensions = fs.readdirSync('fe-repo/src/extensions');
// 2. BE extensions check
const beExtensions = fs.readdirSync('be-repo/src/extensions');
// 3. extensions.yaml check
const config = yaml.load(
  fs.readFileSync('extension-contracts/src/extensions.yaml', 'utf8')
);

const ids = Object.values(EXTENSION_IDS);

for (const id of ids) {
  const ext = config.extensions.find((e: any) => e.id === id);
  if (!ext) {
    console.error(`Missing in extensions.yaml: ${id}`);
    process.exit(1);
  }
  if (ext.fe && !feExtensions.includes(id)) {
    console.error(`FE directory missing for: ${id}`);
    process.exit(1);
  }
  // Python BE uses snake_case
  const beDir = id.replace(/-/g, '_');
  if (ext.be && !beExtensions.includes(id) && !beExtensions.includes(beDir)) {
    console.error(`BE directory missing for: ${id}`);
    process.exit(1);
  }
}
console.log('All extension IDs are consistent!');
```
