/**
 * Scans src/extensions/ directories and generates import/no-restricted-paths zones
 * for ESLint configuration.
 *
 * Usage: npx ts-node scripts/generate-eslint-zones.ts
 */
import * as fs from 'fs';
import * as path from 'path';

const ROOT = path.resolve(__dirname, '..');
const EXTENSIONS_DIR = path.join(ROOT, 'src', 'extensions');

interface Zone {
  target: string;
  from: string;
  message: string;
}

function main(): void {
  if (!fs.existsSync(EXTENSIONS_DIR)) {
    console.log('No extensions directory found. Skipping.');
    return;
  }

  const extDirs = fs.readdirSync(EXTENSIONS_DIR, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => d.name);

  const zones: Zone[] = [];

  for (const ext of extDirs) {
    const otherExts = extDirs.filter(other => other !== ext);
    for (const other of otherExts) {
      zones.push({
        target: `./src/extensions/${ext}/**/*`,
        from: `./src/extensions/${other}`,
        message: `Extension "${ext}" must not import from extension "${other}". Extensions must be isolated.`,
      });
    }
  }

  const output = JSON.stringify(zones, null, 2);
  const outputPath = path.join(ROOT, 'config', 'eslint-zones.generated.json');
  fs.writeFileSync(outputPath, output, 'utf-8');
  console.log(`Generated ${outputPath} with ${zones.length} zone rule(s) for ${extDirs.length} extension(s).`);
}

main();
