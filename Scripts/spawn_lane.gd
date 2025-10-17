extends Resource
class_name SpawnLane

@export var path2d_path: NodePath        # OPTION A : pointer un Path2D déjà présent dans la scène
@export var stage_scene: PackedScene     # OPTION B : sinon, on instancie une scène dont la racine est Path2D
@export var mob_scene: PackedScene       # scène du mob (ex: mobA.tscn)

@export var count: int = 20              # combien de mobs à spawner sur cette voie
@export var interval: float = 0.60       # cadence de spawn pour cette voie
@export var rotates: bool = false        # le mob pivote selon la tangente ?
@export var loop: bool = false           # doit reboucler (en TD, laisse false)
