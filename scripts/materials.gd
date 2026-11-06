extends RefCounted
## Do que é feito o corpo de cada um dos 79 personagens: decide o que sai quando ele apanha
## (fx.gd -> wound). A chave é o nome da cena do rig (rigs/<slug>.tscn, rigs/enemies/<era>_<tipo>.tscn).
##   flesh   sangue vermelho que mancha o chão (os 14 lutadores e os humanos de todas as eras)
##   cyborg  sangue + óleo + faíscas
##   machine óleo escuro, faíscas e parafusos (androides, drones, sentinelas)
##   mutant  sangue verde
##   shadow  fumaça roxa que sobe, sem manchas (espectros e Ecos do vazio)
##   time    areia dourada e estilhaços do tempo (Cronos e ÉON)
##   light   quadradinhos de luz, como uma falha digital (IA Aurora)

const BY_RIG := {
	"utopia_thug": "machine", "utopia_knife": "machine", "utopia_brute": "machine", "utopia_subboss": "machine",
	"utopia_boss": "light",
	"dystopia_knife": "cyborg",
	"apocalypse_thug": "mutant", "apocalypse_brute": "mutant",
	"apocalypse_knife": "shadow", "apocalypse_subboss": "shadow",
	"void_thug": "shadow", "void_knife": "shadow", "void_brute": "shadow", "void_subboss": "shadow",
	"apocalypse_boss": "time", "void_secret_boss": "time",
}
# materiais que sangram: com o sangue desligado (Y no título) viram só poeira, sem manchas
const BLEEDS := ["flesh", "cyborg", "mutant"]


static func of(f) -> String:
	if f == null or f.get("rig_scene_path") == null:
		return "wood"  # não é lutador (caixas: lascas e tábuas próprias)
	var path: String = f.rig_scene_path
	if path == "":
		return "flesh"
	return BY_RIG.get(path.get_file().get_basename(), "flesh")
