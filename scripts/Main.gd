extends Node3D

const MALL_DATA = preload("res://scripts/Mall.gd")
const MALL_PANEL = preload("res://scripts/MallPanel.gd")
var mall = MALL_DATA.new()
var mall_ui: Control
var hero_actor: Node3D
var hero_label: Label

const SAVE_PATH = "user://save.json"
const LOCATIONS = {"HQ": Vector3(-10,0,-10), "Farm": Vector3(10,0,-10), "Oil": Vector3(-10,0,10), "Barracks": Vector3(10,0,10)}
var food: int = 600
var oil: int = 450
var metal: int = 300
var troops: int = 10
var victories: int = 0
var levels: Dictionary = {"HQ":1, "Farm":1, "Oil":1, "Barracks":1}
var selected: String = "HQ"
var cooldown: float = 0.0
var tick: float = 0.0
var training: float = 0.0
var mission: int = 0
var health: float = 100.0
var fighting: bool = false
var enemies: Array[Dictionary] = []
var shot_clock: float = 0.0
var elapsed: float = 0.0
var camera: Camera3D
var camera_target := Vector3(0,0,0)
var zoom: float = 1.0
var resources: Label
var details: Label
var status: Label
var mission_label: Label
var fight_button: Button
var train_button: Button
var marker: MeshInstance3D
var actors: Node3D
var touches: Dictionary = {}
var pointer_start := Vector2.ZERO
var pointer_last := Vector2.ZERO
var dragging: bool = false
var mouse_down: bool = false
var hud_clock: float = 0.0

func _ready() -> void:
    load_game()
    create_world()
    create_ui()
    update_hero_actor()
    refresh()

func box(parent: Node3D, pos: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
    var object := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    object.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.9
    object.material_override = mat
    object.position = pos
    parent.add_child(object)
    return object

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, tint: Color) -> void:
    var object := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    object.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    object.material_override = mat
    object.position = pos
    parent.add_child(object)

func create_world() -> void:
    box(self, Vector3(0,-0.6,0), Vector3(150,1,150), Color("343e36"))
    box(self, Vector3(0,-0.2,0), Vector3(50,0.4,50), Color("58604c"))
    for axis in [0,1]:
        box(self, Vector3(0,0.03,0), Vector3(5,0.08,48) if axis == 0 else Vector3(48,0.08,5), Color("454b49"))
    for z in range(-22,23,5):
        box(self, Vector3(0,0.09,z), Vector3(0.15,0.02,2), Color("c6bd8d"))
    var colors := [Color("6c828d"),Color("7b8960"),Color("a18560"),Color("7c8176")]
    var index: int = 0
    for key in LOCATIONS:
        var p: Vector3 = LOCATIONS[key]
        var building := Node3D.new()
        building.name = key
        building.position = p
        add_child(building)
        box(building, Vector3(0,0.2,0), Vector3(9,0.4,8), Color("797a6c"))
        box(building, Vector3(0,1.9,0), Vector3(7,3.4,6), colors[index])
        box(building, Vector3(0,3.8,0), Vector3(7.8,0.4,6.8), Color("303e43"))
        box(building, Vector3(0,1.2,3.05), Vector3(1.4,2.4,0.12), Color("243138"))
        for x in [-2.2,2.2]:
            box(building, Vector3(x,2.4,3.05), Vector3(1.1,0.8,0.12), Color("a0c6bd"))
        var label := Label3D.new()
        label.text = key.to_upper()
        label.position = Vector3(0,6,0)
        label.font_size = 42
        label.pixel_size = 0.026
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        building.add_child(label)
        if key == "HQ":
            cylinder(building, Vector3(1.8,5,0),0.1,3,Color("a8b0aa"))
            box(building,Vector3(2.7,5.7,0),Vector3(1.8,0.8,0.08),Color("e6ac55"))
        elif key == "Farm":
            for x in [-2.5,-1.0,0.5,2.0]:
                box(building,Vector3(x,0.3,-5.5),Vector3(0.8,0.5,3),Color("8c9b50"))
        elif key == "Oil":
            for x in [-2.0,1.0]:
                cylinder(building,Vector3(x,1,-5),1,2,Color("414c50"))
        else:
            for x in [-2.0,0.0,2.0]:
                box(building,Vector3(x,0.6,-5),Vector3(1.3,1.2,1.3),Color("6d6751"))
        index += 1
    for i in range(-24,25,4):
        box(self,Vector3(i,1.1,-24),Vector3(3.8,2.2,1),Color("74776b"))
        if abs(i) > 4:
            box(self,Vector3(i,1.1,24),Vector3(3.8,2.2,1),Color("74776b"))
        box(self,Vector3(-24,1.1,i),Vector3(1,2.2,3.8),Color("74776b"))
        box(self,Vector3(24,1.1,i),Vector3(1,2.2,3.8),Color("74776b"))
    for x in [-5.0,5.0]:
        box(self,Vector3(x,2.2,22),Vector3(3,4.4,3),Color("566667"))
        box(self,Vector3(x,4.8,22),Vector3(4,0.7,4),Color("273b40"))
        box(self,Vector3(x,4.8,24),Vector3(0.3,0.3,3),Color("192b2d"))
    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    for i in range(65):
        var p := Vector3(rng.randf_range(-65,65),0,rng.randf_range(-65,65))
        if abs(p.x) < 29 and abs(p.z) < 33:
            continue
        cylinder(self,p+Vector3(0,1.5,0),0.25,3,Color("514b3e"))
        box(self,p+Vector3(0,4,0),Vector3(2.5,4,2.5),Color("384c40"))
    for key in levels:
        get_node(NodePath(key)).scale.y = 1.0 + (int(levels[key])-1)*0.06
    actors = Node3D.new()
    add_child(actors)
    for x in [-4.0,-2.0,2.0,4.0]:
        var soldier := make_person(Color("7d9582"))
        soldier.position = Vector3(x,0,19)
    marker = box(self,Vector3(-10,0.12,-10),Vector3(9.8,0.12,8.8),Color("e5b35b"))
    camera = Camera3D.new()
    camera.current = true
    camera.far = 250
    camera.fov = 48
    add_child(camera)
    update_camera()
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50,-35,0)
    sun.light_color = Color("ffe0ac")
    sun.light_energy = 1.5
    add_child(sun)
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("526b6a")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("b6c9cf")
    env.ambient_light_energy = 0.65
    world.environment = env
    add_child(world)

func make_person(tint: Color) -> Node3D:
    var person := Node3D.new()
    actors.add_child(person)
    box(person,Vector3(0,1.1,0),Vector3(0.65,0.9,0.4),tint)
    box(person,Vector3(0,1.85,0),Vector3(0.46,0.5,0.45),Color("b8b19b"))
    box(person,Vector3(-0.2,0.35,0),Vector3(0.23,0.7,0.3),Color("3c4842"))
    box(person,Vector3(0.2,0.35,0),Vector3(0.23,0.7,0.3),Color("3c4842"))
    box(person,Vector3(-0.5,1.2,0.25),Vector3(0.25,0.25,0.8),tint)
    box(person,Vector3(0.5,1.2,0.25),Vector3(0.25,0.25,0.8),tint)
    return person

func style(bg: Color, edge: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = edge
    s.set_border_width_all(1)
    s.set_corner_radius_all(10)
    s.content_margin_left = 16
    s.content_margin_right = 16
    s.content_margin_top = 10
    s.content_margin_bottom = 10
    return s

func label_in(parent: Node, text: String, font_size: int = 18) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size",font_size)
    parent.add_child(label)
    return label

func button_in(parent: Node, text: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(0,48)
    button.add_theme_stylebox_override("normal",style(Color("203238"),Color("43595b")))
    button.add_theme_stylebox_override("hover",style(Color("31484b"),Color("e5b35b")))
    button.add_theme_stylebox_override("pressed",style(Color("56604d"),Color("e5b35b")))
    button.pressed.connect(action)
    parent.add_child(button)
    return button

func create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(16,16)
    panel.custom_minimum_size = Vector2(310,0)
    panel.add_theme_stylebox_override("panel",style(Color("101e24ed"),Color("40575a")))
    layer.add_child(panel)
    panel.custom_minimum_size.y = 652
    panel.size.y = 652
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    var column := VBoxContainer.new()
    column.custom_minimum_size.x = 274
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation",8)
    scroll.add_child(column)
    label_in(column,"VB LAST EMPIRE",26).modulate = Color("e5b35b")
    label_in(column,"SURVIVAL  /  COMMAND CENTER",13)
    button_in(column,"ITEM MALL  /  HEROES",show_mall)
    hero_label = label_in(column,"",15)
    hero_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    resources = label_in(column,"")
    column.add_child(HSeparator.new())
    details = label_in(column,"")
    var grid := GridContainer.new()
    grid.columns = 2
    column.add_child(grid)
    for key in LOCATIONS:
        var b := button_in(grid,key,select_building.bind(key))
        b.custom_minimum_size.x = 133
    button_in(column,"UPGRADE BUILDING",do_action.bind("UPGRADE"))
    train_button = button_in(column,"TRAIN 5 SOLDIERS",do_action.bind("TRAIN"))
    fight_button = button_in(column,"DEFEND BASE",start_wave)
    var row := HBoxContainer.new()
    column.add_child(row)
    button_in(row,"REPAIR",do_action.bind("REPAIR"))
    button_in(row,"SAVE",do_action.bind("SAVE"))
    mission_label = label_in(column,"",16)
    mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    button_in(column,"CLAIM MISSION REWARD",claim_mission)
    status = label_in(column,"Commander: upgrade HQ, train soldiers, then defend the gate.",16)
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var controls := HBoxContainer.new()
    controls.position = Vector2(950,16)
    layer.add_child(controls)
    button_in(controls," - ",zoom_by.bind(0.12))
    button_in(controls," + ",zoom_by.bind(-0.12))
    button_in(controls,"CENTER",center_camera)
    var hint := label_in(layer,"DRAG TO PAN  /  TAP A BUILDING  /  PINCH TO ZOOM",16)
    hint.position = Vector2(400,680)

func select_building(key: String) -> void:
    selected = key
    marker.position = LOCATIONS[key] + Vector3(0,0.12,0)
    refresh()

func do_action(action: String) -> void:
    if action == "UPGRADE":
        var level: int = levels[selected]
        var cost: int = level * 80
        if level >= 20:
            status.text = "Maximum level reached."
        elif selected != "HQ" and level >= int(levels["HQ"]):
            status.text = "Upgrade HQ first."
        elif food >= cost and oil >= cost and metal >= cost:
            food -= cost
            oil -= cost
            metal -= cost
            levels[selected] = level + 1
            status.text = selected + " upgraded! Production or defense increased."
            get_node(NodePath(selected)).scale.y = 1.0 + (level * 0.06)
        else:
            status.text = "Need %d of EACH resource." % cost
    elif action == "TRAIN":
        if training > 0:
            status.text = "Training already in progress."
        elif food >= 100 and oil >= 40:
            food -= 100
            oil -= 40
            training = maxf(3,12 - int(levels["Barracks"]))
            status.text = "Training 5 soldiers..."
        else:
            status.text = "Training costs 100 food + 40 oil."
    elif action == "REPAIR":
        if fighting:
            status.text = "Repair after the battle."
        elif health >= 100:
            status.text = "Base is already fully repaired."
        elif metal >= 60:
            metal -= 60
            health = minf(100,health+40)
            status.text = "Base repaired +40."
        else:
            status.text = "Need 60 metal to repair."
    else:
        status.text = "Progress saved on this device."
    save_game()
    refresh()

func start_wave() -> void:
    if fighting:
        return
    if cooldown > 0:
        status.text = "Squad recovering. Please wait."
        return
    if troops < 10 or health <= 0:
        status.text = "Need 10 soldiers and a repaired base."
        return
    save_game()
    fighting = true
    shot_clock = 0
    var count: int = mini(45,8 + victories * 3)
    for i in range(count):
        var person := make_person(Color("78864b"))
        person.position = Vector3(float(i % 7 - 3)*1.3,0,33 + float(i / 7)*2.3)
        enemies.append({"node":person,"hp":2 + int(victories / 3),"phase":float(i)})
    status.text = "Wave %d approaching the south gate!" % (victories+1)
    refresh()

func update_battle(delta: float) -> void:
    for enemy in enemies:
        var person: Node3D = enemy.node
        person.position.z -= delta * (1.5 + minf(victories*0.08,1.5))
        person.position.y = absf(sin(elapsed*7 + enemy.phase))*0.14
        if person.position.z <= 21:
            health = maxf(0,health-delta*2.5*(1.0-mall.bonuses().y))
            person.position.z = 21
    shot_clock -= delta
    if shot_clock <= 0 and not enemies.is_empty():
        shot_clock = maxf(0.09,0.65 / (1.0 + troops*0.045 + int(levels["Barracks"])*0.12) / (1.0+mall.bonuses().x))
        var enemy: Dictionary = enemies[0]
        var target: Node3D = enemy.node
        var origin := Vector3(-5 if enemies.size() % 2 == 0 else 5,4.8,24)
        var end := target.position + Vector3(0,1.2,0)
        var tracer := box(self,(origin+end)*0.5,Vector3(0.07,0.07,origin.distance_to(end)),Color("ffdc85"))
        tracer.look_at(end,Vector3.UP)
        get_tree().create_timer(0.09).timeout.connect(tracer.queue_free)
        enemy.hp = int(enemy.hp)-1-int(levels["Barracks"])/4
        if int(enemy.hp) <= 0:
            target.queue_free()
            enemies.remove_at(0)
    if health <= 0:
        end_wave(false)
    elif enemies.is_empty():
        end_wave(true)

func end_wave(won: bool) -> void:
    fighting = false
    for enemy in enemies:
        enemy.node.queue_free()
    enemies.clear()
    var losses: int = mini(troops,maxi(1,2 + int(victories/3)))
    if not won:
        losses = mini(troops,losses*3)
    troops -= losses
    if won:
        victories += 1
        food += 80 + victories*10
        oil += 50 + victories*5
        metal += 35 + victories*5
        mall.credits = mini(9999999,mall.credits+120+victories*5)
        if victories % 3 == 0:
            mall.bag.hero_crate = mini(9999,int(mall.bag.hero_crate)+1)
        status.text = "VICTORY! +%d credits. Lost %d soldiers.%s" % [120+victories*5,losses," +1 HERO CRATE!" if victories % 3 == 0 else ""]
    else:
        status.text = "BASE OVERRUN! Repair and train to try again. Lost %d soldiers." % losses
    cooldown = 12
    save_game()
    refresh()

func mission_ready() -> bool:
    if mission == 0:
        return int(levels["HQ"]) >= 2
    if mission == 1:
        return troops >= 15
    if mission == 2:
        return victories >= 1
    return false

func claim_mission() -> void:
    if mission_ready():
        mission += 1
        food += 150
        oil += 100
        metal += 100
        mall.credits = mini(9999999,mall.credits+200)
        status.text = "Mission reward: supplies + 200 mall credits!"
        save_game()
    else:
        status.text = "Complete the current objective first."
    refresh()

func refresh() -> void:
    if mall.equipped.is_empty():
        hero_label.text = "CREDITS %d  /  No hero assigned" % mall.credits
    else:
        var hero: Dictionary = mall.hero_by_id(mall.equipped)
        hero_label.text = "%s  Lv.%d  /  %d CREDITS" % [hero.name,mall.owned[mall.equipped].level,mall.credits]
        hero_label.modulate = MALL_DATA.COLORS[int(hero.rarity)]
    resources.text = "FOOD  %d     OIL  %d\nMETAL  %d     TROOPS  %d\nBASE  %d%%    WAVES  %d" % [food,oil,metal,troops,int(health),victories]
    var cost: int = int(levels[selected])*80
    details.text = "%s  /  LEVEL %d\nUpgrade: %d food + oil + metal" % [selected,levels[selected],cost]
    train_button.text = "TRAINING... %ds" % int(ceil(training)) if training > 0 else "TRAIN 5  /  100 FOOD + 40 OIL"
    train_button.disabled = training > 0
    fight_button.text = "DEFENDING  /  %d ZOMBIES" % enemies.size() if fighting else ("RECOVERING  %ds" % int(ceil(cooldown)) if cooldown > 0 else "DEFEND BASE  /  WAVE %d" % (victories+1))
    fight_button.disabled = fighting or cooldown > 0
    var objectives := ["Upgrade HQ to level 2","Have 15 soldiers ready","Survive your first wave","All starter missions complete!"]
    mission_label.text = "MISSION: " + objectives[mini(mission,3)] + (" [READY]" if mission_ready() else "")

func _process(delta: float) -> void:
    elapsed += delta
    cooldown = maxf(0,cooldown-delta)
    if training > 0:
        training = maxf(0,training-delta)
        if training == 0:
            troops += 5
            status.text = "5 soldiers ready for duty."
            save_game()
    if fighting:
        update_battle(delta)
    tick += delta
    if tick >= 5:
        tick -= 5
        food += int(levels["Farm"])*8
        oil += int(levels["Oil"])*6
        metal += int(levels["HQ"])*3
        if not fighting:
            save_game()
    hud_clock += delta
    if hud_clock >= 0.2:
        hud_clock = 0
        refresh()

func save_game() -> void:
    # Persist pre-battle state until resolution; no partial battle checkpoint.
    if fighting:
        return
    var file := FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify({"version":3,"mall":mall.to_dict(),"food":food,"oil":oil,"metal":metal,"troops":troops,"victories":victories,"levels":levels,"cooldown":cooldown,"health":health,"training":training,"mission":mission}))
        file.close()
        DirAccess.rename_absolute(SAVE_PATH+".tmp",SAVE_PATH)

func load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if not data is Dictionary:
        return
    mall.load_data(data.get("mall",{}))
    food = clampi(int(data.get("food",food)),0,9999999)
    oil = clampi(int(data.get("oil",oil)),0,9999999)
    metal = clampi(int(data.get("metal",data.get("steel",metal))),0,9999999)
    troops = clampi(int(data.get("troops",troops)),0,99999)
    victories = clampi(int(data.get("victories",data.get("kills",0))),0,99999)
    cooldown = clampf(float(data.get("cooldown",data.get("attack_cooldown",0))),0,12)
    health = clampf(float(data.get("health",100)),0,100)
    training = clampf(float(data.get("training",0)),0,12)
    mission = clampi(int(data.get("mission",0)),0,3)
    var saved = data.get("levels",{})
    if saved is Dictionary:
        for key in levels:
            levels[key] = clampi(int(saved.get(key,1)),1,20)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
        save_game()

func update_camera() -> void:
    camera.position = camera_target + Vector3(36,48,55)*zoom
    camera.look_at(camera_target,Vector3.UP)

func zoom_by(amount: float) -> void:
    zoom = clampf(zoom+amount,0.65,1.5)
    update_camera()

func center_camera() -> void:
    camera_target = Vector3.ZERO
    zoom = 1.0
    update_camera()

func pan_by(relative: Vector2) -> void:
    var right := camera.global_basis.x
    var forward := Vector3(right.z,0,-right.x)
    camera_target += (-right*relative.x-forward*relative.y)*0.065*zoom
    camera_target.x = clampf(camera_target.x,-20,20)
    camera_target.z = clampf(camera_target.z,-20,20)
    update_camera()

func tap_building(screen: Vector2) -> void:
    var origin := camera.project_ray_origin(screen)
    var direction := camera.project_ray_normal(screen)
    if abs(direction.y) < 0.001:
        return
    var hit := origin + direction * (-origin.y/direction.y)
    for key in LOCATIONS:
        if Vector2(hit.x-LOCATIONS[key].x,hit.z-LOCATIONS[key].z).length() < 5.5:
            select_building(key)
            return

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            zoom_by(-0.08)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            zoom_by(0.08)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            mouse_down = event.pressed
            if event.pressed:
                pointer_start = event.position
                dragging = false
            elif not dragging:
                tap_building(event.position)
    elif event is InputEventMouseMotion and mouse_down:
        dragging = dragging or event.position.distance_to(pointer_start) > 10
        if dragging:
            pan_by(event.relative)
    elif event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = event.position
            pointer_start = event.position
            dragging = touches.size() > 1
        else:
            touches.erase(event.index)
            if not dragging:
                tap_building(event.position)
    elif event is InputEventScreenDrag:
        if not touches.has(event.index):
            return
        if touches.size() == 2:
            var keys := touches.keys()
            var other: int = keys[0] if keys[1] == event.index else keys[1]
            var old_distance: float = touches[event.index].distance_to(touches[other])
            var new_distance: float = event.position.distance_to(touches[other])
            if new_distance > 0:
                zoom = clampf(zoom*old_distance/new_distance,0.65,1.5)
                update_camera()
            dragging = true
        else:
            dragging = dragging or event.position.distance_to(pointer_start) > 10
            if dragging:
                pan_by(event.relative)
        touches[event.index] = event.position


func show_mall() -> void:
    if fighting:
        status.text = "Finish the defense before opening the mall."
        return
    if is_instance_valid(mall_ui):
        return
    mall_ui = MALL_PANEL.new()
    mall_ui.state = mall
    mall_ui.action_requested.connect(mall_action)
    mall_ui.closed.connect(close_mall)
    var layer := CanvasLayer.new()
    layer.name = "MallLayer"
    layer.layer = 10
    add_child(layer)
    layer.add_child(mall_ui)
    # Clear map gestures so a release over the overlay never leaves a stale touch.
    touches.clear()
    mouse_down = false

func close_mall() -> void:
    if is_instance_valid(mall_ui):
        mall_ui = null
        get_node("MallLayer").queue_free()

func mall_action(action: String, id: String) -> void:
    if fighting:
        return
    var message: String = ""
    if action == "BUY":
        message = "Added to your bag: " + str(MALL_DATA.SHOP[id].name) if mall.buy(id) else "Not enough credits, or bag is full."
    elif action == "OPEN":
        var result: Dictionary = mall.open_crate()
        if result.is_empty():
            message = "No hero crates. Buy one in Shop or earn one every 3 victories."
        else:
            mall_ui.result = result
            var hero: Dictionary = mall.hero_by_id(result.id)
            message = "Recruited: " + str(hero.name) + ("  /  Duplicate +10 shards" if result.duplicate else "  /  NEW HERO!")
            update_hero_actor()
    elif action == "EQUIP":
        message = "Commander assigned." if mall.equip(id) else "Hero is locked."
        update_hero_actor()
    elif action == "UPGRADE_HERO":
        message = "Hero leveled up! Bonuses increased." if mall.upgrade(id) else "Need more matching shards, or hero is at max level."
    elif action == "USE":
        if id == "hero_crate":
            mall_ui.tab = "CRATES"
            message = "Choose OPEN 1 CRATE to recruit a hero."
        elif int(mall.bag.get(id,0)) <= 0:
            message = "No items available."
        elif id == "supply_pack":
            food += 250
            oil += 250
            metal += 250
            mall.bag[id] = int(mall.bag[id])-1
            message = "Supplies delivered: +250 food, oil and metal."
        elif id == "speedup":
            if training <= 0:
                message = "Start training first. Your boost has been kept."
            else:
                training = 0
                troops += 5
                mall.bag[id] = int(mall.bag[id])-1
                message = "Training complete! 5 soldiers ready."
        elif id == "repair_kit":
            if health >= 100:
                message = "Base is fully repaired. Your kit has been kept."
            else:
                health = minf(100,health+40)
                mall.bag[id] = int(mall.bag[id])-1
                message = "Repair kit used: +40 base health."
    if is_instance_valid(mall_ui):
        mall_ui.message = message
        mall_ui.rebuild()
    status.text = message
    save_game()
    refresh()

func update_hero_actor() -> void:
    if is_instance_valid(hero_actor):
        hero_actor.queue_free()
    if mall.equipped.is_empty():
        return
    var hero: Dictionary = mall.hero_by_id(mall.equipped)
    hero_actor = make_person(MALL_DATA.COLORS[int(hero.rarity)])
    hero_actor.position = Vector3(0,0,17)
    hero_actor.scale = Vector3.ONE*1.4
    var nameplate := Label3D.new()
    nameplate.text = str(hero.name)
    nameplate.position.y = 3.1
    nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    nameplate.modulate = MALL_DATA.COLORS[int(hero.rarity)]
    nameplate.font_size = 28
    hero_actor.add_child(nameplate)
