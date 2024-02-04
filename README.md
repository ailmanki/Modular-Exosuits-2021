Scatter's Modular Exos (based on the one from 2014 by Scatter). This mod allows you to customize your Exo in the Prototype Lab menu.


General
* Exo can jump by default, does not start with thrusters


Weapons
* Readded single-version weapons again
* Mix and match weapons per side with the exclusion that the minigun model can never mix with the railgun (model limitation) and no dual-claw/fist
* Added welder (uses railgun model) - behaves precisely like a regular welder
* Added flamethrower (uses railgun model) - behavior like a regular flamethrower but uses heat up mechanics instead of fuel.
* Added Exo Shield (uses the claw weapon)- Absorbs ranged attacks protecting marines behind it while heat isn't full. Recharges out of combat.
* Railgun
    - Dual railguns can fire simultaneously
    - Non-charge damage increased to 35 from 10
* Minigun
    - Base damage increased to 8 from 6
    - Heat-up rate halved


Modules
* Armour modules add an extra 250 armor with a 0.15 weight penalty. This is applied AFTER armor upgrades
* Thruster module (shift only, no spacebar) much more maneuverable than vanilla with a weight penalty of 0.05. Affected by weight with the same formula.
* Phase module enables exos to use phase gates and also be beaconed with a weight penalty of 0.1
* Nano Repair module enables repair for cost of fuel with a weight penalty of 0.1
* Catalyst ability, when active, gives nearby marines the catalyst effect for up to 6 seconds. They lose it if the Exo dies, fuel runs out, or Exo deactivates it.
* Nano Shield ability, when active, gives nearby marines the nano shield (-50% damage) effect for up to 6 seconds. They lose it if the Exo dies, fuel runs out, or Exo deactivates it.


Costing
* Claw 5
* Welder 15
* Shield 15
* Railgun 30
* Minigun 30
* Flamethrower 30
* Armor module 15
* Phase module 15
* Nano repair module 20
* Thruster 20
* Nano Shield 20
* Catalyst pack 20


Weight and speed

* Weight per weapon weight affects speed according to the formula  Base Speed * (1 - Sum(inv weight))(this is no different to vanilla)
* Exo base speed increased to 8
* Claw 0
* Welder 0.02
* Shield 0.1
* Railgun 0.05
* Minigun 0.15
* Flamethrower 0.15
* Armor module 0.15
* Phase module 0.1
* Nano repair module 0.1
* Thruster 0.05
* Nano Shield 0.1
* Catpack 0.1


Sample weight calculation

Single Railgun + Thruster = 8 * (1 - (0.05 + 0.05)) = 7.2
Dual Minigun + Armor module = 8 * (1 - (0.15 + 0.15 + 0.1)) = 4.8
Flame + Railgun + Phase module = 8 * (1-(0.15 + 0.05 + 0.1) = 5.6






Limitations: The flamethrower and welder use the railgun model. Therefore, you cannot mix a minigun with a welder, flamethrower, or railgun. Maybe one day, someone will sort out some extra models.

Credit to xDragon for active abilities and their GUI (including thruster, nano repair, and nano shield).

