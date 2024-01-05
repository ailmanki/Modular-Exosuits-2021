function PlayerUI_GetExoRepairAvailable()
    
    local player = Client.GetLocalPlayer()
    
    if player and player:GetIsPlaying() and player:isa("Exo") and player.GetRepairAllowed then
        
        return player:GetRepairAllowed(), player:GetFuel() >= kExoRepairMinFuel, player.repairActive
    
    end
    
    return false, false, false

end

function PlayerUI_GetExoThrustersAvailable()
    
    local player = Client.GetLocalPlayer()
    
    if player and player:GetIsPlaying() and player:isa("Exo") and player.GetIsThrusterAllowed then
        
        return player:GetIsThrusterAllowed(), player:GetFuel() >= kExoThrusterMinFuel, player.thrustersActive
    
    end
    
    return false, false, false

end

--function PlayerUI_GetExoShieldAvailable()
--
--    local player = Client.GetLocalPlayer()
--
--    if player and player:GetIsPlaying() and player:isa("Exo") and player.GetShieldAllowed then
--
--        return player:GetShieldAllowed(), player:GetFuel() >= kExoShieldMinFuel, player.shieldActive
--
--    end
--
--    return false, false, false
--
--end

function PlayerUI_GetExoCatPackAvailable()
    
    local player = Client.GetLocalPlayer()
    
    if player and player:GetIsPlaying() and player:isa("Exo") and player.GetCatPackAllowed then
        
        return player:GetCatPackAllowed(), player:GetFuel() >= kExoCatPackMinFuel, player.catpackActive
    
    end
    
    return false, false, false

end

function PlayerUI_GetHasThrusters()
    
    local player = Client.GetLocalPlayer()
    if player and player:GetIsPlaying() and player:isa("Exo") and player.GetHasThrusters then
        return player:GetHasThrusters()
    end
    return false

end

function PlayerUI_GetHasNanoShield()
    
    local player = Client.GetLocalPlayer()
    
    if player and player:GetIsPlaying() and player:isa("Exo") and player.GetHasShield then
        return player:GetHasShield()
    end
    
    return false

end

function PlayerUI_GetHasNanoRepair()
    local player = Client.GetLocalPlayer()
    if player and player:GetIsPlaying() and player:isa("Exo") and player.GetHasRepair then
        return player:GetHasRepair()
    end
    return false
end

function PlayerUI_GetHasCatPack()
    local player = Client.GetLocalPlayer()
    if player and player:GetIsPlaying() and player:isa("Exo") and player.GetHasCatPack then
        return player:GetHasCatPack()
    end
    return false
end