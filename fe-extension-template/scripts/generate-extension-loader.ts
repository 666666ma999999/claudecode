/**
 * Reads config/extensions.json and generates src/core/registry/load-extensions.ts
 * with static imports for all enabled extensions.
 *
 * Usage: npx ts-node scripts/generate-extension-loader.ts
 */
import * as fs from 'fs';
import * as path from 'path';

const ROOT = path.resolve(__dirname, '..');
const CONFIG_PATH = path.join(ROOT, 'config', 'extensions.json');
const OUTPUT_PATH = path.join(ROOT, 'src', 'core', 'registry', 'load-extensions.ts');

interface ExtensionsConfig {
  enabled: string[];
}

function main(): void {
  const raw = fs.readFileSync(CONFIG_PATH, 'utf-8');
  const config: ExtensionsConfig = JSON.parse(raw);

  const imports = config.enabled
    .map((id, i) => `import ext${i} from '../../extensions/${id}';`)
    .join('\n');

  const entries = config.enabled
    .map((_, i) => `  ext${i},`)
    .join('\n');

  const output = `// THIS FILE IS AUTO-GENERATED. DO NOT EDIT.
// Run \`scripts/generate-extension-loader.ts\` to regenerate.
import type { ExtensionManifest } from '../types';
${imports}

const manifests: ExtensionManifest[] = [
${entries}
];

export function loadExtensions(): ExtensionManifest[] {
  return manifests;
}
`;

  fs.writeFileSync(OUTPUT_PATH, output, 'utf-8');
  console.log(`Generated ${OUTPUT_PATH} with ${config.enabled.length} extension(s).`);
}

main();
