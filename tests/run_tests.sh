#!/bin/sh
# Lance : structure (.toc a jour), lint Lua 5.0 de TOUT le dossier (addon + modele de module), controle des traductions,
# toutes les suites t_*.lua, puis le controle du modele de module (cree un module de demonstration dans une copie).
# Usage : sh run_tests.sh [suite ...]      (avec des suites en argument : seulement elles ; SUI_INNER=1 : pas de controle du modele)
cd "$(dirname "$0")" || exit 1
fail=0
echo "== structure (.toc) =="
node ../tools/gen_toc.js --check || fail=1
echo "== lint50 =="
node lint50.js ../ShikiUI/*.lua ../docs/template/Mod_*.lua ../docs/template/Locale_*.lua || fail=1
echo "== fermetures de boucle =="
node lint_loopclosure.js ../ShikiUI/*.lua || fail=1
echo "== traductions =="
node check_locale.js || fail=1
echo "== styles en dur (modules) =="
node check_style.js --selftest || fail=1
node check_style.js || fail=1
suites="$*"
all=0
if [ -z "$suites" ]; then suites=$(ls t_*.lua); all=1; fi
for s in $suites; do
  echo "== $s =="
  node harness.js "$s" || fail=1
done
if [ "$all" = "1" ] && [ -z "$SUI_INNER" ]; then
  echo "== modele de module =="
  node check_template.js || fail=1
fi
if [ "$fail" = "0" ]; then echo "TOUT EST VERT"; else echo "ECHECS"; fi
exit $fail
