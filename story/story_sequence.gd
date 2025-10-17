extends Resource
class_name StorySequence

@export var images: Array[Texture2D] = []
@export var texts:  Array[String]    = []

func to_slides() -> Array:
	print("[Seq] to_slides images=", images.size(), " texts=", texts.size())
	var out: Array = []
	var n: int = max(images.size(), texts.size())
	for i in range(n):
		var tex: Texture2D = images[i] if i < images.size() else null
		var txt: String    = texts[i]  if i < texts.size()  else ""
		out.append({ "texture": tex, "text": txt })
	return out
