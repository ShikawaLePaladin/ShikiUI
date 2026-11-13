// bench_builder : compare le panneau de statistiques de ShikiUI (module "charstats") au builder OctoFan de l'utilisateur.
//   node tests/bench_builder.js            compare (builder reel si trouve, sinon valeurs figees)
//   node tests/bench_builder.js --freeze   ecrit tests/bench_builder_frozen.json depuis le builder reel
//   node tests/bench_builder.js --emit-lua[=cas,cas] affiche des cas figes au format Lua
//   node tests/bench_builder.js --splice  reecrit le bloc FROZEN de tests/t_charstats.lua (cas figes depuis le builder reel)
// Fonctionnement : pour chaque jeu de valeurs (CASES), on appelle la VRAIE fonction computeCombatPanel du builder (extraite de
// builder\index.html et executee dans un contexte vm ; seules les lectures de base de donnees d'objets sont remplacees par les
// valeurs du cas) puis on fait tourner le module Lua dans le harnais avec les memes valeurs "lues en jeu", et on compare ligne a ligne
// (libelles sans accents, valeurs). Chemin du builder : variable BUILDER_HTML, sinon I:\2026 a\OctoFan\builder\index.html.
// Ecarts connus, ignores : la ligne "Forme (druide)" du builder (pas de cas druide), le "~" d'estimation en tete des valeurs.
const fs = require('fs');
const os = require('os');
const path = require('path');
const vm = require('vm');
const { spawnSync } = require('child_process');

const HERE = __dirname;
const FROZEN = path.join(HERE, 'bench_builder_frozen.json');
const HTML = process.env.BUILDER_HTML || 'I:\\2026 a\\OctoFan\\builder\\index.html';
const arg = process.argv[2] || '';

// ---------------------------------------------------------------- jeux de valeurs (valeurs "lues en jeu")
const base = {
  cls: 'PALADIN', lvl: 60, str: 120, agi: 90, sta: 160, int: 100, spi: 50, armor: 3000, ap: 240, rap: 0, crit: 5.5, rcrit: 0,
  skill: 300, oskill: 0, speed: 2.6, offSpeed: null, dmin: 100, dmax: 200, omin: 0, omax: 0, rspeed: 0, rmin: 0, rmax: 0, rskill: 0,
  hit: 0, shit: 0, spcrit: 0, sp: 0, heal: 0, mp5: 0, regenCast: 0, haste: 0, shield: false, blockFlat: 0, spen: 0, apen: 0,
  defense: 305, dodge: 5.5, parry: 6.25, block: 12, res: [10, 20, 30, 40, 50], hp: 5000, mana: 3000,
};
const mk = (name, o) => Object.assign({}, base, { name }, o);
const CASES = [
  mk('paladin_tank', { hit: 4, shield: true, blockFlat: 18, defense: 330, dodge: 7, parry: 9, block: 17, sp: 30, heal: 85, mp5: 6, spcrit: 1, shit: 1, regenCast: 15 }),
  mk('paladin_ret_2h', { hit: 7, skill: 305, crit: 12.4, ap: 1500, speed: 3.6, dmin: 300, dmax: 450, sp: 0, mp5: 0, haste: 2 }),
  mk('warrior_dual', { cls: 'WARRIOR', hit: 9, skill: 308, oskill: 302, crit: 21.3, speed: 2.6, offSpeed: 1.5, dmin: 250, dmax: 300, omin: 70, omax: 120,
    str: 300, agi: 150, sta: 350, int: 40, spi: 45, armor: 2200, ap: 1800, defense: 300, dodge: 6, parry: 6.5, block: 0, mana: 0, rspeed: 2.2, rmin: 90, rmax: 140, rskill: 300, rap: 500, rcrit: 14.2, apen: 250 }),
  mk('rogue_dagger_hit', { cls: 'ROGUE', hit: 12, skill: 315, oskill: 315, crit: 28.7, speed: 1.8, offSpeed: 1.4, dmin: 90, dmax: 170, omin: 60, omax: 100,
    agi: 380, str: 90, ap: 1300, defense: 300, dodge: 29, parry: 8, block: 0, mana: 0, int: 30, spi: 40 }),
  mk('hunter_bow', { cls: 'HUNTER', hit: 5, skill: 300, crit: 18, speed: 2.8, dmin: 80, dmax: 140, agi: 330, rap: 1400, rcrit: 24.3, rspeed: 2.9, rmin: 600, rmax: 830, rskill: 308,
    int: 120, spi: 60, mp5: 4, defense: 300, dodge: 15, parry: 0, block: 0, hp: 6400, mana: 4200 }),
  mk('priest_heal', { cls: 'PRIEST', int: 330, spi: 280, sta: 190, sp: 120, heal: 640, mp5: 18, spcrit: 3, shit: 2, regenCast: 25, haste: 0, mana: 9100, hp: 4300, armor: 900, ap: 20,
    skill: 300, crit: 3, speed: 2.0, dmin: 40, dmax: 60, defense: 300, dodge: 3, parry: 0, block: 0, spen: 10 }),
  mk('mage_caster', { cls: 'MAGE', int: 360, spi: 150, sta: 170, sp: 520, heal: 520, mp5: 0, spcrit: 5, shit: 14, haste: 0, mana: 9800, hp: 3700, defense: 300, dodge: 3, parry: 0, block: 0,
    skill: 300, crit: 2, speed: 2.0, dmin: 30, dmax: 50, spen: 25 }),
  mk('shaman_enh_shield', { cls: 'SHAMAN', hit: 6, shield: true, blockFlat: 30, str: 200, agi: 160, int: 140, spi: 90, defense: 322, dodge: 9, parry: 0, block: 16, sp: 60, heal: 60, regenCast: 15, mp5: 9, crit: 14 }),
];
const SPLICE_CASES = ['paladin_tank', 'warrior_dual', 'rogue_dagger_hit', 'hunter_bow', 'priest_heal', 'mage_caster'];
const PANELS = ['base', 'melee', 'meleeBoss', 'ranged', 'spell', 'heal', 'misc', 'defense', 'defenseBoss'];

// ---------------------------------------------------------------- normalisation (accents, tirets, guillemets)
function norm(s) {
  return String(s).normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[\u2013\u2014]/g, '-').replace(/\u2014/g, '-').replace(/\s+/g, ' ').trim();
}

// ---------------------------------------------------------------- extraction du builder
function extractFn(src, name) {
  const re = new RegExp('(^|\\n)(async )?function ' + name + '\\(');
  const m = re.exec(src);
  if (!m) throw new Error('fonction introuvable dans le builder : ' + name);
  let i = src.indexOf('{', m.index + m[0].length);
  let depth = 0, j = i;
  for (; j < src.length; j++) {
    const ch = src[j];
    if (ch === '{') depth++;
    else if (ch === '}') { depth--; if (depth === 0) break; }
  }
  return src.slice(m.index, j + 1);
}
function extractConst(src, name) {
  const m = new RegExp('(^|\\n)const ' + name + '\\b').exec(src);
  if (!m) throw new Error('constante introuvable dans le builder : ' + name);
  let i = m.index + 1;
  let depth = 0, j = src.indexOf('=', i);
  for (; j < src.length; j++) {
    const ch = src[j];
    if (ch === '{' || ch === '[' || ch === '(') depth++;
    else if (ch === '}' || ch === ']' || ch === ')') depth--;
    else if (ch === ';' && depth === 0) break;
  }
  return src.slice(i, j + 1);
}

let CTX = null;
function loadBuilder() {
  if (!fs.existsSync(HTML)) return null;
  const src = fs.readFileSync(HTML, 'utf8');
  const parts = [];
  for (const c of ['COMBAT_LEVEL', 'BASE_SKILL', 'GLANCE_CHANCE_VS_BOSS', 'SPELL_CRIT_INT_FORMULA', 'CAN_PARRY', 'CAN_BLOCK', 'CLASS_BASE_DODGE_CRIT',
    'STAT_LABELS', 'COMBAT_PANEL_DEFS', 'CLASS_DEFAULT_PANELS', 'ROLE_PRESETS']) parts.push(extractConst(src, c));
  for (const f of ['spellCritFromInt', 'missChanceVsSkill', 'dualWieldMissChance', 'bossDodgeChance', 'glanceReduction', 'critAdjustVsBoss',
    'critCapVsBoss', 'baseParryChance', 'baseBlockChance', 'shieldBlockValue', 'spiritManaPerSec', 'avoidanceVsLevelDiff', 'totalAvoidance',
    'fmtPctVal', 'computeCombatPanel']) parts.push(extractFn(src, f));
  const ctx = {};
  vm.createContext(ctx);
  // le code du builder est execute tel quel ; "const" au niveau script n'est pas visible comme propriete : on l'expose via var
  vm.runInContext(parts.join('\n').replace(/(^|\n)const /g, '$1var '), ctx);
  return ctx;
}

// Les lectures de base de donnees d'objets du builder sont remplacees par les valeurs du cas.
function builderRows(ctx, c, panel) {
  const weapon = (min, max, speed, skill) => ({ min, max, speed, skill, at: 'sword', hand: '1h', db: [] });
  const mh = weapon(c.dmin, c.dmax, c.speed, c.skill);
  const oh = c.offSpeed ? weapon(c.omin, c.omax, c.offSpeed, c.oskill) : null;
  const rw = c.rspeed ? weapon(c.rmin, c.rmax, c.rspeed, c.rskill) : null;
  const items = [];
  if (c.shield) items[16] = { id: 2 }; else if (oh) items[16] = { id: 3 };
  ctx.getItem = (id) => (id === 2 ? { 7: { at: 'shield' } } : { 7: { at: 'dagger' } });
  ctx.getEquippedWeapon = (slot) => (slot === 16 ? mh : slot === 17 ? oh : slot === 18 ? rw : null);
  ctx.weaponSkillTotal = (w) => (w ? w.skill : 300);
  ctx.weaponDamageRange = (w) => (w ? { min: w.min, max: w.max, speed: w.speed } : null);
  ctx.offhandDamageRange = (w) => (w ? { min: w.min, max: w.max, speed: w.speed } : null);
  ctx.baseAttackPower = () => 0;
  ctx.baseRangedAttackPower = () => 0;
  ctx.meleeCritTotal = () => (panel === 'ranged' ? c.rcrit : c.crit);
  ctx.baseDodgeChance = () => 0;
  ctx.maxHealthFor = () => c.hp;
  ctx.maxManaFor = () => c.mana;
  const defBonus = c.defense - 300;
  const defPct = defBonus * 0.04;
  const stats = {
    str: c.str, agi: c.agi, sta: c.sta, int: c.int, spi: c.spi, armor: c.armor, ap: panel === 'ranged' ? 0 : c.ap, rap: c.rap,
    hit: c.hit, spHit: c.shit, spCrit: c.spcrit, sp: c.sp, heal: c.heal, mp5: c.mp5, regenCast: c.regenCast, spHaste: c.haste,
    def: defBonus, dodge: c.dodge - defPct, parry: c.parry - 5 - defPct, blockChance: c.block - 5 - defPct, blockValue: c.blockFlat,
    fr: c.res[0], nr: c.res[1], frost: c.res[2], sr: c.res[3], ar: c.res[4], spellPen: c.spen, armorPen: c.apen, _race: null,
  };
  return ctx.computeCombatPanel(panel, stats, c.cls, items);
}

// ---------------------------------------------------------------- cote Lua
function lit(v) {
  if (v === null || v === undefined) return 'nil';
  if (typeof v === 'string') return JSON.stringify(v);
  if (Array.isArray(v)) return '{' + v.map(lit).join(',') + '}';
  if (typeof v === 'object') return '{' + Object.keys(v).map(k => k + '=' + lit(v[k])).join(',') + '}';
  return String(v);
}

const APPLY = `local function apply(c)
  CS.stat = { {c.str,c.str}, {c.agi,c.agi}, {c.sta,c.sta}, {c.int,c.int}, {c.spi,c.spi} }
  CS.armor = c.armor
  CS.res = { 0, c.res[1], c.res[2], c.res[3], c.res[4], c.res[5] }
  CS.ap = {c.ap,0,0}; CS.rap = {c.rap,0,0}; CS.crit = c.crit; CS.rcrit = c.rcrit
  CS.skill = {c.skill,0}; CS.offskill = {c.oskill,0}; CS.speed = c.speed; CS.offSpeed = c.offSpeed
  CS.dmin, CS.dmax, CS.omin, CS.omax = c.dmin, c.dmax, c.omin, c.omax
  CS.rspeed, CS.rmin, CS.rmax, CS.rskill = c.rspeed, c.rmin, c.rmax, {c.rskill,0}
  CS.defense = {c.defense,0}; CS.dodge, CS.parry, CS.block = c.dodge, c.parry, c.block
  W.units.player.class = c.cls
  W.units.player.hpMax = c.hp
  W.units.player.manaMax = c.mana
  W.units.player.ptype = (c.mana > 0) and 0 or 1
  M.lastMana = nil
  CS.gear = {}
  CS.right = {}
  local lines = {}
  if c.hit > 0 then table.insert(lines, "Equip: Improves your chance to hit by " .. c.hit .. "%.") end
  if c.shit > 0 then table.insert(lines, "Equip: Improves your chance to hit with spells by " .. c.shit .. "%.") end
  if c.spcrit > 0 then table.insert(lines, "Equip: Improves your chance to get a critical strike with spells by " .. c.spcrit .. "%.") end
  if c.sp > 0 then table.insert(lines, "Equip: Increases damage and healing done by magical spells and effects by up to " .. c.sp .. ".") end
  if c.heal - c.sp > 0 then table.insert(lines, "Equip: Increases healing done by spells and effects by up to " .. (c.heal - c.sp) .. ".") end
  if c.mp5 > 0 then table.insert(lines, "Equip: Restores " .. c.mp5 .. " mana per 5 sec.") end
  if c.haste > 0 then table.insert(lines, "Equip: Increases your spell haste by " .. c.haste .. "%.") end
  if c.spen > 0 then table.insert(lines, "Equip: Decreases the magical resistances of your spell targets by " .. c.spen .. ".") end
  if c.apen > 0 then table.insert(lines, "Equip: Your attacks ignore " .. c.apen .. " of the target's armor.") end
  if table.getn(lines) > 0 then CS.gear[1] = lines end
  if c.shield then
    CS.gear[17] = { "Bouclier", "Off Hand", (c.blockFlat > 0) and (c.blockFlat .. " Block") or "0 Armor" }
    CS.right[17] = { "", "Shield" }
  end
  CS.talents = {}
  if c.regenCast > 0 then
    CS.talents[1] = { name = "Meditation", rank = 1, lines = { "Meditation", "Rank 1/1", "Allows " .. c.regenCast .. "% of your mana regeneration to continue while casting." } }
  end
  M.gearDirty, M.talentDirty = true, true
end
`;

function luaSuite() {
  const out = [];
  out.push(`local SUI = ShikiUI
local C = SUI.Config
local M = SUI.CharStats
CS_SETUP()
BOOT()
SETTLE()
Fire("PLAYER_REGEN_ENABLED")
SETTLE()
CharacterFrame:Show()
Pump(0.6)
${APPLY}
local function dump(name, panel)
  M.SetPanel(1, panel)
  local box = M.boxes[1]
  for i = 1, box.ncur do
    local r = box.rows[i]
    print("ROW\\t" .. name .. "\\t" .. panel .. "\\t" .. r.label:GetText() .. "\\t" .. r.value:GetText())
  end
end
`);
  for (const c of CASES) {
    out.push(`apply(${lit(c)})`);
    for (const p of PANELS) out.push(`dump(${JSON.stringify(c.name)}, ${JSON.stringify(p)})`);
  }
  out.push('TESTS_DONE = true');
  return out.join('\n');
}

function runLua() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'suibench-'));
  const f = path.join(dir, 'bench_suite.lua');
  fs.writeFileSync(f, luaSuite());
  const r = spawnSync('node', [path.join(HERE, 'harness.js'), f], { encoding: 'utf8' });
  fs.rmSync(dir, { recursive: true, force: true });
  if (r.status !== 0) { console.log(r.stdout); console.log(r.stderr); throw new Error('le module Lua a echoue dans le harnais'); }
  const rows = {};
  for (const line of r.stdout.split(/\r?\n/)) {
    if (line.indexOf('ROW\t') !== 0) continue;
    const [, name, panel, label, value] = line.split('\t');
    const k = name + '|' + panel;
    (rows[k] = rows[k] || []).push([label, value]);
  }
  return rows;
}

// ---------------------------------------------------------------- comparaison
const stripEst = (v) => String(v).replace(/^~/, '');
function expectedFromBuilder(ctx) {
  const exp = {};
  for (const c of CASES) {
    for (const p of PANELS) {
      let rows = builderRows(ctx, c, p);
      if (rows === null) rows = [['Aucune arme a distance equipee', '']];
      exp[c.name + '|' + p] = rows.filter(r => r[0] !== 'Forme (druide)').map(r => [norm(r[0]), norm(r[1])]);
    }
  }
  return exp;
}

function compare(exp, got, label) {
  let bad = 0, n = 0;
  for (const k of Object.keys(exp)) {
    const e = exp[k], g = got[k] || [];
    if (e.length !== g.length) { console.log(`ECART ${label} ${k} : ${e.length} lignes attendues, ${g.length} obtenues`); bad++; }
    for (let i = 0; i < Math.min(e.length, g.length); i++) {
      n++;
      const gl = norm(g[i][0]), gv = norm(stripEst(g[i][1]));
      if (e[i][0] !== gl || e[i][1] !== gv) {
        console.log(`ECART ${label} ${k} ligne ${i + 1} : attendu [${e[i][0]} = ${e[i][1]}] obtenu [${gl} = ${gv}]`);
        bad++;
      }
    }
  }
  console.log(`${n} lignes comparees (${label}), ${bad} ecart(s)`);
  return bad;
}

function main() {
  const ctx = loadBuilder();
  const got = runLua();
  if (arg === '--freeze') {
    if (!ctx) throw new Error('builder introuvable : ' + HTML);
    fs.writeFileSync(FROZEN, JSON.stringify(expectedFromBuilder(ctx)) + '\n');
    console.log('ecrit : ' + FROZEN);
    return 0;
  }
  if (arg.indexOf('--emit-lua') === 0 || arg === '--splice') {
    if (!ctx) throw new Error('builder introuvable : ' + HTML);
    const names = arg === '--splice' ? SPLICE_CASES : (arg.split('=')[1] || '').split(',').filter(Boolean);
    const exp = expectedFromBuilder(ctx);
    const sel = CASES.filter(c => !names.length || names.indexOf(c.name) >= 0);
    const o = [];
    o.push('-- FROZEN-BEGIN (genere par tests/bench_builder.js --splice : cas et lignes attendues du builder, a ne pas editer a la main)');
    o.push(APPLY);
    o.push('local CASES = {');
    for (const c of sel) o.push('  ' + lit(c) + ',');
    o.push('}');
    o.push('local EXPECT = {');
    for (const c of sel) for (const p of PANELS) o.push('  [' + JSON.stringify(c.name + '|' + p) + '] = ' + lit(exp[c.name + '|' + p].map(r => r[0] + '=' + r[1])) + ',');
    o.push('}');
    o.push('-- FROZEN-END');
    const text = o.join('\n');
    if (arg !== '--splice') { console.log(text); return 0; }
    const tf = path.join(HERE, 't_charstats.lua');
    let t = fs.readFileSync(tf, 'utf8');
    const i0 = t.indexOf('-- FROZEN-BEGIN'), i1 = t.indexOf('-- FROZEN-END');
    if (i0 >= 0 && i1 >= 0) t = t.slice(0, i0) + text + t.slice(i1 + '-- FROZEN-END'.length);
    else t = t.replace('--@@FROZEN@@', () => text);
    fs.writeFileSync(tf, t);
    console.log('t_charstats.lua mis a jour : ' + sel.length + ' cas');
    return 0;
  }
  let bad = 0;
  if (ctx) bad += compare(expectedFromBuilder(ctx), got, 'builder reel');
  else console.log('builder introuvable (' + HTML + ') : comparaison aux valeurs figees seulement');
  if (fs.existsSync(FROZEN)) bad += compare(JSON.parse(fs.readFileSync(FROZEN, 'utf8')), got, 'valeurs figees');
  else if (!ctx) { console.log('aucune valeur figee non plus'); bad++; }
  if (ctx && fs.existsSync(FROZEN)) {
    // le builder a-t-il change depuis le gel ?
    const frozen = JSON.parse(fs.readFileSync(FROZEN, 'utf8'));
    if (JSON.stringify(frozen) !== JSON.stringify(expectedFromBuilder(ctx))) console.log('NOTE : le builder ne donne plus les valeurs figees (relancer avec --freeze apres verification)');
  }
  console.log(bad ? bad + ' ecart(s)' : 'OK : le panneau en jeu donne les memes lignes que le builder');
  return bad ? 1 : 0;
}
process.exit(main());
