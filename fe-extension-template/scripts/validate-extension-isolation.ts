/**
 * Scans all extension source files and validates import isolation.
 * - @/core imports: OK
 * - @/shared/* imports: OK
 * - ../extensions/other-ext or @/extensions/other-ext: ERROR
 * - Relative paths crossing extension boundaries: ERROR
 *
 * Usage: npx ts-node scripts/validate-extension-isolation.ts
 */
import * as fs from 'fs';
import * as path from 'path';

const ROOT = path.resolve(__dirname, '..');
const EXTENSIONS_DIR = path.join(ROOT, 'src', 'extensions');

interface Violation {
  file: string;
  line: number;
  importPath: string;
  reason: string;
}

function getSourceFiles(dir: string): string[] {
  const files: string[] = [];
  if (!fs.existsSync(dir)) return files;

  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...getSourceFiles(fullPath));
    } else if (/\.(ts|tsx)$/.test(entry.name)) {
      files.push(fullPath);
    }
  }
  return files;
}

function extractImports(content: string): Array<{ line: number; importPath: string }> {
  const results: Array<{ line: number; importPath: string }> = [];
  const lines = content.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const match = lines[i].match(/(?:import|from)\s+['"]([^'"]+)['"]/);
    if (match) {
      results.push({ line: i + 1, importPath: match[1] });
    }
    const dynamicMatch = lines[i].match(/import\(['"]([^'"]+)['"]\)/);
    if (dynamicMatch) {
      results.push({ line: i + 1, importPath: dynamicMatch[1] });
    }
  }
  return results;
}

function main(): void {
  if (!fs.existsSync(EXTENSIONS_DIR)) {
    console.log('No extensions directory found.');
    process.exit(0);
  }

  const extDirs = fs.readdirSync(EXTENSIONS_DIR, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => d.name);

  const violations: Violation[] = [];

  for (const ext of extDirs) {
    const extDir = path.join(EXTENSIONS_DIR, ext);
    const files = getSourceFiles(extDir);

    for (const file of files) {
      const content = fs.readFileSync(file, 'utf-8');
      const imports = extractImports(content);
      const relativeFile = path.relative(ROOT, file);

      for (const { line, importPath } of imports) {
        // Check for direct reference to other extensions via path alias
        for (const other of extDirs) {
          if (other === ext) continue;
          if (importPath.includes(`extensions/${other}`)) {
            violations.push({
              file: relativeFile,
              line,
              importPath,
              reason: `Cross-extension import to "${other}" detected.`,
            });
          }
        }

        // Check relative imports that escape extension boundary
        if (importPath.startsWith('..')) {
          const resolved = path.resolve(path.dirname(file), importPath);
          const resolvedRelative = path.relative(EXTENSIONS_DIR, resolved);
          const targetExt = resolvedRelative.split(path.sep)[0];
          if (targetExt !== ext && extDirs.includes(targetExt)) {
            violations.push({
              file: relativeFile,
              line,
              importPath,
              reason: `Relative import crosses into extension "${targetExt}".`,
            });
          }
        }
      }
    }
  }

  if (violations.length > 0) {
    console.error('Extension isolation violations found:\n');
    for (const v of violations) {
      console.error(`  ${v.file}:${v.line}`);
      console.error(`    Import: ${v.importPath}`);
      console.error(`    Reason: ${v.reason}\n`);
    }
    process.exit(1);
  }

  console.log(`All ${extDirs.length} extension(s) passed isolation check.`);
}

main();
