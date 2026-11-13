-- mock_template : extension de simulation du module "template" (copiee sous tests\mock_<nom>.lua et chargee automatiquement par le
-- harnais, apres mock_wow.lua et AVANT le mode strict : on peut donc y definir des globales d'aide). Ne contient QUE des noms d'API de
-- WoW 1.12 ou d'extensions connues, et des DONNEES DE TEST. Une aide par besoin du module, toutes prefixees par le nom du module.

-- TEMPLATE_ENEMIES(n [, dist]) : n ennemis hostiles en combat, visibles par plaques de nom, a 'dist' yards (voir mock_target.lua).
function TEMPLATE_ENEMIES(n, dist)
  CLEARPLATES()
  for i = 1, n do MKPLATE("0xF13000000000" .. string.format("%04d", i), { dist = dist or 10 }) end
end
