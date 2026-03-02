--!strict
-- @Big_Honor | sirlael

local ServerScriptService = game:GetService("ServerScriptService")
local ServerCombatSystem = ServerScriptService:WaitForChild("ServerCombatSystem")
local Types = ServerCombatSystem:WaitForChild("Types")
local StateMachineTypes = require(Types:WaitForChild("StateMachineTypes"))

local TransitionRules = {}

export type DomainName = StateMachineTypes.DomainName
export type StateName = StateMachineTypes.StateName

-- ======================================================
-- Public API
-- ======================================================
function TransitionRules.CanTransition(
	domain: DomainName,
	fromState: StateName,
	toState: StateName
): boolean
	if domain == "Locomotion" then
		return TransitionRules._CanLocomotionTransition(fromState, toState)
	elseif domain == "Combat" then
		return TransitionRules._CanCombatTransition(fromState, toState)
	elseif domain == "Control" then
		return TransitionRules._CanControlTransition(fromState, toState)
	elseif domain == "Life" then
		return TransitionRules._CanLifeTransition(fromState, toState)
	end

	return false
end

-- ======================================================
-- Internal functions
-- ======================================================

-- LOCOMOTION
function TransitionRules._CanLocomotionTransition(from: StateName, to: StateName): boolean
	if from == "Dashing" then
		return to == "Idle" or to == "Moving"
	end

	if from == "Idle" then
		return to == "Moving" or to == "Airborne" or to == "Dashing"
	end

	if from == "Moving" then
		return to == "Idle" or to == "Airborne" or to == "Dashing"
	end

	if from == "Airborne" then
		return to == "Idle" or to == "Moving"
	end

	return false
end

-- COMBAT
function TransitionRules._CanCombatTransition(from: StateName, to: StateName): boolean
	if from == to then
		return true
	end
	
	if from == "Ragdolled" then
		return to == "Neutral"
	end

	if from == "Neutral" then
		return to == "Attacking" or to == "Ragdolled" or to == "UsingUniqueAbility"
	end

	if from == "Attacking" then
		return to == "Neutral" or to == "Ragdolled"
	end
	
	if from == "UsingUniqueAbility" then
		return to == "Neutral"
	end

	return false
end

-- CONTROL
function TransitionRules._CanControlTransition(from: StateName, to: StateName): boolean
	if from == "InputLocked" then
		return to == "Normal"
	end

	if from == "Normal" then
		return to == "Stunned" or to == "InputLocked"
	end

	if from == "Stunned" then
		return to == "Normal"
	end

	return false
end

-- LIFE
function TransitionRules._CanLifeTransition(from: StateName, to: StateName): boolean
	if from == "Dead" then
		return false
	end

	if from == "Alive" then
		return to == "Dead"
	end

	return false
end

return TransitionRules
