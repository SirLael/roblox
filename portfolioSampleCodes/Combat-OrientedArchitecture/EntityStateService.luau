--!strict
-- @Big_Honor | sirlael

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerCombatSystem = ServerScriptService:WaitForChild("ServerCombatSystem")
local SharedCombatSystem = ReplicatedStorage:WaitForChild("SharedCombatSystem")
local ExternalRemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local BindableEvents = ReplicatedStorage:WaitForChild("BindableEvents")
local CombatRemoteEvents = SharedCombatSystem:WaitForChild("RemoteEvents")

local EffectsReplication = CombatRemoteEvents:WaitForChild("EffectsReplication")
local KillEvent = ExternalRemoteEvents:WaitForChild("KillEvent")
local UpdateHealthBar = ExternalRemoteEvents:WaitForChild("UpdateHealthBar")
local HealthBar = CombatRemoteEvents:WaitForChild("HealthBar")
local RegisterKill = BindableEvents:WaitForChild("RegisterKill")

local Utils = ServerCombatSystem:WaitForChild("Utils")
local Handlers = ServerCombatSystem:WaitForChild("Handlers")
local StateMachine = Handlers:WaitForChild('StateMachine')
local ReplicatedUtils = SharedCombatSystem:WaitForChild("Utils")

local Signals = require(Utils:WaitForChild("Signals"))
local EventBus = require(Utils:WaitForChild("EventBus"))
local EntityState = require(StateMachine:WaitForChild("EntityState"))
local AssetsManager = require(ReplicatedUtils:WaitForChild("AssetsManager"))

local KILL_HEALTH_ADDITION = 50
local HEALTH_PARTICLE_RADIUS = 50 

local EntityStateService = {}
EntityStateService.__index = EntityStateService

local _states: {[Humanoid]: EntityState.EntityState} = {}
local _billboardGuis: {[Humanoid]: BillboardGui} = {}

local TweenService = game:GetService("TweenService")

local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local COLOR_FULL = Color3.fromRGB(0, 255, 0)
local COLOR_HALF = Color3.fromRGB(255, 255, 0)
local COLOR_LOW = Color3.fromRGB(255, 0, 0)

local activeTweens = {} -- [GuiObject] = {sizeTween, colorTween}


local function fireClientsInRadius(remote, originCF: CFrame, killerCharacter, action)
	local originPos = originCF.Position

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local dist = (char.HumanoidRootPart.Position - originPos).Magnitude
			if dist <= HEALTH_PARTICLE_RADIUS then
				remote:FireClient(player, killerCharacter, action)
			end
		end
	end
end



local function getHealthColor(ratio: number): Color3
	if ratio > 0.5 then
		return COLOR_FULL
	else
		local t = ratio / 0.5 -- 0 at 0%, 1 at 50%
		return COLOR_LOW:Lerp(COLOR_HALF, t)
	end
end

local function tweenHealthBar(healthBar: GuiObject, newSize: UDim2, ratio: number)
	local existing = activeTweens[healthBar]
	if existing then
		if existing.size then existing.size:Cancel() end
		if existing.color then existing.color:Cancel() end
	end

	local sizeTween = TweenService:Create(healthBar, TWEEN_INFO, { Size = newSize })
	local colorTween = TweenService:Create(healthBar, TWEEN_INFO, { BackgroundColor3 = getHealthColor(ratio) })

	activeTweens[healthBar] = { size = sizeTween, color = colorTween }

	sizeTween:Play()
	colorTween:Play()

	sizeTween.Completed:Once(function()
		if activeTweens[healthBar] and activeTweens[healthBar].size == sizeTween then
			activeTweens[healthBar] = nil
		end
	end)
end

function EntityStateService.UpdateBillboardGui(humanoid: Humanoid): nil
	if not humanoid then return nil end
	local billboardGui = _billboardGuis[humanoid] :: any
	if not billboardGui then return nil end
	local ratio = math.clamp(if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0, 0, 1)
	local newSize = UDim2.new(ratio, 0, 1, 0)

	local healthBar = billboardGui.Bar.HealthBar.Health
	tweenHealthBar(healthBar, newSize, ratio)
	billboardGui.Bar.HealthBar.Visible = ratio < 0.999

	local character: Model? = humanoid.Parent
	if not character then return nil end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return nil end

	UpdateHealthBar:FireClient(player, newSize, ratio)
	return nil
end

function EntityStateService.GetBillboardGui(humanoid: Humanoid): BillboardGui?
	return _billboardGuis[humanoid]
end

function EntityStateService.GetOrCreate(humanoid: Humanoid): EntityState.EntityState
	if _states[humanoid] then
		return _states[humanoid]
	end

	local entityState = EntityState.new()
	_states[humanoid] = entityState
	
	if humanoid.Parent and not _billboardGuis[humanoid] then
		local overheadTemplate = AssetsManager:GetBillboardGuiByName("OverheadUI")
		local newOverheadUI: BillboardGui = overheadTemplate:Clone()
		
		local character: Model? = humanoid.Parent
		
		local player:Player 
		if character then
			player = Players:GetPlayerFromCharacter(character)		
			newOverheadUI.PlayerToHideFrom = player
		end		
			
		newOverheadUI.Parent = humanoid.Parent:WaitForChild("HumanoidRootPart")
		newOverheadUI.Bar.username.Text = player and (player.DisplayName or player.Name) or humanoid.Parent.Name
		
		_billboardGuis[humanoid] = newOverheadUI
	end
	
	EventBus:Fire(Signals.ManageFreefall, humanoid)
	
	humanoid.AncestryChanged:Connect(function(_, parent)
		if not parent then
			EntityStateService.Remove(humanoid)
		end
	end)
	
	humanoid.Died:Once(function()
		
		-- Get killer
		local killerName = humanoid:GetAttribute("LastAttacker") :: string
		local killerPlayer = Players:FindFirstChild(killerName or "") :: Player

		-- Get killed player (victim player) player instance
		local victimPlayer = Players:GetPlayerFromCharacter(humanoid.Parent :: Model)

		if killerPlayer and victimPlayer then
			
			-- Fire killed event to all players
			KillEvent:FireAllClients(killerPlayer, victimPlayer)
			
			-- Register kill to update data
			RegisterKill:Fire(killerPlayer)
			
			-- Add 50hp to killer
			local killerCharacter = killerPlayer.Character
			if not killerCharacter then return end
			
			local killHRP:Part = killerCharacter:FindFirstChild("HumanoidRootPart")
			if not killHRP then return end
			
			local killerHumanoid = killerCharacter:FindFirstChildOfClass("Humanoid")
			if not killerHumanoid then return end
			
			killerHumanoid.Health = math.min(
				killerHumanoid.Health + KILL_HEALTH_ADDITION,
				killerHumanoid.MaxHealth
			)
			
			-- Make healing particles visible to only players nearby
			fireClientsInRadius(EffectsReplication, killHRP.CFrame, killerCharacter, "Healing")

			-- Update killer's health bar
			--HealthBar:FireClient(killerPlayer, "Heal", KILL_HEALTH_ADDITION)
			
			-- Update killer's overheadUI
			EntityStateService.UpdateBillboardGui(killerHumanoid)
		end
	end)

	return entityState
end

function EntityStateService.Remove(humanoid: Humanoid)
	_states[humanoid] = nil
	_billboardGuis[humanoid] = nil
	EventBus:Fire(Signals.RemoveEntity, humanoid)
end

return EntityStateService
