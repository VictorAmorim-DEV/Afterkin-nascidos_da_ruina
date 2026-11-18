class_name Dev
extends RefCounted
## Chaves do modo desenvolvedor (PainelDev, F1). Só existem em build de debug (rodando pelo editor/console);
## numa exportação de release o painel não abre e tudo aqui fica desligado.
## O jogador e os inimigos consultam estas chaves; nada disso vai para o save.

static var folego_infinito := false
static var invencivel := false
static var sem_necessidades := false   ## fome e sede sempre cheias
static var invisivel := false          ## inimigos não ouvem nem enxergam o jogador
static var voar := false               ## atravessa tudo e anda 4× mais rápido


static func disponivel() -> bool:
	return OS.is_debug_build()


## Valor de uma chave pelo nome (o painel monta as caixas a partir de uma lista).
static func valor(nome: String) -> bool:
	match nome:
		"folego_infinito": return folego_infinito
		"invencivel": return invencivel
		"sem_necessidades": return sem_necessidades
		"invisivel": return invisivel
		"voar": return voar
	return false


static func ligar(nome: String, v: bool) -> void:
	match nome:
		"folego_infinito": folego_infinito = v
		"invencivel": invencivel = v
		"sem_necessidades": sem_necessidades = v
		"invisivel": invisivel = v
		"voar": voar = v
