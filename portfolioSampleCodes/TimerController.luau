--!nocheck
-- @Big_Honor | sirlael 

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedCombatSystem = ReplicatedStorage:WaitForChild("SharedCombatSystem")
local Utils = SharedCombatSystem:WaitForChild("Utils")
local FastSignal = require(Utils:WaitForChild("FastSignal"))
local Promise = require(Utils:WaitForChild("Promise"))
local Maid = require(Utils:WaitForChild("Maid"))

type FastSignal<T...> = {
	Connect: (self: FastSignal<T...>, callback: (T...) -> ()) -> any,
	Fire: (self: FastSignal<T...>, T...) -> (),
	Destroy: (self: FastSignal<T...>) -> (),
	Wait: (self: FastSignal<T...>) -> T...
}

type Promise<T...> = {
	andThen: (self: Promise<T...>, ...any) -> Promise<T...>,
	catch: (self: Promise<T...>, ...any) -> Promise<T...>,
	cancel: (self: Promise<T...>) -> (),
}

export type TimerMode = "Countdown" | "Stopwatch"

export type Timer = {
	TimeLeft: number,
	TimeElapsed: number,
	Duration: number,
	IsRunning: boolean,
	Mode: TimerMode,

	Tick: FastSignal<number, number, number>,
	Completed: FastSignal<>,

	Start: (self: Timer) -> (),
	Pause: (self: Timer) -> (),
	Stop: (self: Timer) -> (),
	Restart: (self: Timer) -> (),
	SetTime: (self: Timer, seconds: number) -> (),
	WaitPromise: (self: Timer) -> Promise<()>,
	Destroy: (self: Timer) -> (),
}

local activeTimers: { [Timer]: boolean } = {}

RunService.Heartbeat:Connect(function(dt: number)
	for timer in pairs(activeTimers) do
		(timer :: any):_update(dt)
	end
end)

local TimerController = {}
TimerController.__index = TimerController

function TimerController.new(duration: number?, mode: TimerMode?): Timer
	local self = setmetatable({}, TimerController)

	self.Duration = duration or 0
	self.Mode = mode or "Countdown"

	self.TimeLeft = self.Duration
	self.TimeElapsed = 0
	self.IsRunning = false
	self._maid = Maid.new()

	self._currentPromiseResolver = nil :: ((...any) -> ())?
	self._activePromise = nil :: any?

	self.Tick = self._maid:GiveTask(FastSignal.new())
	self.Completed = self._maid:GiveTask(FastSignal.new())

	return (self :: any) :: Timer
end

function TimerController:_update(dt: number)
	if not self.IsRunning then return end

	if self.Mode == "Countdown" then
		self.TimeLeft -= dt
		if self.TimeLeft <= 0 then
			self.TimeLeft = 0
			self:Stop()
			self.Completed:Fire()

			if self._currentPromiseResolver then
				local resolver = self._currentPromiseResolver
				self._currentPromiseResolver = nil
				self._activePromise = nil
				resolver()
			end
		end

	else 
		self.TimeElapsed += dt
	end

	self.Tick:Fire(dt, self.TimeLeft, self.TimeElapsed)
end

-- Public API
function TimerController:Start()
	if self.IsRunning then return end

	if self.Mode == "Countdown" and self.TimeLeft <= 0 then
		self.TimeLeft = self.Duration
	end

	self.IsRunning = true
	activeTimers[(self :: any) :: Timer] = true
end

function TimerController:Pause()
	self.IsRunning = false
	activeTimers[(self :: any) :: Timer] = nil
end

function TimerController:Stop()
	self:Pause()

	if self.Mode == "Countdown" then
		self.TimeLeft = 0 
	else
		self.TimeElapsed = 0
	end
end

function TimerController:Restart()
	self:Stop()
	self.TimeLeft = self.Duration
	self.TimeElapsed = 0
	self:Start()
end

function TimerController:SetTime(seconds: number)
	self.Duration = seconds
	if self.Mode == "Countdown" then
		self.TimeLeft = seconds
	end
end

function TimerController:WaitPromise()
	if self._activePromise and self._activePromise:IsPending() then
		return self._activePromise
	end

	if self.Mode ~= "Countdown" then
		warn("[TimerController] WaitPromise needs to be used with Countdown.")
	end

	self._activePromise = Promise.new(function(resolve, reject, onCancel)
		self._currentPromiseResolver = resolve

		if not self.IsRunning and self.TimeLeft > 0 then
			self:Start()
		end

		if onCancel then
			onCancel(function()
				self._currentPromiseResolver = nil
				self:Pause()
			end)
		end
	end)

	return self._activePromise
end

function TimerController:Destroy()
	self:Pause()
	activeTimers[(self :: any) :: Timer] = nil

	self._maid:Destroy()

	if self._currentPromiseResolver then
		self._currentPromiseResolver = nil
	end

	setmetatable(self :: any, nil)
end


return TimerController