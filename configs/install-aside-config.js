const fs = require('fs');
const path = require('path');

const userProfile = process.env.USERPROFILE;
const sourcePath = path.resolve(__dirname, 'aside-models.json');
if (!fs.existsSync(sourcePath)) {
  console.error(`Source file not found: ${sourcePath}`);
  process.exit(1);
}

const sourceConfig = JSON.parse(fs.readFileSync(sourcePath, 'utf8').replace(/^\uFEFF/, ''));
const providerKey = 'gemini-web';
const sourceProvider = sourceConfig.providers[providerKey];

const accounts = ['0', '1', '2', '3'];
const now = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);

for (const u of accounts) {
  const targetDir = path.join(userProfile, '.aside', 'u', u);
  const targetPath = path.join(targetDir, 'models.json');
  if (!fs.existsSync(targetPath)) continue;

  const backupPath = `${targetPath}.bak-geminiweb-${now}`;
  fs.copyFileSync(targetPath, backupPath);

  const rawTarget = fs.readFileSync(targetPath, 'utf8').replace(/^\uFEFF/, '');
  const targetConfig = JSON.parse(rawTarget);
  if (!targetConfig.providers) targetConfig.providers = {};
  targetConfig.providers[providerKey] = sourceProvider;

  fs.writeFileSync(targetPath, JSON.stringify(targetConfig, null, 2), { encoding: 'utf8' });
  console.log(`[Aside u/${u}] Registered provider '${providerKey}' (${sourceProvider.models.length} models) -> ${targetPath}`);
}
