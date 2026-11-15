# Plan d'amélioration graphique : travail multi-agents

Ce plan découpe les améliorations graphiques en **lots indépendants**. Chaque lot est confié à un agent et **possède ses propres fichiers**. Deux agents ne modifient jamais le même fichier en même temps.

Le jeu est en pixel art 320×180 (`window/stretch/mode="canvas_items"`), sous Godot 4.7, pour Linux et le Web (HTML5).

## Règles communes à tous les agents

1. **Ne modifier que les fichiers listés dans « Possède »** de son lot. Pour un changement ailleurs, le noter dans le compte rendu final : c'est le lot propriétaire, ou l'humain, qui l'appliquera.
2. **Pas de commit, pas de push.** L'auteur relit et commite lui-même.
3. **Ne pas toucher** à `src/Levels/Level01.*`, `Level02.*`, `Level03.*`. Ces scènes ne sont plus chargées : le jeu utilise `LevelTemplate.tscn` (niveaux 1 à 3, selon la difficulté) et `LevelBonus.tscn`.
4. **Ne pas remplacer** `export/linux/screenshots/` ni `docs/media/`. Cela fait partie de la publication, que l'auteur gère.
5. **Garder le style pixel art** :
   - points arrondis au pixel (`.round()`) ;
   - `antialiased = false` sur les `Line2D` ;
   - filtre `NEAREST` (c'est déjà le défaut du projet).

   Pas de flou ni de dégradé lisse sur les sprites. Les halos additifs (`Fx.additive_material()`) sont acceptés.
6. **Rester léger pour le Web** :
   - préférer `CPUParticles2D` et les tweens ;
   - pas de `PointLight2D` supplémentaire sans raison ;
   - au maximum quelques dizaines de `Line2D` à l'écran.
7. **Imiter le code existant** : GDScript avec tabulations, typage léger, commentaires courts (en français ou en anglais, comme le fichier touché). Les effets réutilisables vont dans `src/Common/Effects/`.
8. **Pas de nouvelle image si on peut la générer par code.** Si un PNG est vraiment nécessaire (lot C), le générer avec un script Python (PIL) gardé dans `tools/`.
9. Les scènes de test temporaires vont dans `res://tmp_<lot>/` et sont **supprimées à la fin**.

### Vérification (chaque lot, avant de rendre la main)

```bash
# 1. Erreurs de script / de scène : lancer le jeu sans fenêtre quelques secondes
timeout 20 godot --headless --path . --quit-after 600 2>&1 | grep -E "SCRIPT ERROR|ERROR|Parse Error" || echo OK

# 2. Contrôle visuel : visite automatique (environ 3 min), captures dans un dossier temporaire
mkdir -p /tmp/shots_<lot> && timeout 600 godot --path . -- --screenshots=/tmp/shots_<lot> --tour
```

Ouvrir les captures `Screenshot_01..06.png` et les comparer aux captures actuelles de `export/linux/screenshots/` :

- `Screenshot_01` : l'orage ;
- `Screenshot_02` et `Screenshot_03` : combat et barrières ;
- `Screenshot_04` : voie libre ;
- `Screenshot_05` : niveau bonus ;
- `Screenshot_06` : titre.

Le compte rendu final de chaque lot donne :

- les fichiers modifiés ;
- ce qui a été vérifié, et comment ;
- les changements demandés hors de son périmètre ;
- les écarts restants.

---

## Ordre d'exécution

```
Phase 0 (lot 0, seul) ──┬──> Lot A  Orage
                        ├──> Lot B  Barrière électrique
                        ├──> Lot C  Décor
                        └──> Lot D  Ennemis
Lot E  HUD ─────────────────────────────────────> (indépendant, peut démarrer tout de suite)
                                   tout fini ──> Phase 2 (lot Z, seul) : intégration
```

- Les lots A, B, C et D démarrent **après** le lot 0, car ils utilisent `Bolt`, les fonctions `Fx` et le signal ajouté.
- Le lot E ne dépend de rien.

---

## Lot 0 : Fondations (un seul agent, en premier)

**But** : fournir les briques partagées pour qu'aucun lot n'ait besoin de modifier `Fx.gd`, `Events.gd` ou `project.godot`.

**Possède** :
- `project.godot`
- `src/Common/Effects/Fx.gd` (**figé** après ce lot)
- `src/Common/Autoload/Events.gd` (**figé** après ce lot)
- `src/Common/Effects/Bolt.gd` (nouveau)
- le nœud `WorldEnvironment` de `src/Levels/LevelTemplate.tscn` et de `src/Levels/LevelBonus.tscn` (uniquement la sous-ressource `Environment`)

**Tâches**

1. **Glow HDR 2D.** Ajouter `rendering/viewport/hdr_2d=true` dans `project.godot`. Aujourd'hui, le buffer 2D plafonne à 1.0, et `glow_hdr_threshold = 1.5` ne s'applique donc jamais. Ensuite :
   - régler l'`Environment` des deux scènes pour que seules les valeurs > 1 brillent, sans voile sur toute l'image (seuil autour de 1.0-1.2, intensité à ajuster) ;
   - vérifier qu'un sprite en `modulate = Color(2,2,2)` produit bien un halo ;
   - noter le résultat avec le renderer Mobile (`--rendering-method mobile`).

   Si le glow n'apporte rien ou coûte trop, le dire et revenir en arrière.

2. **`Bolt.gd`** (`class_name Bolt`, `extends Node2D`) : un éclair procédural réutilisable, dessiné avec 3 `Line2D` enfants.

   | Couche | Largeur | Couleur |
   |---|---|---|
   | Halo | 5-7 px | `color`, alpha 0.3, `Fx.additive_material()` |
   | Cœur | 2 px | `color` éclaircie |
   | Centre | 1 px | blanc, intensité HDR |

   API attendue (coordonnées locales) :

   ```gdscript
   @export var color := Color(0.55, 0.75, 1.0)
   @export var thickness := 1.0             # multiplicateur des 3 largeurs
   @export var jaggedness := 0.25           # déplacement max = longueur × jaggedness
   @export var branch_count := 1

   static func zigzag(from: Vector2, to: Vector2, offset: float, depth: int = 5) -> PackedVector2Array
   func set_ends(from: Vector2, to: Vector2) -> void   # garde la forme pour les prochains regenerate()
   func regenerate() -> void                            # nouvelle forme, mêmes extrémités, nouvelles branches
   func reveal(ratio: float) -> void                    # 0..1 : n'affiche que le début du tracé (traceur)
   func set_intensity(value: float) -> void             # 0 = invisible, 1 = normal, > 1 = HDR (glow)
   ```

   - `zigzag()` fait un déplacement du point milieu, avec des points arrondis au pixel.
   - Les branches partent d'un point au hasard du tracé principal, avec un `zigzag` plus court (`depth = 3`) dirigé vers « l'avant ». Elles sont plus fines et ont un halo plus faible.
   - Il faut aucune allocation lourde par image : `regenerate()` n'est appelé qu'à la demande.

3. **Nouvelles fonctions dans `Fx.gd`** (même style que `burst()`, `dust()`…) :
   - `Fx.ring(parent, global_pos, color, radius := 24.0, duration := 0.3)` : onde de choc, un anneau pixel aplati (rapport 1:0.4 pour le sol) qui grandit puis disparaît. Texture générée et mise en cache comme `_shadow_textures`.
   - `Fx.scorch(parent, global_pos, width := 14, duration := 1.2)` : marque brûlée ovale au sol, qui s'efface. Réutiliser le principe de `Fx.shadow`.
   - `Fx.trail(target: Node2D, color, length := 8) -> Line2D` : traînée courte qui suit un nœud. Utile pour l'orbe d'énergie (lot B).

4. **Nouveau signal dans `Events.gd`** : `signal actor_struck_by_lightning(actor)`. Le lot A l'émet, le lot D y réagit.

5. Créer une scène de test temporaire pour montrer `Bolt` (plusieurs éclairs régénérés toutes les 0,1 s), vérifier visuellement, puis la supprimer.

**Terminé quand** :
- `Bolt` s'affiche net (pixels francs) avec un halo ;
- le glow fonctionne, ou bien sa décision de retour arrière est documentée ;
- le jeu se lance sans erreur ;
- les captures sont identiques à avant (aucun changement de rendu, à part le glow).

---

## Lot A : Orage (attaque mana)

**Possède** :
- `src/Actors/Players/Player/ManaAttack/ManaFall.gd` et `ManaFall.tscn`
- `src/Actors/Players/Player/ManaAttack/` (nouveaux fichiers éventuels, par exemple `StormSky.gd`)
- dans `src/Actors/Players/Player.gd` : `build_storm_effects`, `mana_cast_begin`, `mana_cast_end`, `tint_world`, `storm_flash`, `storm_impact`, `mana_attack_start`, `mana_attack_end`, `fall`, `_on_ManaFall_fall_ended`
- dans `src/Actors/Players/Player.tscn` : le nœud `ManaFalling` et ses enfants, et l'animation `attacking_mana01`
- `src/Common/Autoload/ScreenshotTour.gd` : seulement `STORM_IMPACT_DELAY`, si le minutage change
- `src/Actors/Players/Player/lightning.png` (peut être supprimé s'il ne sert plus, avec son `.import`)

**Lecture seule** : `Bolt.gd`, `Fx.gd`, `Events.gd`.

**Constat** :
- l'éclair actuel est un sprite de 20×200 avec un trait de 1 px, sans halo, et un zigzag en « Z » régulier ;
- les 10 éclairs sont identiques, synchronisés, placés à des positions fixes, et les 3 salves se ressemblent ;
- les colonnes `_glow` (`column_texture`, scale 25) font des bandes verticales pâles qui ressemblent à des projecteurs.

**Tâches**

1. Remplacer l'`AnimatedSprite2D` et l'animation `storm` par un `Bolt`. **Garder sans changement** la hitbox, `display_impact()`, `hide_impact()` et le signal `fall_ended`. Le joueur et `PlayerStateAttackMana01` en dépendent.

2. Minutage d'une frappe, environ 0,35 s, piloté par un tween :

   | Moment | Phase | Effet |
   |---|---|---|
   | 0-0,10 s | traceur | `reveal(0→1)` par paliers, intensité 0.4 |
   | 0,10 s | décharge | `reveal(1)`, intensité ~2.5, `display_impact()` |
   | 0,13 s et 0,18 s | scintillement | `regenerate()`, intensité qui oscille |
   | 0,25-0,35 s | extinction | `thickness` et intensité vers 0 |

3. **Désynchroniser** : un délai aléatoire de 0 à 0,25 s par éclair.

4. **Positions** : à chaque salve, tirer de nouvelles positions dans un rectangle autour du joueur, sans que deux éclairs tombent à moins de 20 px l'un de l'autre. Environ 1 éclair sur 3 vise un ennemi proche (groupe `Game.GROUP_ENEMY`) s'il y en a un. Le haut de l'éclair démarre au-dessus de l'écran visible.

5. Supprimer les colonnes `_glow`. Les remplacer par :
   - un éclat bref au sol (le `_impact_glow` actuel peut rester) ;
   - `Fx.ring()` ;
   - `Fx.scorch()` ;
   - les étincelles (`Fx.burst`, déjà présent).

6. Émettre `Events.actor_struck_by_lightning(body)` dans `_on_HitBox_body_entered`, en plus du dégât existant.

7. **Ciel d'orage** : pendant `mana_cast_begin`, ajouter par code (comme `_canvas_modulate`) :
   - une bande de nuages sombres en haut de l'écran, qui arrive en fondu, avec des formes pixel générées par code ;
   - une pluie fine (`CPUParticles2D`, petits traits penchés, en espace caméra).

   Les nuages s'éclairent brièvement à chaque décharge. Tout est retiré dans `mana_cast_end`. **Ne pas modifier les scènes de niveau** (elles appartiennent au lot C). Tout passe par le joueur.

8. Ajuster le flash du monde (`storm_flash`) pour qu'il tombe sur les vraies décharges, et plus sur un minutage fixe.

**Terminé quand** :
- `Screenshot_01` montre des éclairs épais, ramifiés, différents les uns des autres, tombant à des moments différents ;
- il n'y a plus de bandes verticales dans le ciel ;
- les dégâts sur les ennemis sont toujours appliqués ;
- l'orage dure toujours environ 2 s, et le joueur reste invincible pendant ce temps.

---

## Lot B : Barrière électrique et orbes d'énergie

**Possède** :
- `src/Common/Levels/ElectricalBarrier.gd` et `ElectricalBarrier.tscn`
- `src/Common/Levels/ElectricalBarrier/barrier.tscn`
- `src/Common/Levels/Energy.gd` et `Energy.tscn`

**Lecture seule** : `Bolt.gd`, `Fx.gd` (`ENEMY_COLORS`, `trail`), `LevelTemplate.gd`.

**Constat** : la barrière est un `Line2D` marron de 3 px avec des points rouges qui tombent. Sur les captures, on dirait un poteau en bois. Rien ne dit « électrique ». C'est pourtant l'élément central du gameplay.

**Tâches**

1. Dans `barrier.tscn`, remplacer le `Line2D` marron et les particules rouges par :
   - 1 ou 2 `Bolt` verticaux (de `y = -4` à `y = 78`, comme aujourd'hui), régénérés toutes les 0,05-0,08 s, avec `jaggedness` faible et `branch_count` 0 ou 1 ;
   - un petit halo additif.

   Couleur : `Fx.enemy_color(type)`.

2. Le **niveau de charge** est visible : quand `energy_count / max_energy` monte, la barrière devient plus instable (jaggedness et fréquence de régénération en hausse, petites étincelles aux extrémités). Il ne faut pas que ça devienne illisible.

3. À chaque `increment()` : un arc bref et plus brillant, en plus du `pulse()` existant.

4. À l'ouverture (`energy_count == max_energy`) : un **court-circuit** d'environ 0,4 s (arcs brisés, `Fx.burst`, flash) avant `disable_barrier()`. Le signal `opened` et la collision doivent garder le même comportement **au même moment** : seul l'effet visuel se prolonge après.

5. `Energy.gd` : ajouter une traînée (`Fx.trail`) et teinter l'orbe avec la couleur de la barrière cible (`target.get_type()`). `LevelTemplate.gd` n'a pas besoin d'être modifié.

**Terminé quand** :
- sur `Screenshot_02` et `Screenshot_03`, les barrières se lisent clairement comme des arcs électriques de la couleur de l'ennemi demandé ;
- l'ouverture produit un effet visible ;
- l'ordre des signaux et des sons est inchangé.

---

## Lot C : Décor (ciel, arbres, sol)

**Possède** :
- `src/Levels/LevelTemplate.tscn` et `src/Levels/LevelBonus.tscn` (tout, **sauf** `WorldEnvironment`, qui reste tel que le lot 0 l'a laissé)
- `src/Levels/LevelTemplate/*.png`
- `src/Levels/ForestBackground.tscn` (nouveau) et ses scripts ou shaders
- `tools/` (nouveaux scripts de génération)

**Contrainte** : `Player.tint_world()` assombrit toutes les `ParallaxLayer` trouvées dans l'arbre. Le décor doit **rester en `ParallaxLayer`** pour que l'orage l'assombrisse toujours.

**Tâches**

1. **Factoriser** : `ParallaxBackground` et `ParallaxBackground2` sont dupliqués dans les deux scènes. Les extraire dans `ForestBackground.tscn`, instancié par les deux. La scène bonus peut changer de teinte par une propriété exportée.

2. **Perspective atmosphérique** : les 3 couches d'arbres utilisent la même texture `background-trees-up.png`. Teinter les couches lointaines (`motion_scale` faible) plus sombres et plus bleues, et la plus proche plus contrastée.

3. **Ciel** :
   - un dégradé vertical par paliers (pixel art, pas lisse) ;
   - une lune ;
   - une quinzaine d'étoiles qui scintillent, par code ou `CPUParticles2D` ;
   - des nuages qui défilent lentement.

4. **Sol** : la tuile 96×96 est un bruit vert très saturé et très haute fréquence, sur environ 60 % de l'écran. Il attire l'œil plus que les personnages. La régénérer avec un script `tools/generate_ground.py` (PIL) :
   - bruit plus doux, avec des taches plus larges ;
   - saturation plus basse ;
   - quelques détails rares (touffes, cailloux, fleurs) ;
   - raccord parfait sur les bords.

   Ajouter aussi :
   - un léger assombrissement vers la ligne d'arbres (overlay en dégradé par paliers au-dessus de la `TileMap`) pour la profondeur ;
   - une transition douce entre le sol et la ligne d'arbres, car la frontière actuelle est très nette.

5. **Premier plan** : les buissons sombres du bas oscillent légèrement (petit shader de vent sur `brushes`, déformation par colonne de pixels).

6. Ne **rien** changer aux positions de gameplay : `WalkingLimits`, `CameraLimitRect`, `Gate`, spawns, `ElectricalBarriers`.

**Terminé quand** :
- sur toutes les captures, les personnages se détachent mieux que le sol ;
- le ciel a de la profondeur ;
- l'orage assombrit toujours le décor ;
- les deux scènes partagent le même décor.

---

## Lot D : Ennemis (mort, impacts, barres de vie)

**Possède** :
- `src/Common/Abstract/Enemy.gd` et `src/Common/Abstract/BonusActor.gd`
- `src/Common/Effects/character.gdshader`
- `src/Actors/SimpleEnemies/*.tscn` et `src/Actors/BonusActors/Squirrel.tscn` (seulement le nœud `BodyPivot/Control/ProgressBar`)

**Lecture seule** : `Fx.gd`, `Events.gd`, `Game.gd`.

**Tâches**

1. **Mort** : aujourd'hui, l'ennemi clignote 4 fois puis disparaît (`Enemy.start_death`). Ajouter un uniform `dissolve` (0..1) dans `character.gdshader` :
   - dissolution par pixels, avec un motif de bruit à la résolution de la texture ;
   - bord coloré à la couleur de l'ennemi (`Fx.enemy_color`).

   Garder le contour et `depth_shade`. Remplacer le clignotement par la dissolution (environ 0,4 s) et un `Fx.burst` à la couleur de l'ennemi. `queue_free` à la fin, comme aujourd'hui.

2. **Touché par l'éclair** : écouter `Events.actor_struck_by_lightning`. Si c'est lui :
   - flash bleu-blanc ;
   - 2 ou 3 petits `Bolt` (environ 10 px) autour du sprite pendant 0,3 s.

   S'il meurt de l'éclair : silhouette noire carbonisée (uniform du shader ou `modulate`), puis dissolution en cendres grises.

3. **Barre de vie vide qui reste affichée** sous un ennemi mort (visible sur `Screenshot_04`) : trouver la cause (`Enemy.gd` cache la barre ligne 86, mais apparemment pas dans tous les cas) et la masquer dès que la mort commence.

4. Optionnel, si le temps le permet : un style pixel pour la `ProgressBar` des ennemis (fond sombre, bordure de 1 px, remplissage à la couleur de l'ennemi), dans le même esprit que `PixelBar.gd` du HUD, mais sans le modifier.

**Terminé quand** :
- les morts se dissolvent au lieu de clignoter ;
- les morts par éclair sont distinctes ;
- aucune barre vide ne traîne ;
- le contour des personnages est toujours là.

---

## Lot E : HUD et textes flottants (indépendant)

**Possède** :
- `src/Common/UI/HUD.gd`, `HUD.tscn`, `PixelBar.gd`
- `src/Actors/Players/ComboPlusOne.*` et `src/Actors/Players/Player/ComboBonus.*`
- les fonctions `manage_combo_for_actor` et `_on_combo_bonus_finished` de `src/Levels/LevelTemplate.gd`, seulement si la position des textes de combo y est décidée

**Tâches**

1. **« LEVEL 01 » et « 3 KILLS » se chevauchent** (captures 2 à 5). `_streak_label` est à `y = 13`, et le label `level` occupe `y = 1..14` avec une police plus grande. Décaler `_streak_label`, réduire le label du niveau, ou les mettre sur deux lignes nettes. Cela doit rester lisible à 320×180.
2. **« +10 » chevauche « COMBO! »** (captures 2 et 3) : séparer verticalement les deux textes, ou les décaler dans le temps.
3. **Barre de vie** : quand le joueur perd de la vie, garder une portion claire qui se vide en retard derrière la vraie valeur (« chip damage »).
4. **Barre de mana** : quand elle est pleine (l'orage est disponible), la faire scintiller ou pulser doucement, pour signaler que l'attaque est prête.
5. Le score qui augmente peut faire un petit « pop » d'échelle (il existe peut-être déjà ; vérifier avant d'ajouter).

**Terminé quand** : il n'y a plus aucun chevauchement de texte sur les 6 captures, et les barres donnent un retour visible.

---

## Phase 2 : Intégration (lot Z, un seul agent, à la fin)

**Possède** : rien a priori. Il corrige, avec l'accord de l'humain, les petits écarts signalés dans les comptes rendus.

1. Lire les comptes rendus des lots 0, A, B, C, D et E. Appliquer les changements demandés hors périmètre qui n'ont pas été faits, en le signalant.
2. Lancer la vérification complète (erreurs headless et visite automatique), et regarder les 6 captures ensemble. Vérifier :
   - la cohérence des couleurs (le bleu de l'éclair, du mana et de l'aura doit être le même) ;
   - l'intensité du glow, sans écran voilé ;
   - la lisibilité des personnages par-dessus le nouveau décor.
3. **Performance** : lancer `LevelTemplate.tscn` avec `--rendering-method mobile`. Déclencher l'orage au milieu d'une foule d'ennemis et noter les FPS (moniteur `Performance.TIME_FPS` dans un script de test temporaire). Il ne doit pas y avoir de chute nette par rapport à `main`.
4. Vérifier que les scènes du titre, du menu, du game over et de fin de niveau n'ont pas été touchées par erreur (`git diff --stat`).
5. Produire un résumé pour l'auteur :
   - ce qui a changé, par lot ;
   - les captures avant/après (chemins dans `/tmp`) ;
   - les points à décider.

   L'auteur décide ensuite de mettre à jour `export/linux/screenshots/`, `docs/media/` et le README, puis commite.

---

## Récapitulatif : qui possède quoi

| Fichier | Lot |
|---|---|
| `project.godot`, `Fx.gd`, `Events.gd`, `Bolt.gd` (nouveau) | 0 |
| `WorldEnvironment` de `LevelTemplate.tscn` et `LevelBonus.tscn` | 0 |
| `ManaAttack/*`, fonctions d'orage de `Player.gd`, `ManaFalling` et anim mana de `Player.tscn`, `STORM_IMPACT_DELAY` | A |
| `ElectricalBarrier*`, `barrier.tscn`, `Energy*` | B |
| Reste de `LevelTemplate.tscn` et `LevelBonus.tscn`, `LevelTemplate/*.png`, `ForestBackground.tscn`, `tools/` | C |
| `Enemy.gd`, `BonusActor.gd`, `character.gdshader`, `ProgressBar` des ennemis | D |
| `HUD.*`, `PixelBar.gd`, `ComboPlusOne.*`, `ComboBonus.*`, fonctions combo de `LevelTemplate.gd` | E |
| `Level01/02/03.*` (inutilisés) | personne |
