extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var save_path := "user://save.json"
    var existed := FileAccess.file_exists(save_path)
    var original := FileAccess.get_file_as_string(save_path) if existed else ""
    if existed:
        DirAccess.remove_absolute(save_path)
    var game = load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    check(game.food == 600 and game.troops == 10,"Fresh game resources")
    game.do_action("UPGRADE")
    check(game.levels.HQ == 2 and game.food == 520,"Upgrade charges resources")
    game.claim_mission()
    check(game.mission == 1 and game.food == 670,"HQ mission reward")
    game.claim_mission()
    check(game.mission == 1 and game.food == 670,"No repeated claim")
    game.do_action("TRAIN")
    var paid_food: int = game.food
    game.do_action("TRAIN")
    check(game.food == paid_food and game.troops == 10,"Training queue cannot duplicate")
    game._process(12.0)
    check(game.troops == 15 and game.training == 0,"Training completes after delay")
    game.claim_mission()
    check(game.mission == 2,"Army mission")
    game.start_wave()
    check(game.fighting and game.enemies.size() == 8,"First wave spawns")
    game.start_wave()
    check(game.enemies.size() == 8,"Cannot start overlapping wave")
    for i in range(1200):
        if not game.fighting:
            break
        game._process(0.05)
    check(not game.fighting and game.victories == 1 and game.health > 0,"Wave resolves through actual combat")
    check(game.troops < 15 and game.cooldown > 0,"Casualties and recovery applied")
    game.claim_mission()
    check(game.mission == 3,"Victory mission")
    game.start_wave()
    check(not game.fighting,"Cooldown blocks a new wave")
    game.cooldown = 0
    game.troops = 100
    game.start_wave()
    for enemy in game.enemies:
        enemy.node.position.z = 21
    game.health = 0.1
    game.update_battle(0.1)
    check(not game.fighting and game.health == 0,"Overrun resolves as defeat")
    var wins: int = game.victories
    game.cooldown = 0
    game.start_wave()
    check(not game.fighting and game.victories == wins,"Destroyed base blocks attack")
    game.metal = 100
    game.do_action("REPAIR")
    check(game.health == 40 and game.metal == 40,"Repair enables recovery")
    game.food = 0
    game.selected = "HQ"
    game.do_action("UPGRADE")
    check(game.levels.HQ == 2,"Cannot upgrade without resources")
    game.save_game()
    game.health = 99
    game.load_game()
    check(game.health == 40 and game.mission == 3,"Save reload preserves progress")
    var f := FileAccess.open(save_path,FileAccess.WRITE)
    f.store_string('{"steel":75,"kills":4,"levels":{"HQ":0,"Farm":999},"troops":-2}')
    f.close()
    game.load_game()
    check(game.metal == 75 and game.victories == 4,"V1.1 saves migrate")
    check(game.levels.HQ == 1 and game.levels.Farm == 20 and game.troops == 0,"Loaded values are bounded")
    # Mall: economy, exact rarity weights, pity, duplicates, assignment and persistence.
    game.show_mall()
    await process_frame
    check(is_instance_valid(game.mall_ui),"Mall opens")
    var store_state = game.mall
    check(store_state.credits == 1000 and store_state.bag.hero_crate == 3,"Old save gets starter gifts")
    var weights := [0,0,0,0]
    for roll in range(10000):
        weights[store_state.rarity_for_roll(roll)] += 1
    check(weights == [6000,2500,1200,300],"Displayed rates match all roll intervals")
    store_state.credits = 200
    game.mall_action("BUY","hero_crate")
    check(store_state.credits == 0 and store_state.bag.hero_crate == 4,"Purchase charges exact price")
    game.mall_action("BUY","hero_crate")
    check(store_state.credits == 0 and store_state.bag.hero_crate == 4,"Insufficient balance cannot buy")
    game.mall_action("USE","speedup")
    check(store_state.bag.speedup == 1,"Unused training boost is preserved")
    game.food = 100
    game.oil = 40
    game.do_action("TRAIN")
    var before_troops: int = game.troops
    game.mall_action("USE","speedup")
    check(game.training == 0 and game.troops == before_troops+5 and store_state.bag.speedup == 0,"Boost completes exactly one training queue")
    game.mall_action("USE","speedup")
    check(game.troops == before_troops+5,"Used boost cannot grant soldiers again")
    game.health = 100
    game.mall_action("USE","repair_kit")
    check(store_state.bag.repair_kit == 1,"Full base keeps repair kit")
    game.health = 75
    game.mall_action("USE","repair_kit")
    check(game.health == 100 and store_state.bag.repair_kit == 0,"Repair kit caps base health")
    game.food = 0
    game.mall_action("USE","supply_pack")
    check(game.food == 250 and store_state.bag.supply_pack == 0,"Supply pack grants contents once")
    store_state.pity = 29
    store_state.rng.seed = 42
    game.mall_action("OPEN","")
    var gold_id: String = store_state.history[0].id
    check(store_state.history[0].rarity == 3 and store_state.pity == 0,"30th crate guarantees gold and resets pity")
    check(store_state.equipped == gold_id and is_instance_valid(game.hero_actor),"First hero is assigned and shown at base")
    var before_credits: int = store_state.credits
    for i in range(2):
        store_state.pity = 29
        store_state.rng.seed = 42
        game.mall_action("OPEN","")
    check(store_state.owned[gold_id].shards == 20,"Two duplicates become 20 matching shards")
    var bonus_before: Vector2 = store_state.bonuses()
    game.mall_action("UPGRADE_HERO",gold_id)
    check(store_state.owned[gold_id].level == 2 and store_state.owned[gold_id].shards == 0,"Hero upgrade consumes required shards")
    check(store_state.bonuses().x > bonus_before.x and store_state.bonuses().y > bonus_before.y,"Hero levels improve battle bonuses")
    game.mall_action("UPGRADE_HERO",gold_id)
    check(store_state.owned[gold_id].level == 2,"Cannot level up without shards")
    store_state.bag.hero_crate = 0
    game.mall_action("OPEN","")
    check(store_state.bag.hero_crate == 0 and store_state.credits == before_credits,"Empty crate cannot consume currency or grant hero")
    for tab in ["SHOP","CRATES","HEROES","BAG"]:
        game.mall_ui.show_tab(tab)
        await process_frame
        check(game.mall_ui.tab == tab,"Mall tab renders: "+tab)
    game.save_game()
    store_state.owned.clear()
    store_state.equipped = ""
    game.load_game()
    check(store_state.owned.has(gold_id) and store_state.owned[gold_id].level == 2 and store_state.equipped == gold_id,"Hero ownership, assignment and levels reload")
    var saved_mall: Dictionary = store_state.to_dict()
    game.load_game()
    check(store_state.to_dict() == saved_mall,"Reload does not repeat starter gifts")
    check(not store_state.equip("unknown"),"Cannot assign a locked or unknown hero")
    # Verify equipped hero changes actual incoming damage and attack cooldown.
    game.close_mall()
    await process_frame
    game.troops = 20
    game.health = 100
    game.cooldown = 0
    game.start_wave()
    for enemy in game.enemies:
        enemy.node.position.z = 21
    var enemy_count: int = game.enemies.size()
    game.shot_clock = 1
    game.update_battle(0.1)
    var expected_health: float = 100-enemy_count*0.25*(1-store_state.bonuses().y)
    check(absf(game.health-expected_health) < 0.001,"Equipped hero reduces actual damage")
    game.shot_clock = 0
    game.update_battle(0.001)
    check(game.shot_clock < 0.65/(1+20*0.045+int(game.levels.Barracks)*0.12),"Equipped hero increases actual firing rate")
    var credits_before_win: int = store_state.credits
    game.end_wave(true)
    check(store_state.credits > credits_before_win,"Victory awards mall credits")
    game.queue_free()
    await process_frame
    if existed:
        f = FileAccess.open(save_path,FileAccess.WRITE)
        f.store_string(original)
        f.close()
    else:
        DirAccess.remove_absolute(save_path)
    print("Gameplay checks finished: %d failures" % failures)
    quit(0 if failures == 0 else 1)
