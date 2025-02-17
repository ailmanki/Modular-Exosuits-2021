--________________________________
--
--  NS2: Combat
--    Copyright 2014 Faultline Games Ltd.
--  and Unknown Worlds Entertainment Inc.
--
--________________________________

class 'ArmoryAbility' (Entity)

local kExtents = Vector(0.4, 0.5, 0.4) -- 0.5 to account for pathing being too high/too low making it hard to palce tunnels

local function IsPathable(position)

    local noBuild = Pathing.GetIsFlagSet(position, kExtents, Pathing.PolyFlag_NoBuild)
    local walk = Pathing.GetIsFlagSet(position, kExtents, Pathing.PolyFlag_Walk)
    return not noBuild and walk
    
end

local kUpVector = Vector(0, 1, 0)
local kCheckDistance = 0.8 -- bigger than onos
local kVerticalOffset = 0.3
local kVerticalSpace = 2

local kCheckDirections = 
{
    Vector(kCheckDistance, 0, -kCheckDistance),
    Vector(kCheckDistance, 0, kCheckDistance),
    Vector(-kCheckDistance, 0, kCheckDistance),
    Vector(-kCheckDistance, 0, -kCheckDistance),
}

function ArmoryAbility:GetIsPositionValid(position, player, surfaceNormal)
    
    local valid = false

    --/ allow only on even surfaces
    if surfaceNormal then
    
        if not IsPathable(position) then
            valid = false
			
        elseif surfaceNormal:DotProduct(kUpVector) > 0.9 then
        
            valid = true
			
	
			
            local startPos = position + Vector(0, kVerticalOffset, 0)
        
            for i = 1, #kCheckDirections do
            
                local traceStart = startPos + kCheckDirections[i]
            
                local trace = Shared.TraceRay(traceStart, traceStart - Vector(0, kVerticalOffset + 0.1, 0), CollisionRep.Default, PhysicsMask.AllButPCsAndRagdolls, EntityFilterOneAndIsa(player, "Babbler"))
            
                if trace.fraction < 0.60 or trace.fraction >= 1.0 then --the max slope a sentry can be placed on.
                    valid = false
                    break
                end
            
            end
        
        
        end

    end
    
    return valid
end

function ArmoryAbility:AllowBackfacing()
    return false
end

function ArmoryAbility:GetDropRange()
    return kGorgeCreateDistance
end

function ArmoryAbility:GetStoreBuildId()
    return false
end

function ArmoryAbility:GetEnergyCost(player)
    return kDropStructureEnergyCost
end

function ArmoryAbility:GetGhostModelName(ability)
    return WeaponCache.kModelName
end

function ArmoryAbility:GetDropStructureId()
    return kTechId.WeaponCache
end

function ArmoryAbility:GetSuffixName()
    return "Armory"
end

function ArmoryAbility:GetDropClassName()
    return "WeaponCache"
end

function ArmoryAbility:GetDropMapName()
    return WeaponCache.kMapName
end

function ArmoryAbility:CreateStructure()
	return false
end
function ArmoryAbility:IsAllowed(player)
	return true
end
