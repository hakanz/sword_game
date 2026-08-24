# Save System — Technical Detail

`SaveManager` (autoload). Offline-first, local only, zero server dependency (charter §31).
Tamper-protection is an explicit non-goal for a single-player game.

## Files
- `user://settings.cfg` — app settings (locale, bus volumes). ConfigFile.
- `user://save_slot_1.json` — the player profile. **Versioned JSON**, never serialized
  Resources (foreign Resource files can execute embedded scripts; JSON cannot).

## Envelope + versioning
```json
{ "save_version": 4, "profile": { ...PlayerProfile.to_dict()... } }
```
Rules (mandatory):
- Bump `SaveManager.SAVE_VERSION` whenever the persisted shape changes.
- Add exactly one `_migrate_vN_to_vN+1()` step; the loader chains them.
- Saves from NEWER versions are refused (never guess forward). Corrupt files load as null.
- `PlayerProfile.from_dict()` defaults every missing field — migrations only need to
  handle semantic moves, not defaults.

## Migration history
| v | change | migration |
|---|---|---|
| 0 | pre-versioning dev format (bare profile dict) | wrap into envelope |
| 1 | initial release shape | — |
| 2 | + `inventory_weapon_ids`, `inventory_armour_ids` (equipment phase) | empty satchels |
| 3 | + `known_skill_ids` (skill phase) | none known; banked points stay |
| 4 | + `defeated_champion_ids` (arena phase) | empty record |
| 5 | + `selected_arena_id`, `completed_tournament_arena_ids` | default arena; an already-beaten Maulhilda credits the Gravelmaw tournament |

## Autosave points (charter §31)
After battle rewards, after purchases/sales, after equip changes, after attribute
confirm, after learning a skill. Never mid-combat-action.

## Smoke/CI safety
`--smoke-test` sets `disk_writes_enabled = false`: headless runs never touch a real
player's save or settings. Tests overriding `profile_path` restore it and delete their
temp file.
