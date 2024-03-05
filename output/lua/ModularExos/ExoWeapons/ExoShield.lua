Script.Load("lua/LiveMixin.lua")
Script.Load("lua/Weapons/Marine/ExoWeaponHolder.lua")
Script.Load("lua/Weapons/Marine/ExoWeaponSlotMixin.lua")
Script.Load("lua/TechMixin.lua")
Script.Load("lua/TeamMixin.lua")
Script.Load("lua/EntityChangeMixin.lua")
Script.Load("lua/NanoShieldMixin.lua")

class 'ExoShield'(Entity)

ExoShield.kMapName = "exoshield"

-- shield state: undeployed --*toggle*   -> deployed
--               deployed   --*delay*    -> active
--               active     --*overheat* -> overheated --*delay* -> deployed
--               active     --*toggle*   -> deployed   --*delay* -> undeployed
-- combat state: idle       --*damage*   -> combat     --*delay* -> idle

-- TODO: Move balance-related stuff into ModularExo_Balance.lua
-- up
ExoShield.kShieldAngleYawMin = math.rad(70) -- left
ExoShield.kShieldAngleYawMax = math.rad(70) -- right

function generateShieldPosition(numColumns, numRows)
    local shieldPosition = {}
    
    for i = 0, numColumns - 1 do
        local x = i / (numColumns - 1) -- normalize to 0-1 range
        for j = 0, numRows - 1 do
            local y = j / (numRows - 1) -- normalize to 0-1 range
                -- first and last column/row only have center position
                table.insert(shieldPosition, {x, y})
        end
    end
    
    return shieldPosition
end
local shieldPosition = {
    --first column
    { 0, 0.5 },
    --second column
    { 0.25, 0.25 },
    { 0.25, 0.75 },
    --third column
    { 0.5, 0 },
    { 0.5, 0.5 },
    { 0.5, 1 },
    --fourth column
    { 0.75, 0.25 },
    { 0.75, 0.75 },
    --fifth column
    { 1, 0.5 }
}

shieldPosition = generateShieldPosition(12,12)
local cinematicCount = #shieldPosition

--ExoShield.kHexagonIdleCinematic = PrecacheAsset("cinematics/modularexo/exoshield_hexagon_idle.cinematic")
--ExoShield.kHexagonBreakCinematic = PrecacheAsset("cinematics/modularexo/exoshield_hexagon_break.cinematic")
ExoShield.kHexagonModelP = PrecacheAsset("models/marine/hexagon/hexagon3.model")
ExoShield.kHexagonModel = PrecacheAsset("models/marine/hexagon/hexagon3.model")
--ExoShield.kHexagonMaterial = PrecacheAsset("models/marine/hexagon/hexagon.material")
ExoShield.kHexagonMaterial = PrecacheAsset("materials/biodome/biodome_ground.material")
--ExoShield.kHexagonModel = PrecacheAsset("models/exoshield_hexagon.model")
--ExoShield.kHexagonMaterial = PrecacheAsset("models/exoshield_hexagon.material")
ExoShield.kShieldPitchUpDeadzone = math.rad(10)
ExoShield.kShieldPitchUpLimit = math.rad(30)
ExoShield.kShieldDistance = 2.2
ExoShield.kShieldHeightMin = 2-- down
ExoShield.kShieldHeightMax = 1

local ExoShieldkShieldAngleYawMaxMin = (ExoShield.kShieldAngleYawMin + ExoShield.kShieldAngleYawMax)
local ExoShieldkShieldHeightMaxMin = (ExoShield.kShieldHeightMax + ExoShield.kShieldHeightMin)




local networkVars = {
    heatAmount             = "float (0 to 1 by 0.01)", -- current shield heat
    isShieldDesired        = "boolean", -- if the user wants the shield up (click to toggle)
    isShieldDeployed       = "boolean", -- if the shield is "powered" (may not be active)
    isShieldActive         = "boolean", -- if the shield is currently active
    isShieldOverheated     = "boolean", -- if the shield is currently cooling down from an overheat
    shieldDeployChangeTime = "time", -- the time the shield was deployed/undeployed
    lastHitTime            = "time", -- the last time damage was done to the shield
}

--AddMixinNetworkVars(TechMixin, networkVars)
AddMixinNetworkVars(ExoWeaponSlotMixin, networkVars)
AddMixinNetworkVars(LiveMixin, networkVars)
AddMixinNetworkVars(TeamMixin, networkVars)
AddMixinNetworkVars(NanoShieldMixin, networkVars)

function ExoShield:OnCreate()
    
    PROFILE("ExoShield:OnCreateRender")
    
    Entity.OnCreate(self)
    
    --InitMixin(self, TechMixin)
    InitMixin(self, EntityChangeMixin)
    InitMixin(self, LiveMixin)
    InitMixin(self, TeamMixin)
    InitMixin(self, ExoWeaponSlotMixin)
    InitMixin(self, NanoShieldMixin)
    
    self.heatAmount = 0
    self.isShieldDesired = false
    self.isShieldDeployed = false
    self.isShieldOverheated = false
    self.shieldDeployChangeTime = 0
    self.lastHitTime = 0
    
    self.isShieldActive = false
    self.idleHeatAmount = 0
    self.isInCombat = false
    
    self.isPhysicsActive = false
    
    --self.contactEntityIdList = {}
    --self.contactEntityIdMap = {}
    
    if Client then
        self.shieldEffectScalar = 0
    end
    
    --self:SetUpdates(true)
end
function ExoShield:OnInitialized()

end
function ExoShield:GetTechId()
    return nil
end
function ExoShield:OnDestroy()
    Entity.OnDestroy(self)
    self:DestroyPhysics()
    if Client then
        if self.shieldModel then
            Client.DestroyRenderModel(self.shieldModel)
            self.shieldModel = nil
        end
        if self.clawLight then
            Client.DestroyRenderLight(self.clawLight)
            self.clawLight = nil
        end
        if self.cinematicList then
            for cinematicI, cinematic in ipairs(self.cinematicList) do
                Client.DestroyRenderModel(cinematic)
                cinematic = nil
                --Client.DestroyCinematic(cinematic)
            end
            self.cinematicList = nil
        end
        if self.heatDisplayUI then
            Client.DestroyGUIView(self.heatDisplayUI)
            self.heatDisplayUI = nil
        end
    end
end

function ExoShield:OnPrimaryAttack(player)
    if not player:GetPrimaryAttackLastFrame() then
        self.isShieldDesired = not self.isShieldDesired -- toggle desired state
    end
end
function ExoShield:OnPrimaryAttackEnd(player)
    self.isShieldDesired = false
end

function ExoShield:UpdateHeat(dt)
    
    
    self.isInCombat = (Shared.GetTime() < self.lastHitTime + ExoShield.kCombatDuration)
    local cooldownRate = (
            self.isShieldOverheated and ExoShield.kHeatOverheatedDrainRate
                    or not self.isShieldDeployed and ExoShield.kHeatUndeployedDrainRate
                    or self.isInCombat and ExoShield.kHeatCombatDrainRate
                    or ExoShield.kHeatActiveDrainRate
    )
    if self.isShieldOverheated and self.heatAmount <= ExoShield.kOverheatCooldownGoal then
        self.isShieldOverheated = false
    end
    local minHeat = 0
    if self.isShieldDeployed then
        local baseHeatScalar = Clamp((Shared.GetTime() - self.shieldDeployChangeTime) / ExoShield.kIdleBaseHeatMaxDelay, 0, 1)
        minHeat = minHeat + ExoShield.kIdleBaseHeatMin + (ExoShield.kIdleBaseHeatMax - ExoShield.kIdleBaseHeatMin) * baseHeatScalar
        if self.isInCombat then
            minHeat = minHeat + ExoShield.kCombatBaseHeatExtra
        end
        minHeat = Clamp(minHeat + math.sin(Shared.GetTime()) * 0.06, 0, 1)
    end
    self.idleHeatAmount = minHeat
    
    if self.heatAmount >= 1 then
        self.isShieldOverheated = true
    end
    if Server then
        self.heatAmount = Clamp(self.heatAmount - cooldownRate * dt, minHeat, 1)
    end
end

function ExoShield:AbsorbDamage(damage)
    self.heatAmount = self.heatAmount + ExoShield.kHeatPerDamage * damage
    Print("ExoShield:AbsorbDamage: damage %s! (%s)", damage, self.heatAmount)
    self.lastHitTime = Shared.GetTime()
end
function ExoShield:AbsorbProjectile(projectileEnt)
    if projectileEnt:isa("Bomb") then
        Print("ExoShield:AbsorbProjectile: Bomb")
        projectileEnt:TriggerEffects("bomb_absorb")
        self:AbsorbDamage(kBileBombDamage * ExoShield.kCorrodeDamageScalar)
    elseif projectileEnt:isa("WhipBomb") then
        Print("ExoShield:AbsorbProjectile: WhipBomb")
        projectileEnt:TriggerEffects("whipbomb_absorb")
        self:AbsorbDamage(kWhipBombardDamage * ExoShield.kCorrodeDamageScalar)
        self.lastHitTime = Shared.GetTime()
    end
end
function ExoShield:OverrideTakeDamage(damage, attacker, doer, point, direction, armorUsed, healthUsed, damageType, preventAlert)
    Print("ExoShield:OverrideTakeDamage: damage %s!", damage)
    self:AbsorbDamage(damage)
    return false, false, 0.0001 -- must be >0 if you want damage numbers to appear
end
--function ExoShield:GetIsEntityZappable(ent)
--    return HasMixin(ent, "Live") and ent:GetIsAlive()--and ent:GetTeam() == kAlienTeamType and HasMixin(ent, "Energy")
--end
--function ExoShield:StartZappingEntity(ent)
--    Print("ExoShield:StartZappingEntity: New entity %s (%s) in contact", ent:GetId(), ent:GetClassName())
--    if Client then
--        if #self.contactEntityIdList == 1 then
--            if not self.contactSoundEffect then
--                self.contactSoundEffect = Client.CreateSoundEffect(Shared.GetSoundIndex("sound/NS2.fev/marine/grenades/pulse/explode"))--"sound/NS2.fev/ambient/neon light loop"))
--                self.contactSoundEffect:SetParent(self:GetId())
--                self.contactSoundEffect:SetCoords(Coords.GetTranslation(self:GetShieldCoords(0.5, 0.5).origin))
--                self.contactSoundEffect:SetPositional(true)
--                self.contactSoundEffect:SetRolloff(SoundSystem.Rolloff_Linear)
--                self.contactSoundEffect:SetMinDistance(0)
--                self.contactSoundEffect:SetMaxDistance(10)
--
--                self.contactSoundEffect:SetVolume(1)
--                --self.contactSoundEffect:SetPitch(self.pitch)
--            end
--            self.contactSoundEffect:Start()
--        end
--    end
--end
--function ExoShield:StopZappingEntity(ent)
--    Print("ExoShield:StopZappingEntity")
--    if Client then
--        if #self.contactEntityIdList == 0 then
--            self.contactSoundEffect:Stop()
--        end
--    end
--end
--
--function ExoShield:UpdateZapping(deltaTime)
--
--    for entI, entId in ipairs(self.contactEntityIdList) do
--        local ent = Shared.GetEntity(entId)
--        if HasMixin(ent, "Energy") then
--            ent:AddEnergy(-ent:GetMaxEnergy() * ExoShield.kContactEnergyDrainRatePercent * deltaTime)
--            ent:AddEnergy(-ExoShield.kContactEnergyDrainRateFixed * deltaTime)
--        end
--    end
--
--end

function ExoShield:GetIsNanoShielded()
    return true
end

function ExoShield:GetOwner()
    return self:GetParent()
end
function ExoShield:GetIsShieldActive()
    return self.isShieldActive
end
function ExoShield:GetShieldTeam()
    return kMarineTeamType
end
function ExoShield:GetShieldProjectorCoordinates()
    local player = self:GetParent()
    local playerViewCoords = player:GetViewCoords()
    local playerAngles = Angles()
    playerAngles:BuildFromCoords(playerViewCoords)
    
    playerAngles.pitch = Clamp(playerAngles.pitch + ExoShield.kShieldPitchUpDeadzone, -ExoShield.kShieldPitchUpLimit, 0)
    
    local projectorCoords = playerAngles:GetCoords() -- GetViewCoords seems to twitch when used directly..
    projectorCoords.origin = playerViewCoords.origin
    
    return projectorCoords, playerAngles
end
function ExoShield:GetShieldDistance()
    return ExoShield.kShieldDistance
end
function ExoShield:GetShieldAngleExtents()
    return ExoShield.kShieldAngleYawMin, ExoShield.kShieldAngleYawMax
end

--function ExoShield:OnUpdate(deltaTime)
function ExoShield:ProcessMoveOnWeapon(player, input)
    
    PROFILE("ExoShield:ProcessMoveOnWeapon")
    
    local deltaTime = input.time
    local time = Shared.GetTime()
    
    if self.isShieldDesired and not self.isShieldOverheated then
        if not self.isShieldDeployed and time > self.shieldDeployChangeTime + ExoShield.kShieldToggleDelay then
            self.isShieldDeployed = true
            self.shieldDeployChangeTime = time
        end
    elseif self.isShieldDeployed and time > self.shieldDeployChangeTime + ExoShield.kShieldToggleDelay then
        self.isShieldDeployed = false
        self.shieldDeployChangeTime = time
    end
    
    self.isShieldActive = (self.isShieldDeployed and time > self.shieldDeployChangeTime + ExoShield.kShieldOnDelay)
    self:UpdateHeat(deltaTime)
    --self:UpdateZapping(deltaTime)
    
    self:UpdatePhysics(deltaTime)

end

function ExoShield:UpdatePhysics()
    PROFILE("ExoShield:UpdatePhysics")
    
    if self.isShieldActive and not self.isPhysicsActive then
        self:CreatePhysics()
    elseif not self.isShieldActive and self.isPhysicsActive then
       -- self:DestroyPhysics()
    end
    
    if self.isShieldActive then
        local projectorCoords, projectorAngles = self:GetShieldProjectorCoordinates()
        
        for physBodyI, physBody in ipairs(self.physBodyList) do
            -- server side
            local xFraction = shieldPosition[physBodyI][1]
            local yFraction = shieldPosition[physBodyI][2]
            
            local newAngles = Angles(projectorAngles)
            newAngles.yaw = newAngles.yaw - ExoShield.kShieldAngleYawMin + xFraction * ExoShieldkShieldAngleYawMaxMin
            
            -- Calculate the forward offset based on the shield distance
            local forwardOffset = newAngles:GetCoords().zAxis * ExoShield.kShieldDistance
            
            -- Reset the pitch angle
            newAngles.pitch = 0
            
            -- Get the coordinates from the adjusted angles
            local newCoords = newAngles:GetCoords()
            
            -- Adjust the origin of the shield coordinates based on the projector coordinates, forward offset, and yFraction
            newCoords.origin = (
                    projectorCoords.origin
                            + forwardOffset
                            + Vector(0, -ExoShield.kShieldHeightMin + yFraction * ExoShieldkShieldHeightMaxMin, 0)
            )
            
            physBody:SetCoords(newCoords)
            local direction = Vector(0, 0, 0)
            physBody:AddImpulse(self:GetOrigin(), direction)
       end
    end
end
function ExoShield:CreatePhysics()
    if Client then
        Print("Client: ExoShield:CreatePhysics")
    end
    if Server then
        Print("Server: ExoShield:CreatePhysics")
    end
    if not self.isPhysicsActive then
        self.isPhysicsActive = true
        self.physBodyList = {}
        local projectorCoords = self:GetShieldProjectorCoordinates()
        
        for cinematicI = 1, cinematicCount do
            local physBody = Shared.CreatePhysicsModel(ExoShield.kHexagonModel, true, projectorCoords, self)
            
            
            --physBody:SetEntity(self)
            physBody:SetPhysicsType(CollisionObject.Dynamic)
            physBody:SetGroup(PhysicsGroup.ShieldGroup)
            physBody:SetTriggeringEnabled(true)
            physBody:SetCollisionEnabled(true)
            physBody:SetGravityEnabled(false)
            
            if Client then
                -- Create the render model
                local renderModel = Client.CreateRenderModel(RenderScene.Zone_Default)
                renderModel:SetModel(ExoShield.kHexagonModel)
                renderModel:InstanceMaterials()
                physBody:SetEntity(renderModel)
                table.insert(self.cinematicList, renderModel)
            end
            table.insert(self.physBodyList, physBody)
        end
    end
end
function ExoShield:DestroyPhysics()
    if self.isPhysicsActive then
        for _, renderModel in ipairs(self.cinematicList) do
            Client.DestroyRenderModel(renderModel)
        end
        
        -- Now destroy physics bodies
        for _, physBody in ipairs(self.physBodyList) do
            Shared.DestroyCollisionObject(physBody)
        end
        
        -- Clear the lists
        self.physBodyList = {}
        self.cinematicList = {}
        
        self.isPhysicsActive = false
    end
end

local clawLightColorCold = Color(0, 0.7, 1, 1)
local clawLightColorHot = Color(1, 0, 0, 1)
local hexagonSize = 0.1
local hexagonModelSize = Vector(hexagonSize, hexagonSize, hexagonSize)
local rate = 11 + 3 * (2 * math.random() - 1)
local angRate = math.pi * 2 * math.pi * 2 / (4 + 1 * (2 * math.random() - 1))

function ExoShield:OnUpdateRender()
    PROFILE("ExoShield:OnUpdateRender")
    
    --Print("meow")
    local time = Shared.GetTime()
    local lastTime = self.lastOnUpdateRenderTime or 0
    local deltaTime = time - lastTime
    self.lastOnUpdateRenderTime = time
    
    local delay = self.isShieldDeployed and ExoShield.kShieldEffectOnDelay or ExoShield.kShieldEffectOffDelay
    self.shieldEffectScalar = Clamp((time - self.shieldDeployChangeTime) / delay, 0, 1)
    --Print(tostring(self.shieldDeployChangeTime))
    if not self.isShieldDeployed then
        self.shieldEffectScalar = 1 - self.shieldEffectScalar
    end
    
    
    --local player = self:GetParent()
    if not self.clawLight then
        self.clawLight = Client.CreateRenderLight()
        self.clawLight:SetType(RenderLight.Type_Point)
        self.clawLight:SetCastsShadows(false)
        self.clawLight:SetAtmosphericDensity(1)
        self.clawLight:SetSpecular(0)
    end
    self.clawLight:SetIsVisible(self.shieldEffectScalar > 0)
    self.clawLight:SetRadius(10 * self.shieldEffectScalar)
    self.clawLight:SetIntensity(15 * self.shieldEffectScalar)
    self.clawLight:SetColor(LerpColor(clawLightColorCold, clawLightColorHot, self.heatAmount))
    local clawLightCoords = self:GetShieldCoords(0.5, 0.5)
    self.clawLight:SetCoords(clawLightCoords)
    ----
    ----if Client then
    ----    Print("Client: ExoShield:OnUpdateRender")
    ----end
    ----if Server then
    ----    Print("Server: ExoShield:OnUpdateRender")
    ----end
    --local projectorCoords, projectorAngles = self:GetShieldProjectorCoordinates()
    --if not self.cinematicList then
    --    self.cinematicList = {}
    --    self.cinematicCoordsList = {}
    --    for cinematicI = 1, cinematicCount do
    --
    --        local model = Client.CreateRenderModel(RenderScene.Zone_Default)
    --        model:SetModel(ExoShield.kHexagonModel)
    --        --model.model = ExoShield.kHexagonModel
    --        --model:SetIsVisible(false)
    --        --model:InstanceMaterials()
    --        --Print(model:GetOverrideMaterialName(0))
    --
    --        --model:AddMaterial(ExoShield.kHexagonMaterial)
    --
    --        model:InstanceMaterials()
    --
    --        --local cinematic = Client.CreateCinematic(RenderScene.Zone_Default)
    --        --cinematic:SetCinematic(ExoShield.kHexagonIdleCinematic)
    --        --cinematic:SetRepeatStyle(Cinematic.Repeat_Endless)
    --
    --        self.cinematicList[cinematicI] = model
    --
    --        local coords = Coords.GetIdentity()
    --        coords.xAxis, coords.yAxis, coords.zAxis = projectorCoords.xAxis, projectorCoords.yAxis, projectorCoords.zAxis
    --        coords.origin = projectorCoords.origin
    --
    --        coords.xAxis, coords.yAxis, coords.zAxis = coords.xAxis * 10, coords.yAxis * 10, coords.zAxis * 10
    --        local angles = Angles()
    --        angles:BuildFromCoords(coords)
    --        self.cinematicList[cinematicI]:SetCoords(coords)
    --
    --        -- Set the visibility of the cinematic based on whether the shield is active or not
    --        self.cinematicList[cinematicI]:SetIsVisible(true)
    --        self.cinematicCoordsList[cinematicI] = { coords, angles }
    --    end
    --end
    --if self.cinematicList and self.isShieldActive then
    --
    --    local filter = EntityFilterTwo(self, self:GetParent())
    --
    --    for cinematicI = 1, cinematicCount do
    --        -- Retrieve the x and y fractions from the shieldPosition table using the cinematic index
    --        --[[local xFraction = shieldPosition[cinematicI][1]
    --        local yFraction = shieldPosition[cinematicI][2]
    --
    --        -- Create a new Angles object from the projectorAngles
    --        local newAngles = Angles(projectorAngles)
    --
    --        -- Adjust the yaw angle of the new Angles object based on the xFraction
    --        -- This is done by subtracting the minimum shield angle yaw from the current yaw angle
    --        -- and then adding the product of the xFraction and the difference between the maximum and minimum shield angle yaws
    --        newAngles.yaw = newAngles.yaw - ExoShield.kShieldAngleYawMin + xFraction * ExoShieldkShieldAngleYawMaxMin
    --
    --        -- Calculate the forward offset based on the shield distance
    --        local forwardOffset = newAngles:GetCoords().zAxis * ExoShield.kShieldDistance
    --
    --        -- Reset the pitch angle
    --        newAngles.pitch = 0
    --
    --        -- Get the coordinates from the adjusted angles
    --        local newCoords = newAngles:GetCoords()
    --
    --        -- Adjust the origin of the shield coordinates based on the projector coordinates, forward offset, and yFraction
    --        newCoords.origin = (
    --                projectorCoords.origin
    --                        + forwardOffset
    --                        + Vector(0, -ExoShield.kShieldHeightMin + yFraction * ExoShieldkShieldHeightMaxMin, 0)
    --        )
    --
    --        -- Retrieve the previous coordinates and angles from the cinematicCoordsList
    --        local prevCoords, prevAngles = unpack(self.cinematicCoordsList[cinematicI])
    --
    --        ------------------------------
    --        local trace = Shared.TraceBox(
    --                hexagonModelSize,
    --                projectorCoords.origin, newCoords.origin,
    --        --prevCoords.origin, newCoords.origin,
    --                CollisionRep.Default, PhysicsMask.Movement, filter
    --        --CollisionRep.Default, PhysicsMask.MarineBullets, filter
    --        )
    --        if trace.fraction ~= 1 then
    --            --local normal = -trace.normal
    --            --newAngles.yaw = math.atan2(normal.x, normal.z)
    --            --newCoords.origin = trace.endPoint
    --            local f = Clamp((trace.fraction-0.8)*5, 0, 1)
    --            newCoords.xAxis = newCoords.xAxis*f
    --            newCoords.yAxis = newCoords.yAxis*f
    --            newCoords.zAxis = newCoords.zAxis*f
    --        end
    --        --Print("trace.fraction: %f", trace.fraction)
    --        self.cinematicList[cinematicI]:SetMaterialParameter("dmgAmount", trace.fraction)
    --
    --        --self.cinematicList[cinematicI]:SetMaterialParameter("inwall", trace.fraction)
    --        ---------------------
    --        -- Slerp (spherical linear interpolation) between the previous angles and the new angles
    --        -- This is done to smoothly transition from the previous angles to the new angles over time
    --        local angles = SlerpAngles(prevAngles, newAngles, angRate * deltaTime)
    --
    --        -- Get the coordinates from the adjusted angles
    --        local coords = angles:GetCoords()
    --
    --        --coords.xAxis, coords.yAxis, coords.zAxis = coords.xAxis *10, coords.yAxis*10, coords.zAxis*10
    --        -- Slerp between the previous coordinates and the new coordinates
    --        -- This is done to smoothly transition from the previous coordinates to the new coordinates over time
    --        coords.origin = SlerpVector(prevCoords.origin, newCoords.origin, rate * deltaTime)
    --        coords.xAxis, coords.yAxis, coords.zAxis = newCoords.xAxis, newCoords.yAxis, newCoords.zAxis
    --        -----------
    --
    --        -- Update the cinematicCoordsList with the new coordinates and angles
    --        self.cinematicCoordsList[cinematicI] = { coords, angles }]]
    --
    --        if self.physBodyList[cinematicI] then
    --            -- Set the coordinates of the cinematic to the new coordinates
    --            self.cinematicList[cinematicI]:SetCoords(self.physBodyList[cinematicI]:GetPosition():GetCoords())
    --
    --            -- Set the visibility of the cinematic based on whether the shield is active or not
    --            self.cinematicList[cinematicI]:SetIsVisible(self.isShieldActive)
    --
    --        end
    --    end
    --end
    --
    local parent = self:GetParent()
    if parent and parent:GetIsLocalPlayer() then
        local heatDisplayUI = self.heatDisplayUI
        if not heatDisplayUI then
            heatDisplayUI = Client.CreateGUIView(242 + 64, 720)
            heatDisplayUI:Load("lua/ModularExos/GUI/GUILeftShieldDisplay.lua")
            heatDisplayUI:SetTargetTexture("*exo_claw_left")
            self.heatDisplayUI = heatDisplayUI
        end
        heatDisplayUI:SetGlobal("heatAmountleft", self.heatAmount)
        heatDisplayUI:SetGlobal("idleHeatAmountleft", self.idleHeatAmount)
        heatDisplayUI:SetGlobal("shieldStatusleft", (
                self.isShieldOverheated and "overheat"
                        or not self.isShieldDesired and "off"
                        or self.isInCombat and "combat"
                        or "on"
        ))
    end
end

--- Get the coordinates of the shield based on the fractions provided.
-- This function calculates the coordinates of the shield based on the fractions of the yaw and pitch angles.
-- @param xFraction The fraction of the yaw angle. Defaults to 0.5 if not provided.
-- @param yFraction The fraction of the pitch angle. Defaults to 0.5 if not provided.
-- @return shieldCoords The calculated coordinates of the shield.
function ExoShield:GetShieldCoords(xFraction, yFraction)
    
    local projectorCoords, projectorAngles = self:GetShieldProjectorCoordinates()
    
    -- Adjust the yaw angle based on the xFraction
    projectorAngles.yaw = projectorAngles.yaw - ExoShield.kShieldAngleYawMin + xFraction * ExoShieldkShieldAngleYawMaxMin
    
    
    -- Calculate the forward offset based on the shield distance
    local forwardOffset = projectorAngles:GetCoords().zAxis * ExoShield.kShieldDistance
    
    -- Reset the pitch angle
    projectorAngles.pitch = 0
    
    -- Get the coordinates from the adjusted angles
    local shieldCoords = projectorAngles:GetCoords()
    
    -- Adjust the origin of the shield coordinates based on the projector coordinates, forward offset, and yFraction
    shieldCoords.origin = (
            projectorCoords.origin
                    + forwardOffset
                    + Vector(0, -ExoShield.kShieldHeightMin + yFraction * ExoShieldkShieldHeightMaxMin, 0)
    )
    
    return shieldCoords
end

function ExoShield:GetSurfaceOverride(dmg)
    -- alternatively: "electronic", "armor", "flame", "ethereal", "hallucination", "structure"
    return "nanoshield"
end

function ExoShield:OnTag(tagName)
    PROFILE("ExoShield:OnTag")
    local player = self:GetParent()
    if player then
        if tagName == "hit" then
        elseif tagName == "claw_attack_start" then
            --player:TriggerEffects("claw_attack")
        end
    end
end

function ExoShield:OnUpdateAnimationInput(modelMixin)
    --modelMixin:SetAnimationInput("activity_" .. self:GetExoWeaponSlotName(), self.isShieldActive)
end

function ExoShield:GetWeight()
    return kExoShieldWeight
end

-- to fix a bug
function ExoShield:GetExoWeaponSlotName()
    return "left"
end
function ExoShield:GetIsLeftSlot()
    return true
end
function ExoShield:GetIsRightSlot()
    return false
end
function ExoShield:GetExoWeaponSlot()
    return ExoWeaponHolder.kSlotNames.Left
end

Shared.LinkClassToMap("ExoShield", ExoShield.kMapName, networkVars)


