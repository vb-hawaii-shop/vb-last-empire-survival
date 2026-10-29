extends RefCounted

# Offline prototype economy. Credits have no cash value or payment integration.
const RARITIES = ["UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
const COLORS = [Color("61c47a"),Color("64b8f5"),Color("b990f7"),Color("f2c365")]
const HEROES = [
    {"id":"scout", "name":"SCOUT NOVA", "rarity":0, "role":"Recon specialist", "attack":0.10, "defense":0.04},
    {"id":"guard", "name":"GUARD FLINT", "rarity":0, "role":"Gate defender", "attack":0.06, "defense":0.10},
    {"id":"ranger", "name":"RANGER KAI", "rarity":1, "role":"Precision fire", "attack":0.24, "defense":0.08},
    {"id":"engineer", "name":"ENGINEER IVY", "rarity":1, "role":"Fortification expert", "attack":0.12, "defense":0.20},
    {"id":"viper", "name":"VIPER RAVEN", "rarity":2, "role":"Assault commander", "attack":0.45, "defense":0.16},
    {"id":"sentinel", "name":"SENTINEL ATLAS", "rarity":2, "role":"Armored guardian", "attack":0.25, "defense":0.32},
    {"id":"titan", "name":"TITAN REX", "rarity":3, "role":"Legendary warlord", "attack":0.80, "defense":0.20},
    {"id":"aurora", "name":"AURORA SOL", "rarity":3, "role":"Legendary protector", "attack":0.60, "defense":0.35}
]
const SHOP = {
    "hero_crate":{"name":"HERO CRATE", "price":200, "description":"One random hero. Includes a 30-crate gold guarantee."},
    "supply_pack":{"name":"SUPPLY PACK", "price":80, "description":"Use from Bag: +250 food, +250 oil, +250 metal."},
    "speedup":{"name":"TRAINING BOOST", "price":50, "description":"Use from Bag: instantly finish your current training."},
    "repair_kit":{"name":"BASE REPAIR KIT", "price":60, "description":"Use from Bag: restore 40 base health."}
}
var credits: int = 1000
var bag: Dictionary = {"hero_crate":3,"supply_pack":1,"speedup":1,"repair_kit":1}
var owned: Dictionary = {}
var equipped: String = ""
var pity: int = 0
var opened: int = 0
var history: Array = []
var rng := RandomNumberGenerator.new()

func _init() -> void:
    rng.randomize()

func hero_by_id(id: String) -> Dictionary:
    for hero in HEROES:
        if hero.id == id:
            return hero
    return {}

func buy(id: String) -> bool:
    if not SHOP.has(id):
        return false
    var price: int = SHOP[id].price
    if credits < price or int(bag[id]) >= 9999:
        return false
    credits -= price
    bag[id] = int(bag[id])+1
    return true

# Rolls 0..9999. Two heroes per tier, each equally likely within that tier.
func rarity_for_roll(roll: int) -> int:
    if roll < 6000:
        return 0
    if roll < 8500:
        return 1
    if roll < 9700:
        return 2
    return 3

func open_crate() -> Dictionary:
    if int(bag.hero_crate) <= 0:
        return {}
    bag.hero_crate = int(bag.hero_crate)-1
    var rarity: int = 3 if pity >= 29 else rarity_for_roll(rng.randi_range(0,9999))
    var id: String = HEROES[rarity*2+rng.randi_range(0,1)].id
    var duplicate: bool = owned.has(id)
    if duplicate:
        owned[id].shards = mini(99999,int(owned[id].shards)+10)
    else:
        owned[id] = {"level":1,"shards":0}
    if equipped.is_empty():
        equipped = id
    pity = 0 if rarity == 3 else pity+1
    opened += 1
    var result := {"id":id,"rarity":rarity,"duplicate":duplicate}
    history.push_front(result)
    if history.size() > 10:
        history.resize(10)
    return result

func equip(id: String) -> bool:
    if not owned.has(id):
        return false
    equipped = id
    return true

func upgrade(id: String) -> bool:
    if not owned.has(id):
        return false
    var level: int = owned[id].level
    var cost: int = 20*level
    if level >= 5 or int(owned[id].shards) < cost:
        return false
    owned[id].shards = int(owned[id].shards)-cost
    owned[id].level = level+1
    return true

func bonuses() -> Vector2:
    if not owned.has(equipped):
        return Vector2.ZERO
    var hero: Dictionary = hero_by_id(equipped)
    var growth: float = 1.0 + (int(owned[equipped].level)-1)*0.2
    return Vector2(float(hero.attack)*growth,minf(0.70,float(hero.defense)*growth))

func to_dict() -> Dictionary:
    return {"credits":credits,"bag":bag.duplicate(true),"owned":owned.duplicate(true),"equipped":equipped,"pity":pity,"opened":opened,"history":history.duplicate(true)}

func load_data(value: Variant) -> void:
    if not value is Dictionary:
        return
    credits = clampi(int(value.get("credits",1000)),0,9999999)
    pity = clampi(int(value.get("pity",0)),0,29)
    opened = clampi(int(value.get("opened",0)),0,9999999)
    var saved_bag = value.get("bag",{})
    if saved_bag is Dictionary:
        for id in bag:
            bag[id] = clampi(int(saved_bag.get(id,bag[id])),0,9999)
    owned.clear()
    var saved_owned = value.get("owned",{})
    if saved_owned is Dictionary:
        for id in saved_owned:
            if hero_by_id(str(id)).is_empty() or not saved_owned[id] is Dictionary:
                continue
            owned[id] = {"level":clampi(int(saved_owned[id].get("level",1)),1,5),"shards":clampi(int(saved_owned[id].get("shards",0)),0,99999)}
    equipped = str(value.get("equipped",""))
    if not owned.has(equipped):
        equipped = ""
    history.clear()
    var saved_history = value.get("history",[])
    if saved_history is Array:
        for entry in saved_history:
            if entry is Dictionary and not hero_by_id(str(entry.get("id",""))).is_empty():
                var hero := hero_by_id(str(entry.id))
                history.append({"id":hero.id,"rarity":hero.rarity,"duplicate":bool(entry.get("duplicate",false))})
                if history.size() == 10:
                    break
