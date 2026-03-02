--!strict
-- @Big_Honor | sirlael

local ServerScriptService = game:GetService("ServerScriptService")
local ServerCombatSystem = ServerScriptService:WaitForChild("ServerCombatSystem")

local Configs = ServerCombatSystem:WaitForChild("Configs")
local Types = ServerCombatSystem:WaitForChild("Types")

local StatesConfig = require(Configs:WaitForChild("StatesConfig"))
local StateMachineTypes = require(Types:WaitForChild("StateMachineTypes"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FastSignal = require(ReplicatedStorage.SharedCombatSystem.Utils.FastSignal)

local StateMachine = {}
StateMachine.__index = StateMachine

export type DomainName = StateMachineTypes.DomainName
export type StateName = StateMachineTypes.StateName

export type StateMachine = StateMachineTypes.StateMachine

function StateMachine.new(): StateMachine
	local self = setmetatable({}, StateMachine)

	self._domains = StatesConfig
	self._currentStates = {}
	self._connections = {}

	for domain, domainConfig in pairs(StatesConfig :: StateMachineTypes.StatesConfig) do
		local initial = domainConfig.Initial
		local states = domainConfig.States

		if states[initial] ~= true then
			warn(
				`[StateMachine] Invalid initial state on Domain "{domain}": {initial}`
			)
		else
			self._currentStates[domain] = initial
			self._connections[domain] = FastSignal.new()
		end
	end

	return self :: StateMachineTypes.StateMachine
end

function StateMachine:StateChanged(domain: DomainName): RBXScriptSignal
	return self._connections[domain]
end

function StateMachine:GetState(domain: DomainName): StateName?
	return self._currentStates[domain]
end

function StateMachine:Is(domain: DomainName, state: StateName): boolean
	return self._currentStates[domain] == state
end

function StateMachine:SetState(domain: DomainName, newState: StateName): boolean
	local domainConfig = self._domains[domain]
	if domainConfig == nil then
		warn(`[StateMachine] Invalid domain: {domain}`)
		return false
	end

	local states = domainConfig.States
	if states[newState] ~= true then
		return false
	end

	local current = self._currentStates[domain]
	if current == newState then
		if domain ~= "Combat" then
			return false
		end
	end

	self._currentStates[domain] = newState
	self._connections[domain]:Fire(newState)
	
	return true
end

return StateMachine
