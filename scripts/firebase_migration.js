/**
 * Firebase -> REST migration helper script
 */
const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const DART_SRC_ROOT = path.join(PROJECT_ROOT, 'request', 'lib');

const firebaseImportPatterns = [
  /import\s+['\"]package:firebase_auth\/firebase_auth.dart['\"];?/g,
  /import\s+['\"]package:cloud_firestore\/cloud_firestore.dart['\"];?/g,
  /import\s+['\"]package:firebase_core\/firebase_core.dart['\"];?/g,
  /import\s+['\"]package:firebase_messaging\/firebase_messaging.dart['\"];?/g,
];
const authCurrentUserPattern = /FirebaseAuth\.instance\.currentUser/g;
const firestoreInstancePattern = /FirebaseFirestore\.instance/g;

let filesScanned = 0, filesModified = 0, replacements = 0;

function walk(dir, acc = []) {
  if (!fs.existsSync(dir)) return acc;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (["build", ".dart_tool"].includes(entry.name)) continue;
      walk(full, acc);
    } else if (entry.isFile() && entry.name.endsWith('.dart')) acc.push(full);
  }
  return acc;
}

function ensureShimImported(content) {
  if (content.includes('firebase_shim.dart')) return content;
  const importBlock = content.match(/(import[^;]+;\s*)+/);
  if (importBlock) {
    const idx = importBlock.index + importBlock[0].length;
    return content.slice(0, idx) + "import 'src/utils/firebase_shim.dart'; // Added by migration script\n" + content.slice(idx);
  }
  return "import 'src/utils/firebase_shim.dart'; // Added by migration script\n" + content;
}

function annotateFirestoreQueries(text) {
  const lines = text.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes('FirebaseFirestore.instance') && !lines[i].includes('FIRESTORE_TODO')) {
      lines[i] = `// FIRESTORE_TODO: replace with REST service. Original: ${lines[i].trim()}\n${lines[i]}`;
    }
  }
  return lines.join('\n');
}

function processFile(file) {
  let content = fs.readFileSync(file, 'utf8');
  const original = content; let modified = false;

  firebaseImportPatterns.forEach(p => {
    if (p.test(content)) {
      content = content.replace(p, m => { modified = true; replacements++; return `// REMOVED_FB_IMPORT: ${m}`; });
    }
  });

  if (authCurrentUserPattern.test(content)) {
    content = content.replace(authCurrentUserPattern, () => { modified = true; replacements++; return 'RestAuthService.instance.currentUser'; });
  }

  if (firestoreInstancePattern.test(content)) { content = annotateFirestoreQueries(content); modified = true; }

  if (modified && original !== content && !content.includes('firebase_shim.dart')) {
    content = ensureShimImported(content);
  }

  if (modified && original !== content) {
    const backup = file + '.fbmig.bak';
    if (!fs.existsSync(backup)) fs.writeFileSync(backup, original, 'utf8');
    fs.writeFileSync(file, content, 'utf8');
    filesModified++; console.log('✔ Migrated:', path.relative(PROJECT_ROOT, file));
  }
  filesScanned++;
}

function main() {
  console.log('Starting Firebase migration pass...');
  const dartFiles = walk(DART_SRC_ROOT);
  dartFiles.forEach(processFile);
  console.log('\n==== Migration Summary ====');
  console.log('Files scanned     :', filesScanned);
  console.log('Files modified    :', filesModified);
  console.log('Replacements made :', replacements);
  console.log('\nNext: implement REST services for TODO blocks, then remove shim.');
}
main();
