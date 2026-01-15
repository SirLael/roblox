--!nocheck
-- @Big_Honor | sirlael 

--========================
-- Services
--========================
-- Core Roblox services used by the combat system
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

--========================
-- Dependencies
--========================
-- Main combat folders (server-side and shared)
local ServerCombatSystem = ServerScriptService:WaitForChild("ServerCombatSystem")
local SharedCombatSystem = ReplicatedStorage:WaitForChild("SharedCombatSystem")

-- Internal utilities and structure
local Utils = ServerCombatSystem:WaitForChild("Utils")
local Types = ServerCombatSystem:WaitForChild("Types")
local ReplicatedUtils = SharedCombatSystem:WaitForChild("Utils")
local Handlers = ServerCombatSystem:WaitForChild("Handlers")
local Configs = ServerCombatSystem:WaitForChild("Configs")

-- RemoteEvents used mainly for UI feedback
local RemoteEvents = SharedCombatSystem:WaitForChild("RemoteEvents")
local HealthBar = RemoteEvents:WaitForChild("HealthBar")
local CooldownGui = RemoteEvents:WaitForChild("CooldownGui")

--========================
-- Modules
--========================
-- Hitbox system based on shapecasting
local ShapecastHitbox = require(Utils:WaitForChild("ShapecastHitbox"))

-- Signal definitions and event dispatcher
local Signals = require(Utils:WaitForChild("Signals"))
local EventBus = require(Utils:WaitForChild("EventBus"))

-- Handles tool cooldown logic
local CooldownService = require(Utils:WaitForChild("CooldownService"))

-- Entity state machine (combat, locomotion, life, etc)
local EntityStateService = require(Handlers:WaitForChild("EntityStateService"))

-- Async control helpers
local Promise = require(ReplicatedUtils:WaitForChild("Promise"))
local Maid = require(ReplicatedUtils:WaitForChild("Maid"))

-- State machine type definitions
local StateMachineTypes = require(Types:WaitForChild("StateMachineTypes"))

-- Tool configuration (damage, cooldowns, stun times, etc)
local ToolsConfig = require(Configs:WaitForChild("ToolsConfig"))

--========================
-- Constants
--========================
-- Safety delay to force attack end if something desyncs
local ATTACK_FALLBACK_DELAY = 0.225

-- Time required out of combat before regen starts
local OUT_OF_COMBAT_DELAY = 10

-- Total time to fully regenerate HP
local FULL_REGEN_TIME = 3 

-- Regen tick interval
local REGEN_TICK = 0.1 

--========================
-- State
--========================
-- Tracks the last combat timestamp per player
local _lastCombats = {}

-- Indicates if the player already entered regen state
local _regenState = {} :: {[Player]: boolean}

-- Tracks humanoids already initialized in the state service
local _entities = {} :: {[Humanoid]: boolean}

--========================
-- Internal functions
--========================

-- Removes ragdoll after a delay and safely returns entity to Neutral
local function _delayRemoveRagdoll(playerOrEntity: Player?, duration : number, entityState : StateMachineTypes.EntityState): nil
	local maid = Maid.new()

	-- Waits the stun duration before stopping ragdoll
	local attackPromise = Promise.delay(duration, function()
		local character = playerOrEntity:IsA("Player") and playerOrEntity.Character or playerOrEntity
		EventBus:Fire(Signals.StopRagdoll, character)
		entityState:TrySetState("Combat", "Neutral")
	end)

	maid:GivePromise(attackPromise)
	
	-- Non-player entities don't need ancestry cleanup
	if not playerOrEntity:IsA("Player") then return nil end 

	-- Cleanup if the player leaves the game
	local conn = playerOrEntity.AncestryChanged:Connect(function(_, parent)
		if not parent then
			maid:Destroy()
		end
	end)

	maid:GiveTask(conn)

	return nil
end

-- Forces attack termination if the normal flow fails
local function _delayFallback(player : Player?, entityState : StateMachineTypes.EntityState): nil
	local maid = Maid.new()

	-- If still attacking after the delay, manually end it
	local attackPromise = Promise.delay(ATTACK_FALLBACK_DELAY, function()
		if entityState:Is("Combat", "Attacking") then
			EventBus:Fire(Signals.AttackEnded, player)
		end
	end)

	maid:GivePromise(attackPromise)

	if not player then return nil end 

	-- Cleanup when player leaves
	local conn = player.AncestryChanged:Connect(function(_, parent)
		if not parent then
			maid:Destroy()
		end
	end)

	maid:GiveTask(conn)
	
	return nil
end

-- Applies damage, ragdoll and combat feedback to a valid target
local function _hitTarget(
	targetCharacter : Model,
	targetHumanoid : Humanoid,
	tool : Tool,
	targetState : StateMachineTypes.EntityState,
	attackerCharacter : Model
): nil
	
	-- Prevents overlapping hits by locking target in ragdoll
	targetState:TrySetState("Combat", "Ragdolled")

	-- Visual / physics feedback
	EventBus:Fire(Signals.HitTarget, targetCharacter)
	EventBus:Fire(Signals.StartRagdoll, targetCharacter, attackerCharacter)
	EventBus:Fire(Signals.ApplyKnockback, targetCharacter, attackerCharacter)
	
	-- Damage calculation based on tool config
	local damage = ToolsConfig[tool.Name].Damage
	targetHumanoid:TakeDamage(damage)
	EntityStateService.UpdateBillboardGui(targetHumanoid)
	
	-- Player-specific combat tracking and UI update
	local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
	if targetPlayer then
		_lastCombats[targetPlayer] = os.clock()
		_regenState[targetPlayer] = nil
		HealthBar:FireClient(targetPlayer, "Damage", damage)
	end
	
	-- Duration the target stays stunned
	local ragdollTime = ToolsConfig[tool.Name].StunTime
	
	-- Schedule ragdoll removal
	_delayRemoveRagdoll(targetPlayer or targetCharacter, ragdollTime, targetState)
	
	return nil
end

-- Starts the attack flow for the player
local function _startAttack(player: Player, tool : Tool, attackId : string): nil
	
	local character = player.Character :: Model
	local humanoid = character and character:WaitForChild("Humanoid") :: Humanoid
	if not character or not humanoid then return end 
	
	local entityState = EntityStateService.GetOrCreate(humanoid)
	if not entityState then return nil end

	-- Fallback ensures attack always ends
	_delayFallback(player, entityState)
	
	-- Small delay to sync animation and hitbox
	task.delay(0.26, function()
		EventBus:Fire(Signals.StartHitBoxDetection, player, tool, attackId)
	end)
	
	-- Registers a new swing for combo tracking
	EventBus:Fire(Signals.AddSwing, tool)

	-- Resets combat timer and regen state
	_lastCombats[player] = os.clock()
	_regenState[player] = nil
	
	return nil
end

--========================
-- Core
--========================

-- Called when a hitbox detects a humanoid
local function targetDetected(humanoid : Humanoid, attackOwner : Player, tool : Tool, hitboxType : string?): nil
	local targetState = EntityStateService.GetOrCreate(humanoid)
	if not targetState then return nil end
	
	-- Ignore invalid combat states
	if targetState:Is("Combat", "Ragdolled") then return end
	if targetState:Is("Life", "Dead") then return end 
	
	-- Apply hit logic
	_hitTarget(humanoid.Parent, humanoid, tool, targetState, attackOwner.Character)

	return nil
end

-- Client request to perform an attack
local function attackRequest(player: Player, tool : Tool, swingNumber : number): nil
	local character = player.Character :: Model
	local humanoid = character and character:WaitForChild("Humanoid") :: Humanoid
	if not character or not humanoid then return end 

	local entityState = EntityStateService.GetOrCreate(humanoid)
	if not entityState then return nil end
	
	-- Blocks attacks during dash
	if entityState:Is("Locomotion", "Dashing") then return nil end
	
	-- Cooldown validation
	if CooldownService:IsOnCooldown(tool) then return nil end
	
	-- Attempts to enter attacking state
	local sucess = entityState:TrySetState("Combat", "Attacking")
	if sucess then
		local cooldown = ToolsConfig[tool.Name].Cooldown
		CooldownService:Start(tool, cooldown)
		
		-- Unique identifier for this attack instance
		local attackId = HttpService:GenerateGUID(false)
		
		EventBus:Fire(Signals.Attacking, player, swingNumber, attackId, tool)
		_startAttack(player, tool, attackId)

		-- Updates client cooldown UI
		CooldownGui:FireClient(player, "Swing", cooldown)
	end
	
	return nil
end

-- Called when an attack is finished
local function attackEnded(player : Player, attackId : string): nil
	local character = player.Character :: Model
	local humanoid = character and character:WaitForChild("Humanoid") :: Humanoid
	
	if not character or not humanoid then return end 
	
	local entityState = EntityStateService.GetOrCreate(humanoid)
	if not entityState then return nil end
	
	-- Stops hitbox detection for this attack
	EventBus:Fire(Signals.StopHitBoxDetection, player, attackId)
	
	local now = os.clock()
	
	-- Only return to Neutral if not chaining combat
	if now - (_lastCombats[player] or now) > 0.5 then
		entityState:TrySetState("Combat", "Neutral")
	end 
	
	return nil
end

-- Removes humanoid reference when entity is destroyed
local function removeEntity(humanoid: Humanoid): nil
	if not humanoid then return nil end
	
	_entities[humanoid] = nil
	return nil
end

--========================
-- Public API
--========================
local CombatHandler: {[string]: any} = {}

function CombatHandler.Initialize(): nil

	-- Core combat signal bindings
	EventBus:Connect(Signals.AttackRequest, attackRequest)
	EventBus:Connect(Signals.AttackEnded, attackEnded)
	EventBus:Connect(Signals.TargetDetected, targetDetected)
	EventBus:Connect(Signals.RemoveEntity, removeEntity)
	
	-- Loop responsible for entity init and health regeneration
	task.spawn(function()
		while true do
			local now = os.clock()

			for _, player in ipairs(Players:GetPlayers()) do
				local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
				
				-- Ensures each humanoid has a state machine
				if humanoid and not _entities[humanoid] then
					_entities[humanoid] = true
					EntityStateService.GetOrCreate(humanoid)
				end
				
				local lastCombat = _lastCombats[player]
				if not lastCombat then continue end

				local timeSinceCombat = now - lastCombat
				if timeSinceCombat < OUT_OF_COMBAT_DELAY then
					continue
				end
				
				-- Skip invalid regen conditions
				if not humanoid or humanoid.Health <= 0 or humanoid.Health >= humanoid.MaxHealth then
					continue
				end
				
				-- Fires healing signal only once per regen cycle
				if not _regenState[player] then
					_regenState[player] = true
					EventBus:Fire(Signals.Healing, player.Character)
				end
				
				local regenElapsed = timeSinceCombat - OUT_OF_COMBAT_DELAY
				if regenElapsed >= FULL_REGEN_TIME then
					humanoid.Health = humanoid.MaxHealth
				else
					local regenPerSecond = humanoid.MaxHealth / FULL_REGEN_TIME
					local regenThisTick = regenPerSecond * REGEN_TICK

					humanoid.Health = math.min(
						humanoid.Health + regenThisTick,
						humanoid.MaxHealth
					)
					
					-- Client feedback + billboard update
					HealthBar:FireClient(player, "Heal", regenThisTick)
					EntityStateService.UpdateBillboardGui(humanoid)
				end
			end

			task.wait(REGEN_TICK)
		end
	end)

	return nil
end

return CombatHandler
