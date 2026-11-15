# Afterkin: Nascidos da Ruína

Jogo de sobrevivência isométrico pós-apocalíptico. Estamos migrando um protótipo
HTML/JS (V13, em docs/prototipo_html_v13/) para Godot 4.7, renderizador GL Compatibility.

## Regras do projeto
- Idioma: português do Brasil em comentários, mensagens de commit e texto do jogo.
- GDScript com TABS (nunca espaços). Sempre tipos explícitos em valores sem tipo
  conhecido (var x: float = dic["k"]); não use := com valores de Dictionary ou Variant.
- Projeção isométrica 2:1: tela = ((x-y)*0.5, (x+y)*0.25). Use IsoMath.mundo_para_tela
  e IsoMath.tela_para_mundo. 1 tile = 64 u, 1 metro = 49,48 u.
- Classes novas com class_name precisam de `godot --headless --import` antes de
  rodar testes headless.

## Migração da V13
- Antes de portar qualquer coisa, leia docs/RESUMO_V13.md (índice de funções e linhas
  da V13, com ✅ feito / ⬜ falta). Consulte o index.html com `sed -n 'A,Bp'`, sem relê-lo inteiro.
- Ao terminar uma etapa, marque ✅ no RESUMO_V13.md e faça o commit.

## Testes
- Godot instalado em: C:\Users\victo\OneDrive\Área de Trabalho\Godot\Godot_v4.7.2-stable_win64_console.exe
- Rodar o projeto sem janela: <exe> --headless --path . --quit-after 300
- Sempre rodar o projeto e ler os erros ANTES de commitar.

## Git
- Commits no padrão `feat: ...`, `fix: ...`, `docs: ...`, em português.
- NÃO commitar arquivos .import e .uid (a Godot os gera sozinha).
- Quem dá `git push` sou eu; não faça push sem eu pedir.

## Estado atual
- Migrado e rodando na Godot: construções, inventário/loot, combate/inimigos, raças/doenças,
  veículos/totem, mundo aberto por chunks e biomas, galhos/pedras, portões, HUD completo,
  cidade completa (prédios de vários andares, quarteirões especiais, objetos urbanos, postes).
- Prédios: `Edificio` constrói fatiado (orçamento por quadro comum a todos) e fica invisível até
  `pronto`; os polígonos vão para um `Desenho` (um _draw por nó), não um Polygon2D por face.
- Pendente: ver ⬜ em docs/RESUMO_V13.md (minimapa, menu/remapeamento, detalhes de ruas).