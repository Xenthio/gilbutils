# GilbUtils

Shared GMod addon providing reusable HL1-accurate base code for AI-generated content.

## Features

- **`hl1_hgib`** entity — HL1-accurate gib with `MOVETYPE_CUSTOM` manual physics (bounce, tumble, ground friction, blood decals)
- **`GilbUtils.Gibs`** library — simple API for exploding any entity into gibs

## API

```lua
-- Explode any entity into HL1 gibs on death
GilbUtils.Gibs.Explode(ent, dmg)

-- Explode with options
GilbUtils.Gibs.Explode(ent, dmg, {
    model   = "models/gibs/hghl1.mdl",  -- gib model
    count   = 4,                          -- number of body gibs
    headGib = true,                       -- spawn a head gib
})

-- Spawn a single gib manually
GilbUtils.Gibs.SpawnGib(model, bodygroup, pos, vel, bloodColor)
```

## Usage Example

```lua
-- Make NPCs explode into HL1 gibs on death
hook.Add("OnNPCKilled", "HL1GibNPCs", function(npc, attacker, inflictor)
    GilbUtils.Gibs.Explode(npc)
    npc:Remove()
end)

-- Make players gib on death
hook.Add("PlayerDeath", "HL1GibPlayers", function(ply, inflictor, attacker)
    GilbUtils.Gibs.Explode(ply)
end)
```

## Physics Notes

- `MOVETYPE_CUSTOM` — all physics driven manually in `Think()`, not VPhysics
- `GIB_ELASTICITY = 0.45` — from HL1's `pev->friction = 0.55`
- `AngVelocity` is zeroed permanently on first floor contact — required to prevent floor spinning
- Blood decals fire on every airborne collision, max 5 per gib
