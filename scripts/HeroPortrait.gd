extends Control

var hero: Dictionary = {}

func _draw() -> void:
    if hero.is_empty():
        return
    var palette = preload("res://scripts/Mall.gd").COLORS
    var tint: Color = palette[int(hero.rarity)]
    var center: float = size.x*0.5
    draw_rect(Rect2(Vector2.ZERO,size),Color("172a30"))
    draw_circle(Vector2(center,65),57,tint.darkened(0.65))
    # Original geometric commander portraits, drawn directly by the game.
    draw_colored_polygon(PackedVector2Array([Vector2(center-65,130),Vector2(center-52,96),Vector2(center-18,84),Vector2(center+18,84),Vector2(center+52,96),Vector2(center+65,130)]),tint.darkened(0.35))
    draw_rect(Rect2(center-10,75,20,24),Color("a98269"))
    draw_circle(Vector2(center,56),26,Color("c99e7f"))
    draw_rect(Rect2(center-28,27,56,21),tint.darkened(0.3))
    draw_rect(Rect2(center-34,44,68,6),tint)
    draw_rect(Rect2(center-17,57,10,4),Color("233a3c"))
    draw_rect(Rect2(center+7,57,10,4),Color("233a3c"))
    draw_line(Vector2(center-6,74),Vector2(center+7,74),Color("705449"),2)
    draw_line(Vector2(center-30,94),Vector2(center+13,130),Color("c0ae80"),7)
    draw_rect(Rect2(center+29,90,12,22),tint)
    if int(hero.rarity) >= 2:
        draw_line(Vector2(center-24,60),Vector2(center+23,60),Color("162a30"),10)
        draw_line(Vector2(center-19,60),Vector2(center-5,60),tint,3)
    if int(hero.rarity) == 3:
        for x in [-14.0,0.0,14.0]:
            draw_circle(Vector2(center+x,38),3,Color("fff2b0"))
    if hero.id in ["guard","sentinel","aurora","engineer"]:
        draw_circle(Vector2(center+43,106),13,tint.lightened(0.3))
        draw_line(Vector2(center+36,106),Vector2(center+50,106),Color("172a30"),3)
    else:
        draw_line(Vector2(center-48,123),Vector2(center+38,91),Color("111e24"),9)
    draw_rect(Rect2(Vector2.ZERO,size),tint,false,2)
