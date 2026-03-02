--!strict
-- @Big_Honor | sirlael

local ServerScriptService = game:GetService("ServerScriptService")
local ServerCombatSystem = ServerScriptService:WaitForChild("ServerCombatSystem")

local Types = ServerCombatSystem:WaitForChild("Types")
local Utils = ServerCombatSystem:WaitForChild("Utils")
local StateMachineFolder = ServerCombatSystem:WaitForChild("Handlers"):WaitForChild("StateMachine")

local StateMachine = require(StateMachineFolder:WaitForChild("StateMachine"))
local TransitionRules = require(Utils:WaitForChild("TransitionRules"))
local StateMachineTypes = require(Types:WaitForChild("StateMachineTypes"))

local EntityState = {}
EntityState.__index = EntityState

export type DomainName = StateMachineTypes.DomainName
export type StateName = StateMachineTypes.StateName
export type StateDomain = StateMachineTypes.StateDomain
export type EntityState = StateMachineTypes.EntityState

-- ======================================================
-- Public API
-- ======================================================
function EntityState.new(): EntityState
	local self = setmetatable({}, EntityState)

	self._stateMachine = StateMachine.new()

	return self :: EntityState
end

function EntityState:GetState(domain: DomainName): StateName?
	return self._stateMachine:GetState(domain)
end

function EntityState:Is(domain: DomainName, state: StateName): boolean
	return self._stateMachine:Is(domain, state)
end

function EntityState:GetAllStates(): {[DomainName]: StateName}
	local snapshot = {}

	for domain, state in pairs(self._stateMachine._currentStates) do
		snapshot[domain :: DomainName] = state :: string
	end

	return snapshot
end

function EntityState:TrySetState(domain: DomainName, newState: StateName): boolean
	local current = self._stateMachine:GetState(domain)
	if not current then
		return false
	end

	if not TransitionRules.CanTransition(domain, current, newState) then
		return false
	end

	-- Guards (stamina, cooldown, timers, etc)

	return self._stateMachine:SetState(domain, newState)
end

function EntityState:StateChanged(domain: DomainName): RBXScriptSignal
	return self._stateMachine:StateChanged(domain)
end

return EntityState
