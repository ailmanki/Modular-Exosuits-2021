-- ======= Copyright (c) 2003-2013, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua\Shield.lua
--
--    Created by:   Andreas Urwalek (andi@unknownworlds.com)
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================

Script.Load("lua/ScriptActor.lua")
Script.Load("lua/Mixins/ClientModelMixin.lua")
Script.Load("lua/LiveMixin.lua")
Script.Load("lua/TeamMixin.lua")
Script.Load("lua/MobileTargetMixin.lua")
Script.Load("lua/DamageMixin.lua")
Script.Load("lua/EntityChangeMixin.lua")
Script.Load("lua/OwnerMixin.lua")
Script.Load("lua/TargetCacheMixin.lua")
Script.Load("lua/PathingMixin.lua")
Script.Load("lua/PhysicsGroups.lua")
Script.Load("lua/GameEffectsMixin.lua")

kShieldMoveTypeStr = { 'None', 'Move' }
kShieldMoveType = enum(kShieldMoveTypeStr)

class 'Shield' (ScriptActor)

Shield.kMapName = "shield"

Shield.kModelName = PrecacheAsset("models/alien/shield/shield.model")
Shield.kModelNameShadow = PrecacheAsset("models/alien/shield/shield_shadow.model")


Shield.kMass = 15
Shield.kRadius = 0.25
Shield.kProcessHitRadius = 0.70


Shield.kRestitution = 0.30
Shield.kFov = 360

local kTargetSearchRange = 12
local kTargetMaxFollowRange = 30
local kAttackRate = 0.40


local networkVars =
{
    targetId = "entityid",
    ownerId = "entityid",
    -- updates every 10 and [] means no compression used (not updates are send in this case)
    m_angles = "interpolated angles (by 10 [], by 10 [], by 10 [])",
    m_origin = "compensated interpolated position (by 0.05 [2 3 5], by 0.05 [2 3 5], by 0.05 [2 3 5])",
}

AddMixinNetworkVars(BaseModelMixin, networkVars)
AddMixinNetworkVars(ClientModelMixin, networkVars)
AddMixinNetworkVars(LiveMixin, networkVars)
AddMixinNetworkVars(TeamMixin, networkVars)
AddMixinNetworkVars(GameEffectsMixin, networkVars)

-- shared:

function Shield:CreateHitBox()

    if self:GetIsAlive() and not self:GetIsDestroyed() and not self.clinged and not self.hitBox then
    
        -- Log("Creating hitbox for %s", self)
        self.hitBox = Shared.CreatePhysicsSphereBody(false, Shield.kRadius * 2, Shield.kMass, self:GetCoords() )
        self.hitBox:SetGroup(PhysicsGroup.ShieldGroup)
        self.hitBox:SetCoords(self:GetCoords())
        self.hitBox:SetEntity(self)
        self.hitBox:SetPhysicsType(CollisionObject.Kinematic)
        self.hitBox:SetTriggeringEnabled(true)
        
    end

end

function Shield:OnCreate()

    ScriptActor.OnCreate(self)

    InitMixin(self, BaseModelMixin)
    InitMixin(self, ClientModelMixin)
    
    InitMixin(self, LiveMixin)
    InitMixin(self, TeamMixin)
    InitMixin(self, DamageMixin)
    InitMixin(self, EntityChangeMixin)
    InitMixin(self, GameEffectsMixin)

    if Server then
    
        self.targetId = Entity.invalidId
        self.timeLastJump = 0
        self.timeLastAttack = 0
        self.kNextUpdateAttack = 0
        self.jumpAttempts = 0
        self.kStopImpulseDone = 0
        self.silenced = false
        
        InitMixin(self, PathingMixin)
        
        self.targetId = Entity.invalidId
        
        self.moveType = kShieldMoveType.None
        
        self.creationTime = Shared.GetTime()

    elseif Client then
    
        self.oldModelIndex = 0
        
    end

    self:SetUpdateRate(kRealTimeUpdateRate)
    
end

function Shield:OnInitialized()

    self:SetModel(Shield.kModelName, kAnimationGraph)
    

    if Server then

        InitMixin(self, MobileTargetMixin)
        InitMixin(self, TargetCacheMixin)
        
    
    end
    
end

function Shield:DestroyHitbox()
    if self.hitBox then
yCollisionObject(self.hitBox)
        self.hitBox = nil

    end
end

function Shield:OnDestroy()

    ScriptActor.OnDestroy(self)

    if Server then
        self:Detach(true)
    end

    if self.physicsBody then
    
        Shared.DestroyCollisionObject(self.physicsBody)
        self.physicsBody = nil
        
    end

    self:DestroyHitbox()
    
    if Client then
        
        self.clientVelocity = nil
        
        local model = self:GetRenderModel()
    
    end

end

function Shield:GetCanBeUsed(_, useSuccessTable)
    useSuccessTable.useSuccess = false    
end


function Shield:UpdateRelevancy()

    local owner = self:GetOwner()
    local sighted = owner ~= nil and (owner:GetOrigin() - self:GetOrigin()):GetLengthSquared() < 16 and (HasMixin(owner, "LOS") and owner:GetIsSighted())

    local mask = bit.bor(kRelevantToTeam1Unit, kRelevantToTeam2Unit, kRelevantToReadyRoom)

    local teamNumber = self:GetTeamNumber()
    if teamNumber == 1 then
        mask = bit.bor(mask, kRelevantToTeam1Commander)
        if sighted then
            mask = bit.bor(mask, kRelevantToTeam2Commander)
        end
    end

    if teamNumber == 2 then
        mask = bit.bor(mask, kRelevantToTeam2Commander)
        if sighted then
            mask = bit.bor(mask, kRelevantToTeam1Commander)
        end
    end
    
    self:SetExcludeRelevancyMask( mask )

end

function Shield:UpdateShield(deltaTime)


    if not self:GetIsAlive() then
       return
    end

    if Server then

        self:UpdateMove(deltaTime)
        self:UpdateRelevancy()

    elseif Client then

        self:UpdateMoveDirection(deltaTime)

        local model = self:GetRenderModel()

    end

    self.lastOrigin = self:GetOrigin()
    self.lastUpdate = Shared.GetTime()

end

function Shield:UpdatePhysics()
    self:CreateHitBox()
    if self.hitBox then
        self.hitBox:SetCoords(self:GetCoords())
    end
end

function Shield:OnUpdatePhysics()
    self:UpdatePhysics()
end

function Shield:OnFinishPhysics()
    self:UpdatePhysics()
end


function Shield:OnUpdate(deltaTime)
    PROFILE("Shield:OnUpdate")

    ScriptActor.OnUpdate(self, deltaTime)

    self:UpdateShield(deltaTime)

end

function Shield:OnProcessMove(input)
    self:UpdateShield(input.time)
    
    if Server then
        
        local parent = self:GetParent()
        if parent then
            self:SetOrigin(parent:GetOrigin())
        end
        
    end
    
end

function Shield:GetPhysicsModelAllowedOverride()
    return false
end

if Server then

    local kEyeOffset = Vector(0, 0.2, 0)
    function Shield:GetEyePos()
        return self:GetOrigin() + kEyeOffset
    end

    function Shield:OnEntityChange(oldId, newId)

        if oldId == self.targetId then
            local target = newId and Shared.GetEntity(newId)

            if target and HasMixin(target, "Live") and target:GetIsAlive() then
                
                    self.targetId = newId
            else

                self.targetId = Entity.invalidId
            end
        end

    end

    local kDetachOffset = Vector(0, 0.3, 0)

    function Shield:Attach(deltaTime)
        local target = self:GetTarget()
        if not target then return false end

        if not target:GetIsAlive() then return false end

        if HasMixin(target, "ShieldCling") or target:isa("Embryo") or target:isa("AlienCommander") then

            local attachPointOrigin
            if HasMixin(target, "ShieldCling") then
                attachPointOrigin = target:GetFreeShieldAttachPointOrigin()
            else
                attachPointOrigin = self.targetPosition
            end

            if attachPointOrigin then
                local moveDir = GetNormalizedVector(attachPointOrigin - self:GetOrigin())

                local distance = (self:GetOrigin() - attachPointOrigin):GetLength()
                local travelDistance = deltaTime * 15

                if distance < travelDistance then

                    if HasMixin(target, "ShieldCling") then

                        if target:AttachShield(self) then
                            self.clinged = true

                            self:DestroyHitbox()
                            travelDistance = distance
                        else -- Just for safety
                            return false
                        end
                    else
                        if target:isa("Embryo") and not target:GetIsAlive() then
                            self.shieldOffMap = true -- Force unstuck (since we are inside the egg/ground)
                            self.shieldOffMapRecoveryOrig = self:GetOrigin() + Vector(0, 0.7, 0)
                            return false
                        end
                        if distance < 0.1 then
                            return true
                        end
                    end

                end

                -- disable physic simulation
                self:SetGroundMoveType(true)
                self:SetOrigin(self:GetOrigin() + moveDir * travelDistance)

                return true

            end

        end

        return false
    end

    function Shield:Detach(force)

        self:CreateHitBox()

        self:SetOrigin(self:GetOrigin() + kDetachOffset)
        self:UpdateJumpPhysicsBody()
        self:SetMoveType(kShieldMoveType.None)
        self:JumpRandom()

        self:AddTimedCallback(Shield.ShieldOffMap, kShieldOffMapInterval)
        self:AddTimedCallback(Shield.MoveRandom, kUpdateMoveInterval + math.random() / 5)
        self:AddTimedCallback(Shield.UpdateWag, 0.4)
    end

    function Shield:UpdateTargetPosition()

        local target = self:GetTarget()

        if target and not target:isa("AlienSpectator") then

            if self.moveType == kShieldMoveType.Cling and target.GetFreeShieldAttachPointOrigin then

                self.targetPosition = target:GetFreeShieldAttachPointOrigin()
                -- If there are no free attach points, stop trying to cling.
                if not self.targetPosition then
                    self:SetMoveType(kShieldMoveType.None)
                end

            end

        end

    end

    local function NoObstacleInWay(self, targetPosition)

        local trace = Shared.TraceRay(self:GetOrigin() + kEyeOffset, targetPosition, CollisionRep.LOS, PhysicsMask.All, EntityFilterAll())
        return trace.fraction == 1

    end
    
    function Shield:OnKill()

        self:TriggerEffects("death", {effecthostcoords = Coords.GetTranslation(self:GetOrigin()) })
        
    end
        
    function Shield:ProcessHit(entityHit, surface)

        if entityHit then

            if HasMixin(entityHit, "Live") and HasMixin(entityHit, "Team") and entityHit:GetTeamNumber() ~= self:GetTeamNumber() then
            
                if self.timeLastAttack + kAttackRate < Shared.GetTime() then
                    
                    self.timeLastAttack = Shared.GetTime()
                    
                    local targetOrigin
                    if entityHit.GetEngagementPoint then
                        targetOrigin = entityHit:GetEngagementPoint()
                    else
                        targetOrigin = entityHit:GetOrigin()
                    end
                    
                    --local attackDirection = self:GetOrigin() - targetOrigin
                    --attackDirection:Normalize()
                    
                    self:DoDamage( kShieldDamage, entityHit, self:GetOrigin(), nil, surface )
                    self:TriggerUncloak()

                    if entityHit:isa("Player") then
                        self:Jump((entityHit:GetOrigin() - self:GetOrigin()):GetUnit() * 2)
                    end

                end
                
            end
            
        end

    end 
    
    function Shield:GetShowHitIndicator()
        return true
    end

elseif Client then

    function Shield:OnUpdateRender()
        PROFILE("Shield:OnUpdateRender")
        
    end

    function Shield:OnAdjustModelCoords(modelCoords)

        if not self:GetIsClinged() and self.moveDirection then
            modelCoords = Coords.GetLookIn(modelCoords.origin, self.moveDirection)
            modelCoords.origin.y = modelCoords.origin.y - Shield.kRadius
        end
    
        return modelCoords
    
    end
    
end

Shared.LinkClassToMap("Shield", Shield.kMapName, networkVars, true)
