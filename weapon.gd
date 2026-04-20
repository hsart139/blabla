func _greatsword_dash():
    var collision_shape = $CollisionShape2D
    var current_position = position
    var dash_distance = 100  # You can adjust this value
    current_position += Vector2(dash_distance, 0).rotated(rotation)

    # Maintain collision
    collision_shape.position = current_position

    # Move player immediately
    position = current_position

    # Immediately deal damage to enemies
    deal_damage_to_enemies()