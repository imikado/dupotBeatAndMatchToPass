extends Node

signal player_health_changed(new_value)

signal actor_took_damage(actor, damage)

signal actor_took_damage_by_bullet(actor, damage, bullet)

signal actor_let_item(actor)

signal actor_health_changed(actor, previous_value, new_value)

signal player_launch_mana_attack(player)

# mana dépensée hors orage (attaque lourde) : le niveau met le HUD à jour
signal player_mana_changed(player_index)

signal player_took_lifebottle(bottle, player)

signal player_tookadvantage_of_lifebottle(player)

signal player_gameover

signal actor_struck_by_lightning(actor)

# power-up d'attaque ou de mana ramassé sur le trajet (PowerUp.gd)
signal player_took_power_up(power_up, player)

# choix d'arme : demandé depuis le HUD (clic / toucher sur l'icône), puis appliqué par le joueur
signal weapon_select_requested(player_index, weapon)
signal player_weapon_changed(player_index)
