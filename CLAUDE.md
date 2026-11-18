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

## Pendências
- `docs/PENDENCIAS.md` é a lista viva do que falta fazer. Leia no começo de cada sessão.
- A cada pedido novo, acrescente o item (⬜); ao começar, marque 🔄; ao terminar, ✅ com o hash do commit.
- Ideias que eu ainda estou avaliando ficam como 💭 e só começam quando eu confirmar.

## Testes
- Godot instalado em: C:\Users\victo\OneDrive\Área de Trabalho\Godot\Godot_v4.7.2-stable_win64_console.exe
- Rodar o projeto sem janela: <exe> --headless --path . --quit-after 300
- Sempre rodar o projeto e ler os erros ANTES de commitar.

## Git
- Commits no padrão `feat: ...`, `fix: ...`, `docs: ...`, em português.
- Commitar os arquivos .uid e .import junto com o script/asset correspondente (cenas e scripts
  se referenciam pelos UIDs). Só a pasta .godot/ fica fora do Git (já está no .gitignore).
- Quem dá `git push` sou eu; não faça push sem eu pedir.

## Estado atual
- Port da V13 concluído (docs/RESUMO_V13.md): construções com texturas procedurais, inventário/loot,
  combate/inimigos, raças/doenças (com sintomas por estágio e antídoto dos ninhos de morcegos),
  veículos/totem, ruas com rotatória, esquinas, árvores, bueiros e lixo, sombras do sol, minimapa, menu, save/load.
- Mundo = ilha do mapa-múndi (assets/new_assets/mapa_mundi_hd.png): `tools/gerar_mapa_dados.gd` gera
  `data/mapa_dados.res` e `MapaMundi` responde terreno/mata/bioma/água por ponto; 1 px do mapa = 192 u (~5 × 4,7 km).
  Mudou o mapa-múndi? Rode o tool de novo. As 16 cidades ficam em `MundoGen.AREAS` (origem em px do mapa).
- Coordenadas chegam a 250 mil u: desenhe relativo à origem do nó (a triangulação em float32 falha longe da origem).
- Acabamento: `Vento` (shader nas plantas), `SombraSol.contato`, `Relevo` (normal maps: `tools/gerar_normais.gd`),
  `Atmosfera` e poeira do `Veiculo` (CPUParticles2D: as GPUParticles2D não aparecem no GL Compatibility).
- Prédios: `Edificio` constrói fatiado (orçamento por quadro comum a todos) e fica invisível até
  `pronto`; os polígonos vão para um `Desenho` (um draw call por nó, sempre com o atlas `TexturasParede`).
- Gráficos nunca mudam sozinhos: efeitos pesados ficam atrás de uma flag (ex.: `SombraSol.ativo`) que vira
  opção no menu de configurações.
- Marco 1 (incursão humana) aprovado; decisões de design em `docs/DECISOES_DESIGN.md` (valem sobre o GDD).
- Modo desenvolvedor: F1 (`PainelDev`/`Dev`, só em build de debug). O mapa-base do minimapa/mapa do mundo fica em
  cache em `user://mapa_base_*.png` (chave pelos dados e scripts do mapa; regenera sozinho quando eles mudam).
- Único ⬜ que resta no RESUMO: guarda/mirar (na V13 é só um anel, sem efeito). Próximos passos: docs/PENDENCIAS.md.