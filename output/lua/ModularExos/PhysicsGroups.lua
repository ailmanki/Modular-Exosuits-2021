-- Appends the "ShieldGroup" to the PhysicsGroup enum
debug.appendtoenum(PhysicsGroup, "ShieldGroup")

-- A table that defines which masks should collide
local masksThatShouldCollide = { Bullets = true, PredictedProjectileGroup = true }

-- Iterates over each key-value pair in the PhysicsMask table
for maskKey, maskValue in pairs(PhysicsMask) do
    -- Checks if the key is a string and if it should not collide
    if type(maskKey) == "string" and not masksThatShouldCollide[maskKey] then
        -- Updates the maskValue to exclude the ShieldGroup from the mask
        PhysicsMask[maskKey] = bit.band(maskValue, bit.bnot(bit.lshift(1, PhysicsGroup.ShieldGroup - 1)))
    end
end

-- Appends the "MarineBullets" to the PhysicsMask enum, excluding the ShieldGroup from the mask
debug.appendtoenum(PhysicsMask, "MarineBullets", bit.band(PhysicsMask.Bullets, bit.bnot(bit.lshift(1, PhysicsGroup.ShieldGroup - 1))))

-- Appends the "MarinePredictedProjectileGroup" to the PhysicsMask enum, excluding the ShieldGroup from the mask
debug.appendtoenum(PhysicsMask, "MarinePredictedProjectileGroup", bit.band(PhysicsMask.PredictedProjectileGroup, bit.bnot(bit.lshift(1, PhysicsGroup.ShieldGroup - 1))))

