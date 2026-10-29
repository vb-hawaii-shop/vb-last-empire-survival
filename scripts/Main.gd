extends Node3D

const SAVE_PATH = "user://save.json"
var food := 600
var oil := 450
var metal := 300
var troops := 10
var victories := 0
var levels := {"HQ": 1, "Farm": 1, "Oil": 1, "Barracks": 1}
var selected := "HQ"
var cooldown := 0.0
var tick := 0.0
var camera: Camera3D
var resources: Label
var details: Label
var status: Label

func _ready() -> void:
    load_game()
    create_world()
    create_ui()
    refresh()

func cube(pos: Vector3, dimensions: Vector3, tint: Color) -> void:
    var object := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    object.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    object.material_override = mat
    object.position = pos
    add_child(object)

func create_world() -> void:
    cube(Vector3(0,-0.4,0),Vector3(55,0.8,55),Color("#4b5546"))
    cube(Vector3(0,0.03,0),Vector3(5,0.08,52),Color("#77786e"))
    cube(Vector3(0,0.03,0),Vector3(52,0.08,5),Color("#77786e"))
    var locations := [Vector3(-10,0,-10),Vector3(10,0,-10),Vector3(-10,0,10),Vector3(10,0,10)]
    var colors := [Color("#647986"),Color("#668051"),Color("#837b6c"),Color("#8c7864")]
    for i in range(4):
        var p: Vector3 = locations[i]
        cube(p+Vector3(0,1.8,0),Vector3(7,3.6,6),colors[i])
        cube(p+Vector3(0,3.8,0),Vector3(8,0.4,7),Color("#343f45"))
        for x in [-2.0,0.0,2.0]:
            cube(p+Vector3(x,2.3,3.05),Vector3(0.9,1.1,0.12),Color("#a4c5c6"))
    for i in range(-24,25,4):
        cube(Vector3(i,1,-24),Vector3(3.8,2,1),Color("#62685c"))
        cube(Vector3(i,1,24),Vector3(3.8,2,1),Color("#62685c"))
        cube(Vector3(-24,1,i),Vector3(1,2,3.8),Color("#62685c"))
        cube(Vector3(24,1,i),Vector3(1,2,3.8),Color("#62685c"))
    camera = Camera3D.new()
    camera.position = Vector3(36,43,46)
    camera.rotation_degrees = Vector3(-43,39,0)
    camera.current = true
    add_child(camera)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55,-30,0)
    add_child(sun)
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#879b9f")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#e2e3db")
    env.ambient_light_energy = 0.8
    world.environment = env
    add_child(world)

func create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(12,12)
    panel.custom_minimum_size = Vector2(280,600)
    layer.add_child(panel)
    var column := VBoxContainer.new()
    panel.add_child(column)
    var title := Label.new()
    title.text = "VB LAST EMPIRE\n3D SURVIVAL PROTOTYPE"
    column.add_child(title)
    resources = Label.new()
    column.add_child(resources)
    details = Label.new()
    column.add_child(details)
    for building in ["HQ","Farm","Oil","Barracks"]:
        var button := Button.new()
        button.text = "SELECT " + building
        button.custom_minimum_size = Vector2(260,42)
        button.pressed.connect(select_building.bind(building))
        column.add_child(button)
    for action in ["UPGRADE","TRAIN 5","FIGHT ZOMBIES","SAVE"]:
        var button := Button.new()
        button.text = action
        button.custom_minimum_size = Vector2(260,48)
        button.pressed.connect(do_action.bind(action))
        column.add_child(button)
    status = Label.new()
    status.text = "Welcome, Commander!"
    column.add_child(status)

func select_building(building: String) -> void:
    selected = building
    refresh()

func do_action(action: String) -> void:
    if action == "UPGRADE":
        var cost: int = levels[selected] * 80
        if food >= cost and oil >= cost and metal >= cost:
            food -= cost
            oil -= cost
            metal -= cost
            levels[selected] += 1
            status.text = selected + " upgraded."
        else:
            status.text = "Not enough resources."
    elif action == "TRAIN 5":
        if food >= 100 and oil >= 40:
            food -= 100
            oil -= 40
            troops += 5
            status.text = "5 soldiers trained."
        else:
            status.text = "Need food and oil."
    elif action == "FIGHT ZOMBIES":
        if cooldown > 0:
            status.text = "Squad recovering."
        elif troops < 10:
            status.text = "Need 10 soldiers."
        else:
            var enemy: int = 8 + victories * 3
            var power: int = troops * 2 + levels["Barracks"] * 4
            var casualties: int = mini(troops, maxi(1, int(ceil(float(enemy) / 12.0))))
            troops -= casualties
            if power >= enemy:
                victories += 1
                food += 80
                oil += 50
                metal += 35
                status.text = "Victory! Lost %d soldiers." % casualties
            else:
                status.text = "Defeat! Lost %d soldiers." % casualties
            cooldown = 12.0
    elif action == "SAVE":
        status.text = "Saved!"
    save_game()
    refresh()

func refresh() -> void:
    resources.text = "Food %d | Oil %d\nMetal %d | Troops %d\nWins %d" % [food,oil,metal,troops,victories]
    details.text = "Selected: %s | Level %d" % [selected,levels[selected]]

func _process(delta: float) -> void:
    cooldown = maxf(0.0,cooldown-delta)
    tick += delta
    if tick >= 5.0:
        tick = 0.0
        food += levels["Farm"] * 8
        oil += levels["Oil"] * 6
        metal += levels["HQ"] * 3
        save_game()
        refresh()

func save_game() -> void:
    var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify({"food":food,"oil":oil,"metal":metal,"troops":troops,"victories":victories,"levels":levels,"cooldown":cooldown}))

func load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if not data is Dictionary:
        return
    food = int(data.get("food",food))
    oil = int(data.get("oil",oil))
    metal = int(data.get("metal",metal))
    troops = int(data.get("troops",troops))
    victories = int(data.get("victories",victories))
    cooldown = float(data.get("cooldown",0.0))
    var saved = data.get("levels",{})
    if saved is Dictionary:
        for key in levels:
            levels[key] = int(saved.get(key,1))
