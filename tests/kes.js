const fs = require('fs'), os = require('os'), path = require('path'), { spawnSync } = require('child_process');
const muts = require('C:/Temp/ccx/shikiui_work/tests/mutations/esport.js');
let surv = 0, total = 0;
for (const [f, from, to, label] of muts) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kes-'));
  fs.cpSync('../ShikiUI', path.join(dir, 'ShikiUI'), { recursive: true });
  const fp = path.join(dir, 'ShikiUI', 'Mod_Esport.lua');
  let s = fs.readFileSync(fp, 'utf8');
  fs.writeFileSync(fp, s.split(from).join(to));
  const r = spawnSync('node', ['harness.js', 't_esport.lua'], { env: Object.assign({}, process.env, { ADDON_DIR: path.join(dir, 'ShikiUI') }), encoding: 'utf8' });
  total++;
  if (r.status === 0) { surv++; console.log('SURVIT : ' + label); }
  fs.rmSync(dir, { recursive: true, force: true });
}
console.log(total + ' mutants, ' + surv + ' survivants');
