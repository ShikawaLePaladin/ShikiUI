// check_locale : coherence des traductions de ShikiUI (socle + un fichier Locale_<Nom>.lua par module).
//  - memes cles en fr et en en, dans chaque fichier ; memes marqueurs de format (%s %d %.1f ...) dans le meme ordre ;
//  - aucune cle definie deux fois (noyau ou autre module) : SUI.AddStrings ne remplace jamais, la 2e serait perdue ;
//  - chaque module reste dans SON espace de noms : opt.<nom>.* tip.<nom>.* choice.<nom>.* msg.<nom>.* mod.<nom>.* help.<nom>*
//    cat.<nom> opt.modules.<nom> tip.modules.<nom> (deux agents ne peuvent donc pas se marcher dessus) ;
//  - chaque Mod_<Nom>.lua definit au moins opt.modules.<nom> et tip.modules.<nom> ;
//  - toute chaine litterale ressemblant a une cle ("msg.xxx", "opt.xxx"...) dans les sources existe, et un module ne reference
//    que ses propres cles ou celles du socle ;
//  - le modele docs\template\ est controle comme un module de nom "template".
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');
const dir = path.join(root, 'ShikiUI');
const tdir = path.join(root, 'docs', 'template');
let bad = 0;
const err = (s) => { console.log('  ' + s); bad++; };

// Lit les blocs de textes d'un fichier : { fr: {cle: texte}, en: {...} }. Deux formes :
//   Locale.lua :       "\tfr = {"  ...  "\t},"          entrees a 2 tabulations
//   Locale_<Nom>.lua : SUI.AddStrings("fr", {  ...  })  entrees a 1 tabulation
function parse(file, label) {
  const lines = fs.readFileSync(file, 'latin1').split(/\r?\n/);
  const langs = { fr: {}, en: {} };
  let cur = null, entry = null;
  for (const line of lines) {
    let m = line.match(/^\t(fr|en) = \{\s*$/);
    if (m) { cur = m[1]; entry = /^\t\t\["/; continue; }
    m = line.match(/^(?:ShikiUI|SUI)\.AddStrings\("(fr|en)", \{\s*$/);
    if (m) { cur = m[1]; entry = /^\t\["/; continue; }
    if (cur && (/^\t\},?\s*$/.test(line) || /^\}\)\s*$/.test(line))) { cur = null; continue; }
    m = line.match(/^\t{1,2}\["([^"]+)"\]\s*=\s*"((?:[^"\\]|\\.)*)",?\s*$/);
    if (m && cur && entry.test(line)) {
      if (langs[cur][m[1]] !== undefined) err(`${label}: cle en double (${cur}) : ${m[1]}`);
      langs[cur][m[1]] = m[2];
    } else if (cur && /\[".*"\]\s*=/.test(line)) {
      err(`${label}: ligne de texte illisible (une entree par ligne, "cle" = "texte",) : ${line.trim().slice(0, 60)}`);
    }
  }
  return { fr: langs.fr, en: langs.en };
}

const fmts = (s) => (s.match(/%[-+ 0#]*\d*(\.\d+)?[sdfgxc]/g) || []).join(' ');
function parity(label, t) {
  for (const k of Object.keys(t.fr)) if (!(k in t.en)) err(`${label}: manque en en : ${k}`);
  for (const k of Object.keys(t.en)) if (!(k in t.fr)) err(`${label}: manque en fr : ${k}`);
  for (const k of Object.keys(t.fr)) {
    if (k in t.en && fmts(t.fr[k]) !== fmts(t.en[k])) err(`${label}: formats differents pour ${k} : "${fmts(t.fr[k])}" / "${fmts(t.en[k])}"`);
    if (t.fr[k].trim() === '') err(`${label}: texte vide (fr) : ${k}`);
  }
  for (const k of Object.keys(t.en)) if (t.en[k].trim() === '') err(`${label}: texte vide (en) : ${k}`);
}

const nsOk = (n, k) => new RegExp(`^((opt|tip|choice|msg|mod)\\.${n}(\\.|$)|help\\.${n}(\\.|$)|cat\\.${n}$|(opt|tip)\\.modules\\.${n}$)`).test(k);

// ---- socle
const core = parse(path.join(dir, 'Locale.lua'), 'Locale.lua');
const coreFiles = fs.readdirSync(dir).filter(f => /^Locale_.+\.lua$/.test(f));
const modFiles = fs.readdirSync(dir).filter(f => /^Mod_.+\.lua$/.test(f));
const modNames = modFiles.map(f => f.replace(/^Mod_(.+)\.lua$/, '$1'));
const coreNames = ['Mode', 'Target', 'Style', 'Layout', 'Menu', 'Preview', 'Mover', 'Bind', 'Addons', 'Setup', 'Visibility'];     // sous-systemes du socle qui ont leur Locale_<Nom>.lua sans Mod_<Nom>.lua
parity('Locale.lua', core);
const owner = { fr: {}, en: {} };           // cle -> fichier qui la definit
for (const lang of ['fr', 'en']) for (const k of Object.keys(core[lang])) owner[lang][k] = 'Locale.lua';
const perFile = {};
function addFile(label, file, name, isModule) {
  const t = parse(file, label);
  perFile[label] = t;
  parity(label, t);
  const n = name.toLowerCase();
  for (const lang of ['fr', 'en']) {
    for (const k of Object.keys(t[lang])) {
      if (owner[lang][k]) err(`${label}: cle deja definie dans ${owner[lang][k]} (${lang}) : ${k}`);
      else owner[lang][k] = label;
      if (!nsOk(n, k)) err(`${label}: cle hors de l'espace de noms "${n}" : ${k}`);
    }
  }
  if (isModule) {
    for (const k of [`opt.modules.${n}`, `tip.modules.${n}`]) if (!(k in t.fr)) err(`${label}: cle obligatoire absente : ${k}`);
  }
}
for (const f of coreFiles) {
  const name = f.replace(/^Locale_(.+)\.lua$/, '$1');
  const isCore = coreNames.includes(name);
  if (!isCore && !modNames.includes(name)) { err(`${f}: pas de Mod_${name}.lua correspondant`); continue; }
  addFile(f, path.join(dir, f), name, !isCore);
}
for (const n of modNames) if (!fs.existsSync(path.join(dir, `Locale_${n}.lua`))) err(`Mod_${n}.lua: Locale_${n}.lua manque`);
// styles : Style_<Nom>.lua porte ses propres textes, uniquement style.<nom>.label et style.<nom>.desc (obligatoires)
const styleFiles = fs.readdirSync(dir).filter(f => /^Style_.+\.lua$/.test(f));
for (const f of styleFiles) {
  const n = f.replace(/^Style_(.+)\.lua$/, '$1').toLowerCase();
  const t = parse(path.join(dir, f), f);
  parity(f, t);
  for (const lang of ['fr', 'en']) {
    for (const k of Object.keys(t[lang])) {
      if (owner[lang][k]) err(`${f}: cle deja definie dans ${owner[lang][k]} (${lang}) : ${k}`);
      else owner[lang][k] = f;
      if (k !== `style.${n}.label` && k !== `style.${n}.desc`) err(`${f}: cle hors de style.${n}.(label|desc) : ${k}`);
    }
  }
  for (const k of [`style.${n}.label`, `style.${n}.desc`]) if (!(k in t.fr)) err(`${f}: cle obligatoire absente : ${k}`);
}
// modele
if (fs.existsSync(path.join(tdir, 'Locale_Template.lua'))) addFile('docs/template/Locale_Template.lua', path.join(tdir, 'Locale_Template.lua'), 'template', true);

const total = (o) => Object.keys(o).length;
console.log(`fr : ${total(owner.fr)} cles, en : ${total(owner.en)} cles (${coreFiles.length} fichier(s) Locale_*, ${modNames.length} module(s))`);

// ---- cles utilisees dans les sources
const KEY = /^(msg|help|menu|transfer|wiz|cat|role|unit|perf|status|opt|tip|choice|profile|mod)\.[A-Za-z0-9_.]+$/;
// chaines qui ressemblent a des cles de traduction sans en etre : cles de config, noms de minuterie, prefixes de concatenation
const NOT_KEYS = new Set(['perf.hud', 'perf.auto', 'perf.autofps', 'perf.sample', 'opt.modules.', 'tip.modules.', 'mod.mode.name.', 'mod.mode.cost.', 'unit.player', 'unit.target', 'unit.targettarget']);
const used = new Set();
function scan(file, label, ownName) {
  const src = fs.readFileSync(file, 'latin1').split(/\r?\n/).filter(l => !/^\s*--/.test(l)).join('\n');
  const re = /"((?:[^"\\\n]|\\.)*)"/g;
  let m;
  while ((m = re.exec(src))) {
    const k = m[1];
    if (!KEY.test(k) || NOT_KEYS.has(k) || /\.$/.test(k)) continue;
    used.add(k);
    if (!(k in owner.fr)) err(`${label}: cle absente des fichiers de traduction : ${k}`);
    else if (ownName && owner.fr[k] !== 'Locale.lua' && !/^(Locale_(Mode|Target|Style|Layout|Menu|Preview|Mover|Bind|Addons|Visibility)|Style_[A-Za-z0-9]+)\.lua$/.test(owner.fr[k]) && !nsOk(ownName, k)) {
      err(`${label}: utilise une cle d'un autre module (${owner.fr[k]}) : ${k}`);
    }
  }
}
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.lua') && !/^Locale/.test(f))) {
  const m = f.match(/^Mod_(.+)\.lua$/);
  scan(path.join(dir, f), f, m ? m[1].toLowerCase() : null);
}
if (fs.existsSync(path.join(tdir, 'Mod_Template.lua'))) scan(path.join(tdir, 'Mod_Template.lua'), 'docs/template/Mod_Template.lua', 'template');
const unused = Object.keys(owner.fr).filter(k => !used.has(k) && !/^(help\.\d+|role\.|cat\.|opt\.|tip\.|choice\.|mod\.|msg\.[a-z]+\.)/.test(k));
if (unused.length) console.log('  (information) cles non referencees litteralement : ' + unused.join(', '));
console.log(bad ? `${bad} probleme(s) de traduction` : 'TRADUCTIONS OK');
process.exit(bad ? 1 : 0);
