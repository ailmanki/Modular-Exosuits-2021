
if Client then
    function ExoVariantMixin:GetWeaponLoadoutClass()

        if self:isa("Exosuit") or self:isa("ReadyRoomExo") then
            local modelName = self:GetModelName()   --hacks
            if StringEndsWith( modelName, "_mm.model" ) or StringEndsWith( modelName, "_cm.model" ) then
                return "Minigun"
            elseif StringEndsWith( modelName, "_rr.model" ) or StringEndsWith( modelName, "_cr.model" )  then
                return "Railgun"
            end
        else
            local wep = self:GetActiveWeapon()
            if wep then
            --This assumes no mixed weapons are allowed (only sets)
                return wep:GetLeftSlotWeapon():GetClassName()
            end
            return false
        end
    end
end