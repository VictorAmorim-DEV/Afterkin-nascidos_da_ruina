extends Node2D
## Cena principal de Afterkin: Nascidos da Ruína.
## World = cenário com Y-Sort (jogador e objetos); Camera2D segue o jogador.


func _ready() -> void:
	print("Afterkin: Nascidos da Ruína — iniciado")


## Fechar o jogo exporta o diário da partida (DiarioPartida) para a pasta do jogo, em segundo plano.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		DiarioPartida.exportar("fechou")
