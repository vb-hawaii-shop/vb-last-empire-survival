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
