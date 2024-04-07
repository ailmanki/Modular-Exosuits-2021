Script.Load("lua/LiveMixin.lua")
Script.Load("lua/Weapons/Marine/ExoWeaponHolder.lua")
Script.Load("lua/Weapons/Marine/ExoWeaponSlotMixin.lua")
Script.Load("lua/TechMixin.lua")
Script.Load("lua/TeamMixin.lua")
--Script.Load("lua/EntityChangeMixin.lua")
Script.Load("lua/Utility.lua")
class 'ExoShield'(Entity)

ExoShield.kMapName = "exoshield"

-- shield state: undeployed --*toggle*   -> deployed
--               deployed   --*delay*    -> active
--               active     --*overheat* -> overheated --*delay* -> deployed
--               active     --*toggle*   -> deployed   --*delay* -> undeployed
-- combat state: idle       --*damage*   -> combat     --*delay* -> idle


ExoShield.kModelNames = {
    PrecacheAsset("models/marine/hexagon/hexagon4_1.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_2.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_3.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_4.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_5.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_6.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_7.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_8.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_9.model"),
}
--ExoShield.kAttachPoint = "Exosuit_HoodHinge"


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
AddMixinNetworkVars(TechMixin, networkVars)
AddMixinNetworkVars(TeamMixin, networkVars)

function ExoShield:OnCreate()
    
    PROFILE("ExoShield:OnCreateRender")
    
    Entity.OnCreate(self)
    
    self.lastAttackApplyTime = 0
    InitMixin(self, ExoWeaponSlotMixin)
    InitMixin(self, TechMixin)
    --InitMixin(self, EntityChangeMixin)
    InitMixin(self, LiveMixin)
    InitMixin(self, TeamMixin)
    
    self.heatAmount = 0
    self.isShieldDesired = false
    self.isShieldDeployed = false
    self.isShieldOverheated = false
    self.shieldDeployChangeTime = 0
    self.lastHitTime = 0
    
    self.isShieldActive = false
    self.idleHeatAmount = 0
    self.isInCombat = false
    
    
    --self.contactEntityIdList = {}
    --self.contactEntityIdMap = {}
    
    if Client then
        self.shieldEffectScalar = 0
    end
    
    self:SetUpdates(true, kRealTimeUpdateRate)
    self:SetLagCompensated(true)
end

function ExoShield:OnInitialized()
    Entity.OnInitialized(self)
end

function ExoShield:OnDestroy()
    Entity.OnDestroy(self)
    self:DestroyPhysics()
    if Client then
        if self.clawLight then
            Client.DestroyRenderLight(self.clawLight)
            self.clawLight = nil
        end
        if self.cinematicList then
            for i = 1, #ExoShield.kModelNames do
                local cinematic = self.cinematicList[i]
                Client.DestroyRenderModel(cinematic)
                cinematic = nil
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
        self.isShieldDesired = true
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

function ExoShield:GetIsShieldActive()
    return self.isShieldActive
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
    self:UpdatePhysics(deltaTime)
    self:UpdateHeat(deltaTime)
end

function ExoShield:UpdatePhysics(deltaTime)
    if self.isShieldActive then
        self:CreatePhysics()
        self:MovePhysics()
    elseif not self.isShieldActive then
        self:DestroyPhysics()
    end
end

function ExoShield:MovePhysics()

    if self.physBodyList then
        local coords = self:GetCoords()
        local boneCoords = CoordsArray()
        boneCoords[1] = coords
        for i = 1, #ExoShield.kModelNames do
            local physBody = self.physBodyList[i]
            if physBody then
                physBody:SetBoneCoords(coords, boneCoords)
            end
        end
    end
end

function ExoShield:CreatePhysics()
    if self.physBodyList then
        return
    end
    self.physBodyList = {}
    for i = 1, #ExoShield.kModelNames do
        --Print("Creating physics for %s", ExoShield.kModelNames[i])
        local physBody = Shared.CreatePhysicsModel(ExoShield.kModelNames[i], true, self:GetCoords(), self)
        physBody:SetEntity(self)
        physBody:SetPhysicsType(CollisionObject.Kinematic)
        physBody:SetGroup(PhysicsGroup.ShieldGroup)
        --physBody:SetGroupFilterMask(PhysicsMask.None)
        physBody:SetCCDEnabled(true)
        physBody:SetTriggeringEnabled(true)
        physBody:SetCollisionEnabled(true)
        physBody:SetGravityEnabled(false)
        table.insert(self.physBodyList, physBody)
    end
end

function ExoShield:DestroyPhysics()
    if self.physBodyList then
        for i = 1, #ExoShield.kModelNames do
            local physBody = self.physBodyList[i]
            if physBody then
                Shared.DestroyCollisionObject(physBody)
                physBody = nil
                self.physBodyList[i] = nil
            end
        end
        self.physBodyList = nil
    end
end

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
    self.clawLight:SetColor(LerpColor(Color(0, 0.7, 1, 1), Color(1, 0, 0, 1), self.heatAmount))
    local coords = self:GetCoords()
    self.clawLight:SetCoords(coords)
    
    if not self.cinematicList then
        --Print("%s", self.cinematicList)
        self.cinematicList = {}
        local zone = self:GetMixinConstants().kRenderZone or RenderScene.Zone_Default;
        for i = 1, #ExoShield.kModelNames do
            local renderModel = Client.CreateRenderModel(zone)
            renderModel:SetModel(ExoShield.kModelNames[i])
            renderModel:SetCoords(coords)
            renderModel:SetIsVisible(true)
            table.insert(self.cinematicList, renderModel)
        end
    end
    
    if self.cinematicList then
        for i = 1, #ExoShield.kModelNames do
            local renderModel = self.cinematicList[i]
            renderModel:SetCoords(coords)
        end
    
    end
    
    local player = self:GetParent()
    if player and player:GetIsLocalPlayer() then
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

function ExoShield:GetSurfaceOverride(dmg)
    -- alternatively: "electronic", "armor", "flame", "ethereal", "hallucination", "structure"
    return "nanoshield"
end

function ExoShield:OnTag(tagName)
    PROFILE("ExoShield:OnTag")
    --Print(tagName)
    --local player = self:GetParent()
    --if player then
    --    if tagName == "hit" then
    --    elseif tagName == "claw_attack_start" then
    --        --player:TriggerEffects("claw_attack")
    --    end
    --end
end
--
--function ExoShield:OnUpdateAnimationInput(modelMixin)
--    --modelMixin:SetAnimationInput("activity_" .. self:GetExoWeaponSlotName(), self.isShieldActive)
--
--
--     self:UpdatePhysics()
--    return modelMixin
--end
--
--local oldExoShieldOnUpdate = ExoShield.OnUpdate

function ExoShield:GetWeight()
    return 0
end
--
function ExoShield:OnTriggerEntered(entA, entB)
    local ent = (entA == self and entB or entA)
    Print("Entity %s (%s) entered trigger", ent:GetId(), ent:GetClassName())
    --if not self.contactEntityIdMap[ent:GetId()] and self:GetIsEntityZappable(ent) then
    --    local i = #self.contactEntityIdList + 1
    --    self.contactEntityIdList[i] = ent:GetId()
    --    self.contactEntityIdMap[ent:GetId()] = i
    --    self:StartZappingEntity(ent)
    --end
end
function ExoShield:OnTriggerExited(entA, entB)
    local ent = (entA == self and entB or entA)
    Print("Entity %s (%s) exited trigger", ent:GetId(), ent:GetClassName())
    --if self.contactEntityIdMap[ent:GetId()] then
    --    self.contactEntityIdList[self.contactEntityIdMap[ent:GetId()]] = nil
    --    self.contactEntityIdMap[ent:GetId()] = nil
    --    self:StopZappingEntity(ent)
    --end
end
--function ExoShield:OnEntityChange(oldId, newId)
--    --if self.contactEntityIdMap[oldId] then
--    --    self.contactEntityIdList[self.contactEntityIdMap[oldId]] = nil
--    --    self.contactEntityIdMap[oldId] = nil
--    --    self:StopZappingEntity(ent)
--    --end
--end

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


