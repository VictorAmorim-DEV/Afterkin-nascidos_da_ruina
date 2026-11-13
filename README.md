# Afterkin: Nascidos da Ruína

Jogo de sobrevivência isométrico pós-apocalíptico, em desenvolvimento na **Godot 4.3+**.

## Estrutura
- `assets/sprites/{characters,objects,buildings}` — sprites (folhas de prédios e objetos extraídas da V13)
- `assets/tilesets` — tileset de terreno · `assets/ui/icons` — ícones de inventário
- `scenes/` — `main`, `player`, `enemies`, `world`, `ui`, `items`
- `scripts/` — `systems`, `player`, `enemies`, `world`, `ui`, `utils`
- `data/`, `resources/` — dados e recursos (.tres)
- `docs/prototipo_html_v13/` — protótipo HTML/JS da V13 (renomeado), usado como **referência de lógica** (mapa, luz, profundidade, atlas); abra `index.html` no navegador
- `concept_art/` — artes conceituais (local, fora do Git, ignorada pela Godot via `.gdignore`)

## Controles (Mapa de Entrada)
WASD mover · Shift correr · Ctrl agachar · Z deitar · Espaço pular · E interagir · Q transformar · I inventário · F lanterna · Mouse esq. atacar · Mouse dir. defender · Esc menu

## Como abrir
Godot 4.3+ → Importar → selecione `project.godot`.
