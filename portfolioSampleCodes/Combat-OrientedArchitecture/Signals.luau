-- @Big_Honor | sirlael

local Signals = {}

-- Weapons
Signals.CreateWeaponHolder = "CreateWeaponHolder"
Signals.WeaponEquipped = "WeaponEquipped"
Signals.WeaponUnequipped = "WeaponUnequipped"

-- PvP 
Signals.AttackRequest = "AttackRequest"   
Signals.Attacking = "Attacking"
Signals.AttackEnded = "AttackEnded"
Signals.AddSwing = "AddSwing"
Signals.TargetDetected = "TargetDetected"   
Signals.HitTarget = "HitTarget"
Signals.StartHitBoxDetection = "StartHitBoxDetection"
Signals.StopHitBoxDetection = "StopHitBoxDetection"
Signals.Healing = "Healing"

-- Unique Ability
Signals.UniqueAbilityRequest = "UniqueAbilityRequest"
Signals.UsingUniqueAbility = "UsingUniqueAbility"
Signals.StopUniqueAbility = "StopUniqueAbility"

-- Ragdoll
Signals.StartRagdoll = "StartRagdoll"
Signals.StopRagdoll = "StopRagdoll"
Signals.ApplyKnockback = "ApplyKnockback"

-- Locomotion
Signals.Dashing = "Dashing"

-- Others
Signals.RemoveEntity = "RemoveEntity"
Signals.ManageFreefall = "ManageFreefall"

return setmetatable(Signals, {
	__newindex = function()
		error("Signals table is read-only")
	end,
})
