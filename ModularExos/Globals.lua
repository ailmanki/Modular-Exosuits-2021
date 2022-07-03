local oldGetPrecachedCosmeticMaterial = GetPrecachedCosmeticMaterial
function GetPrecachedCosmeticMaterial( className, variantId, viewOnly )
    if className == "Claw"  then
		className = "Minigun"
	elseif (className == "ExoWelder") or (className ==  "ExoFlamer") then
		className = "Railgun"
	end

	return oldGetPrecachedCosmeticMaterial( className, variantId, viewOnly )
end