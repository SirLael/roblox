--!nocheck
-- @Big_Honor | sirlael

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedCombatSystem = ReplicatedStorage:WaitForChild("SharedCombatSystem")
local Utils = SharedCombatSystem:WaitForChild("Utils")
local FastSignal = require(Utils:WaitForChild("FastSignal"))
local Maid = require(Utils:WaitForChild("Maid"))
local Promise = require(Utils:WaitForChild("Promise"))

local EventBus = {}
EventBus.__index = EventBus

local singletonInstance: any = nil

function EventBus:GetInstance()
	if singletonInstance then
		return singletonInstance
	end

	local self = setmetatable({}, EventBus)
	self._signals = {} :: {[string]: FastSignal.FastSignal<any>}
	self._maid = Maid.new()
	singletonInstance = self
	return self
end

function EventBus:Connect(eventName: string, callback: (...any) -> ()): Maid
	if not self._signals[eventName] then
		self._signals[eventName] = FastSignal.new()
		self._maid:GiveTask(self._signals[eventName])
	end

	local maid = Maid.new()
	maid:GiveTask(self._signals[eventName]:Connect(callback))
	return maid
end

function EventBus:Fire(eventName: string, ...: any)
	local signal = self._signals[eventName]
	if signal then
		signal:Fire(...)
	end
end

function EventBus:Wait(eventName: string): Promise.Promise<any>
	return Promise.new(function(resolve)
		local maid: Maid
		maid = self:Connect(eventName, function(...)
			resolve(...)
			maid:DoCleaning()
		end)
	end)
end

function EventBus:Destroy()
	self._maid:DoCleaning()
	self._signals = {}
	singletonInstance = nil
end

return EventBus:GetInstance()
