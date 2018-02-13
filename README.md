# factorio-prod-calc
A Factorio scenario (PvP) with an in-game production score calculator gui

Latest changes:

* Version 1.0.8 -- Feb. 12, 2018
  * Fixed resource ignore loop. Now it works correctly for mods.
  * Fixed crash when re-rolling map after using the calc gui
  * Fixed the disabled items table (scenario config) to not be so weird

* Version 1.0.7 -- Feb. 12, 2018
  * Fixed crash when selecting recipe with ingreadients that have a "nil" price
  * Seperated out locale files for easier merging of upstream changes

* Version 1.0.6 -- Feb. 12, 2018
  * Merged in changes from 0.16.23 release  
    key changes:
    * refactored config stuff
    * refactored wall stuff generation

    * removed valid origin check for force area charting
    * removed player starting inventory in favor of chests

    * added space race button
    * added allow admin to be spectator
    * added in-game reroll button
