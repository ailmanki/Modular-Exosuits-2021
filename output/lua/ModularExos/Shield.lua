-- ======= Copyright (c) 2003-2013, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua\Shield.lua
--
--    Created by:   Andreas Urwalek (andi@unknownworlds.com)
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================

--Script.Load("lua/ScriptActor.lua")
--Script.Load("lua/Mixins/ClientModelMixin.lua")
Script.Load("lua/Mixins/ModelMixin.lua")
Script.Load("lua/LiveMixin.lua")
Script.Load("lua/TeamMixin.lua")
Script.Load("lua/DamageMixin.lua")
Script.Load("lua/EntityChangeMixin.lua")
Script.Load("lua/OwnerMixin.lua")
Script.Load("lua/PhysicsGroups.lua")
Script.Load("lua/GameEffectsMixin.lua")

class 'Shield' (ScriptActor)

Shield.kMapName = "shield"

--Shield.kModelName = PrecacheAsset("models/marine/hexagon/hexagon_head.model")
Shield.kAttachPoint = "Exosuit_HoodHinge"

--Shield.kModelName = PrecacheAsset("models/marine/hexagon/hexagon_1.model")
Shield.kModelNames = {
    PrecacheAsset("models/marine/hexagon/hexagon4_1.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_2.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_3.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_4.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_5.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_6.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_7.model"),
    --PrecacheAsset("models/marine/arc/arc.model"),
    
    PrecacheAsset("models/marine/hexagon/hexagon4_8.model"),
    PrecacheAsset("models/marine/hexagon/hexagon4_9.model"),
}
Shield.kAttachPoint = "Exosuit_UpprTorso"


Shield.kMass = 15
Shield.kRadius = 0.25


local networkVars =
{
    shield = "integer (0 to 9)",
   -- ownerId = "entityid",
}

AddMixinNetworkVars(BaseModelMixin, networkVars)
AddMixinNetworkVars(ModelMixin, networkVars)
--AddMixinNetworkVars(ClientModelMixin, networkVars)
AddMixinNetworkVars(LiveMixin, networkVars)
AddMixinNetworkVars(TeamMixin, networkVars)
AddMixinNetworkVars(GameEffectsMixin, networkVars)

function Shield:OnCreate()

    ScriptActor.OnCreate(self)

    InitMixin(self, BaseModelMixin)
    InitMixin(self, ModelMixin)
    --InitMixin(self, ClientModelMixin)
    
    InitMixin(self, LiveMixin)
    InitMixin(self, TeamMixin)
    InitMixin(self, DamageMixin)
    InitMixin(self, EntityChangeMixin)
    InitMixin(self, GameEffectsMixin)
    if Server then
        self:SetUpdates(true)
    elseif Client then
    end
    self.shield = 1
    self.fullyUpdated = true
    --self:SetUpdateRate(kRealTimeUpdateRate)
    
    --self:SetUpdates(true, kRealTimeUpdateRate)
    --self:SetLagCompensated(true)
    self:SetPhysicsType(PhysicsType.Dynamic)
    --self:SetPhysicsGroup(PhysicsGroup.ShieldGroup)
end

--function Shield:OnProcessMove(input)
--   -- self:UpdateBabbler(input.time)
--   -- Print("Shield:OnProcessMove")
--    if Server then
--
--        local parent = self:GetParent()
--        if parent then
--            self:SetOrigin(parent:GetOrigin())
--        end
--
--    end
--
--end

function Shield:OnAdjustModelCoords(modelCoords)
    --gets called a ton each second

    --- x = forward
    --- y = up
    --- z = right
    --modelCoords.origin = modelCoords.origin + Vector(8,8,0)
    --modelCoords.origin = modelCoords.origin + Vector(8,8,0)
    -- rotate angle by -90 degrees around z axis
    
    --
    --if Server then
    --    Print("Shield:OnAdjustModelCoords")
    --    local parent = self:GetParent()
    --    if parent then
    --        modelCoords.origin = parent:GetOrigin()
    --    end
    --
    --end
    --modelCoords = modelCoords * Coords.GetLookIn( Vector(0,0,0), Vector(0,0,1) )
   -- modelCoords.angle = Angles(modelCoords.angle.pitch, modelCoords.angle.yaw, modelCoords.angle.roll)
    --modelCoords.yAxis = modelCoords.yAxis * 0.5
    --modelCoords.zAxis = modelCoords.zAxis * 0.5
    
    return modelCoords
end

function Shield:OnInitialized()
    if Server then
        
        --self:SetPhysicsType(PhysicsType.Kinematic)
        
        --self:SetPhysicsGroup(PhysicsGroup.CommanderUnitGroup)
        
        self:SetModel(Shield.kModelNames[self.shield])
    
    end
    
end
--
--function Shield:OnDestroy()
--
--    ScriptActor.OnDestroy(self)
--
--    if Server then
--       -- self:Detach(true)
--    end
--
--
--    if Client then
--
--
--    end
--
--end

function Shield:GetCanBeUsed(_, useSuccessTable)
    useSuccessTable.useSuccess = false    
end

--function Shield:UpdateShield(deltaTime)
--
--    if not self:GetIsAlive() then
--       return
--    end
--end
--
--function Shield:OnUpdate(deltaTime)
--    PROFILE("Shield:OnUpdate")
--
--    ScriptActor.OnUpdate(self, deltaTime)
--
--    self:UpdateShield(deltaTime)
--
--end
--
--function Shield:OnProcessMove(input)
--    self:UpdateShield(input.time)
--
--    if Server then
--
--        --local parent = self:GetParent()
--        --if parent then
--        --    self:SetOrigin(parent:GetOrigin())
--        --end
--
--    end
--
--end


if Server then

    --local kEyeOffset = Vector(0, 0.2, 0)
    --function Shield:GetEyePos()
    --    return self:GetOrigin() + kEyeOffset
    --end
    --
    --function Shield:OnEntityChange(oldId, newId)
    --
    --    if oldId == self.targetId then
    --        local target = newId and Shared.GetEntity(newId)
    --
    --        if target and HasMixin(target, "Live") and target:GetIsAlive() then
    --
    --                self.targetId = newId
    --        else
    --
    --            self.targetId = Entity.invalidId
    --        end
    --    end
    --
    --end

    --local kDetachOffset = Vector(0, 0.3, 0)
    --
    --function Shield:OnKill()
    --
    --    --self:TriggerEffects("death", {effecthostcoords = Coords.GetTranslation(self:GetOrigin()) })
    --
    --end
        
    --function Shield:ProcessHit(entityHit, surface)
    --
    --    if entityHit then
    --
    --        if HasMixin(entityHit, "Live") and HasMixin(entityHit, "Team") and entityHit:GetTeamNumber() ~= self:GetTeamNumber() then
    --
    --            if self.timeLastAttack + kAttackRate < Shared.GetTime() then
    --
    --                self.timeLastAttack = Shared.GetTime()
    --
    --                local targetOrigin
    --                if entityHit.GetEngagementPoint then
    --                    targetOrigin = entityHit:GetEngagementPoint()
    --                else
    --                    targetOrigin = entityHit:GetOrigin()
    --                end
    --
    --                --local attackDirection = self:GetOrigin() - targetOrigin
    --                --attackDirection:Normalize()
    --
    --                self:DoDamage( kShieldDamage, entityHit, self:GetOrigin(), nil, surface )
    --                self:TriggerUncloak()
    --
    --                if entityHit:isa("Player") then
    --                    self:Jump((entityHit:GetOrigin() - self:GetOrigin()):GetUnit() * 2)
    --                end
    --
    --            end
    --
    --        end
    --
    --    end
    --
    --end
    
    --function Shield:GetShowHitIndicator()
    --    return true
    --end

elseif Client then

    --function Shield:OnUpdateRender()
    --    PROFILE("Shield:OnUpdateRender")
    --
    --end
    --
    --function Shield:OnAdjustModelCoords(modelCoords)
    --
    --    if not self:GetIsClinged() and self.moveDirection then
    --        modelCoords = Coords.GetLookIn(modelCoords.origin, self.moveDirection)
    --        modelCoords.origin.y = modelCoords.origin.y - Shield.kRadius
    --    end
    --
    --    return modelCoords
    --
    --end
    
end
function Shield:OnUpdate(deltaTime)
    -- Call the parent's OnUpdate (if it exists)
    ScriptActor.OnUpdate(self, deltaTime)
    
    -- Add your server-side physics update code here
end

Shared.LinkClassToMap("Shield", Shield.kMapName, networkVars, false)
