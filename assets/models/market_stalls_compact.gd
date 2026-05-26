extends Node3D

func _ready():
	# Parcourt tous les enfants MeshInstance3D
	for child in find_children("*", "MeshInstance3D"):
		var aabb: AABB = child.get_aabb()
		print("Nœud : ", child.name)
		print("  Taille  : ", aabb.size)      # Largeur, Hauteur, Profondeur
		print("  Centre  : ", aabb.position)  # Position relative
