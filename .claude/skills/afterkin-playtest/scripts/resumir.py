"""Resume um ou vários diários de partida do Afterkin (eventos.json do DiarioPartida) em Markdown.

Uso: python resumir.py <pasta_ou_arquivo> [<pasta_ou_arquivo> ...]
Procura eventos.json recursivamente em cada pasta. Só lê; não escreve nada.
"""
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

SISTEMAS = {
	"troca": "Escambo", "trabalho": "Trabalhos na comunidade", "recado": "Recados", "habilidade": "Medicina",
	"rumor": "Rumores", "crime": "Crimes", "sono": "Dormir", "doenca": "Doenças", "renascer": "Renascer",
}


def achar(caminhos):
	for c in caminhos:
		p = Path(c)
		if p.is_file() and p.name == "eventos.json":
			yield p
		elif p.is_dir():
			yield from sorted(p.rglob("eventos.json"))


def dur(s):
	m = round(s / 60)
	return f"{m // 60} h {m % 60:02d} min" if m >= 60 else f"{m} min"


def main():
	arquivos = list(achar(sys.argv[1:] or ["diarios"]))
	if not arquivos:
		print("Nenhum eventos.json encontrado.")
		return
	partidas = []
	for a in arquivos:
		try:
			partidas.append((a, json.loads(a.read_text(encoding="utf-8"))))
		except (OSError, json.JSONDecodeError) as e:
			print(f"- não deu para ler {a}: {e}")
	tempo_total = sum(d.get("real_s", 0) for _, d in partidas)
	tipos = Counter()
	causas = Counter()
	lugares_morte = Counter()
	tempos = defaultdict(float)
	uso = defaultdict(set)
	reps = defaultdict(list)
	abates = Counter()
	print(f"# Resumo de {len(partidas)} partida(s) — {dur(tempo_total)} de tempo real\n")
	print("| Partida | Origem | Tempo real | Dia no jogo | Mortes | Eventos |")
	print("|---|---|---|---|---|---|")
	for a, d in partidas:
		evs = d.get("eventos", [])
		mortes = [e for e in evs if e.get("tipo") == "morte"]
		print(f"| {d.get('id', a.parent.name)} | {d.get('info', {}).get('origem', '?')} | {dur(d.get('real_s', 0))} | "
			f"{d.get('dia', '?')} | {len(mortes)} | {len(evs)} |")
		for e in evs:
			t = e.get("tipo", "?")
			tipos[t] += 1
			if t in SISTEMAS:
				uso[t].add(d.get("id"))
			if t == "morte":
				txt = e.get("texto", "")
				causa, _, lugar = txt.removeprefix("Morreu ").rstrip(".").partition(", ")
				causas[causa] += 1
				lugares_morte[lugar or "?"] += 1
		for k, v in d.get("tempos", {}).items():
			tempos[k] += v
		for k, v in d.get("reputacao", {}).items():
			reps[k].append(v)
		abates.update(d.get("abates", {}))
	print("\n## Mortes por causa")
	for k, v in causas.most_common():
		print(f"- {k}: {v}")
	print("\n## Mortes por lugar")
	for k, v in lugares_morte.most_common(10):
		print(f"- {k}: {v}")
	print("\n## Tempo em cada lugar (somado)")
	for k, v in sorted(tempos.items(), key=lambda x: -x[1])[:15]:
		print(f"- {k}: {dur(v)} ({v / max(1, tempo_total) * 100:.0f}%)")
	print("\n## Uso dos sistemas (em quantas partidas apareceu)")
	for t, nome in SISTEMAS.items():
		print(f"- {nome}: {len(uso[t])}/{len(partidas)} partidas, {tipos[t]} vezes")
	print("\n## Eventos por tipo")
	for k, v in tipos.most_common():
		print(f"- {k}: {v}")
	print("\n## Reputação final (média por comunidade)")
	for k, v in reps.items():
		print(f"- {k}: média {sum(v) / len(v):.0f} (mín {min(v)}, máx {max(v)})")
	print("\n## Inimigos mortos")
	for k, v in abates.most_common():
		print(f"- {k}: {v}")
	print("\n## Linhas do tempo (sem reputação e lugares)")
	for a, d in partidas:
		print(f"\n### {d.get('id', a.parent.name)}")
		for e in d.get("eventos", []):
			if e.get("tipo") not in ("reputacao", "lugar"):
				print(f"- Dia {e.get('dia')}, {e.get('hora')} — {e.get('texto')}")


if __name__ == "__main__":
	main()
