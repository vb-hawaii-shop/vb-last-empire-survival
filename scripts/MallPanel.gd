extends Control

signal action_requested(action: String, id: String)
signal closed
const DATA = preload("res://scripts/Mall.gd")
const PORTRAIT = preload("res://scripts/HeroPortrait.gd")
var state: RefCounted
var tab: String = "SHOP"
var message: String = "Welcome! 1,000 credits and 3 hero crates are included."
var result: Dictionary = {}
var content: VBoxContainer
var balance: Label
var tabs: Dictionary = {}

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade := ColorRect.new()
    shade.color = Color("08151bea")
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    var panel := PanelContainer.new()
    panel.position = Vector2(40,28)
    panel.size = Vector2(1200,664)
    panel.add_theme_stylebox_override("panel",skin(Color("101f29"),Color("6c827c")))
    add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation",10)
    panel.add_child(column)
    var header := HBoxContainer.new()
    column.add_child(header)
    var title := text(header,"ITEM MALL  /  HERO COMMAND",27)
    title.modulate = Color("f2c365")
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    balance = text(header,"",21)
    button(header,"CLOSE",func(): closed.emit())
    var nav := HBoxContainer.new()
    column.add_child(nav)
    for name in ["SHOP","CRATES","HEROES","BAG"]:
        var b := button(nav,name,show_tab.bind(name))
        b.custom_minimum_size.x = 200
        tabs[name] = b
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 480
    column.add_child(scroll)
    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation",12)
    scroll.add_child(content)
    rebuild()

func skin(bg: Color, edge: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = edge
    s.set_border_width_all(1)
    s.set_corner_radius_all(10)
    s.content_margin_left = 16
    s.content_margin_right = 16
    s.content_margin_top = 12
    s.content_margin_bottom = 12
    return s

func text(parent: Node, value: String, font_size: int = 18) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size",font_size)
    parent.add_child(label)
    return label

func paragraph(parent: Node, value: String) -> Label:
    var label := text(parent,value)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func button(parent: Node, value: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = value
    b.custom_minimum_size.y = 48
    b.add_theme_stylebox_override("normal",skin(Color("253b43"),Color("536d6a")))
    b.add_theme_stylebox_override("pressed",skin(Color("536346"),Color("f2c365")))
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func card(parent: Node, color: Color) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.custom_minimum_size.x = 268
    panel.add_theme_stylebox_override("panel",skin(Color("192d35"),color))
    parent.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation",8)
    panel.add_child(column)
    return column

func show_tab(name: String) -> void:
    tab = name
    rebuild()

func request(action: String, id: String = "") -> void:
    action_requested.emit(action,id)

func rebuild() -> void:
    if not is_instance_valid(content):
        return
    balance.text = "%d CREDITS" % state.credits
    for name in tabs:
        tabs[name].modulate = Color("f2c365") if name == tab else Color.WHITE
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    paragraph(content,message).modulate = Color("f2d99b")
    if tab == "SHOP":
        paragraph(content,"Earn credits by defending the base and completing missions. All purchases use game credits.")
        var grid := GridContainer.new()
        grid.columns = 2
        content.add_child(grid)
        for id in DATA.SHOP:
            var item: Dictionary = DATA.SHOP[id]
            var c := card(grid,Color("6c827c"))
            text(c,item.name,22)
            paragraph(c,item.description)
            text(c,"In bag: %d" % int(state.bag[id]))
            var b := button(c,"BUY  /  %d CREDITS" % int(item.price),request.bind("BUY",id))
            b.disabled = state.credits < int(item.price) or int(state.bag[id]) >= 9999
    elif tab == "CRATES":
        text(content,"HERO CRATE  /  %d available" % int(state.bag.hero_crate),24)
        paragraph(content,"GREEN 60%  |  BLUE 25%  |  PURPLE 12%  |  GOLD 3%\nEach tier has 2 heroes with equal chances. After 29 non-gold results, the next crate is GOLD (100%). Any gold resets the guarantee.")
        text(content,"Gold guaranteed within %d crates  /  Opened %d" % [30-state.pity,state.opened])
        var row := HBoxContainer.new()
        content.add_child(row)
        button(row,"OPEN 1 CRATE",request.bind("OPEN","")).disabled = int(state.bag.hero_crate) <= 0
        button(row,"BUY CRATE  /  200 CREDITS",request.bind("BUY","hero_crate")).disabled = state.credits < 200
        if not result.is_empty():
            var hero: Dictionary = state.hero_by_id(result.id)
            var c := card(content,DATA.COLORS[int(hero.rarity)])
            var portrait := PORTRAIT.new()
            portrait.hero = hero
            portrait.custom_minimum_size = Vector2(0,132)
            c.add_child(portrait)
            text(c,DATA.RARITIES[int(hero.rarity)]+"  /  "+str(hero.name),26).modulate = DATA.COLORS[int(hero.rarity)]
            paragraph(c,"DUPLICATE: +10 hero shards" if result.duplicate else "NEW HERO UNLOCKED! Select HEROES to assign your commander.")
            c.modulate.a = 0
            c.create_tween().tween_property(c,"modulate:a",1.0,0.4)
        if not state.history.is_empty():
            text(content,"RECENT RESULTS",18)
            for entry in state.history:
                var hero: Dictionary = state.hero_by_id(entry.id)
                text(content,"%s  /  %s%s" % [DATA.RARITIES[int(hero.rarity)],hero.name,"  +10 shards" if entry.duplicate else "  NEW"],16).modulate = DATA.COLORS[int(hero.rarity)]
    elif tab == "HEROES":
        paragraph(content,"Assign ONE commander. Their fire-rate and damage-reduction bonuses apply during defense. Duplicates grant 10 shards; use matching shards to level up (maximum level 5).")
        var grid := GridContainer.new()
        grid.columns = 4
        content.add_child(grid)
        for hero in DATA.HEROES:
            var c := card(grid,DATA.COLORS[int(hero.rarity)])
            var portrait := PORTRAIT.new()
            portrait.hero = hero
            portrait.custom_minimum_size = Vector2(0,132)
            c.add_child(portrait)
            text(c,DATA.RARITIES[int(hero.rarity)],15).modulate = DATA.COLORS[int(hero.rarity)]
            text(c,hero.name,20)
            text(c,hero.role,14)
            var owned: bool = state.owned.has(hero.id)
            var level: int = int(state.owned[hero.id].level) if owned else 1
            var growth: float = 1.0+(level-1)*0.2
            text(c,"Fire rate +%d%%\nBase damage -%d%%" % [roundi(hero.attack*growth*100),roundi(minf(0.70,hero.defense*growth)*100)],16)
            if owned:
                text(c,"Lv.%d  /  Shards %d" % [level,state.owned[hero.id].shards],16)
                var assigned: bool = state.equipped == hero.id
                button(c,"ASSIGNED" if assigned else "ASSIGN",request.bind("EQUIP",hero.id)).disabled = assigned
                var b := button(c,"MAX LEVEL" if level >= 5 else "LEVEL UP  /  %d SHARDS" % (20*level),request.bind("UPGRADE_HERO",hero.id))
                b.disabled = level >= 5 or int(state.owned[hero.id].shards) < 20*level
            else:
                text(c,"LOCKED  /  Find in hero crates",15)
    else:
        paragraph(content,"Items stay in your bag until used. A boost needs active training; repair needs a damaged base. Items are kept if they cannot be used.")
        for id in DATA.SHOP:
            var c := card(content,Color("6c827c"))
            text(c,"%s  x%d" % [DATA.SHOP[id].name,state.bag[id]],22)
            paragraph(c,DATA.SHOP[id].description)
            button(c,"OPEN CRATES" if id == "hero_crate" else "USE ITEM",request.bind("USE",id)).disabled = int(state.bag[id]) <= 0
