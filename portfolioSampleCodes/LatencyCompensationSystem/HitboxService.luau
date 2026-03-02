local HitboxService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local APH_Folder = ReplicatedStorage:WaitForChild("[APH] - ReplicatedStorage")
local Modules = APH_Folder:WaitForChild("Modules")
local Remotes = APH_Folder:WaitForChild("Remotes")

local VehiclesFolder = ReplicatedStorage:WaitForChild("Bikes")
local allVehicles = VehiclesFolder:GetChildren()

local SendHB_Info = Remotes:WaitForChild("SendHB_Info")
local APH_Config = require(Modules:WaitForChild("APH_Config"))

local APH_HITBOX_NAME = APH_Config.APH_Hitbox_Name

local Setuped = false

function HitboxService:Init()
	
	if Setuped then return end
	Setuped = true
	
	self:SetupCollisionGroups()
	self:SetupHitboxesAndGroups()
	self:SetupPlayerPartsGroups()
	self:ConnectPlayerAdded()
	SendHB_Info.OnServerEvent:Connect(function(player, vehicle, hitboxCFrame)
		self.HB_InfoEvent(player, vehicle, hitboxCFrame)
	end)
end

function HitboxService:SetupCollisionGroups()
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:RegisterCollisionGroup("APH_Hitboxes")
	PhysicsService:RegisterCollisionGroup("Vehicle_Structure")

	PhysicsService:CollisionGroupSetCollidable("Players", "APH_Hitboxes", false)
	PhysicsService:CollisionGroupSetCollidable("APH_Hitboxes", "APH_Hitboxes", true)
	PhysicsService:CollisionGroupSetCollidable("Vehicle_Structure", "APH_Hitboxes", false)
	PhysicsService:CollisionGroupSetCollidable("Vehicle_Structure", "Vehicle_Structure", false)
end

function HitboxService:SetupHitboxesAndGroups()
	for _, vehicle in ipairs(allVehicles) do
		for __, vehiclePart in ipairs(vehicle:GetDescendants()) do
			if vehiclePart.Name == APH_HITBOX_NAME and vehiclePart:IsA("BasePart") then
				vehiclePart.CollisionGroup = "APH_Hitboxes"
			elseif vehiclePart:IsA("BasePart") then
				vehiclePart.CollisionGroup = "Vehicle_Structure"
			end
		end
	end
end

function HitboxService:SetupPlayerPartsGroups()
	for _, player in ipairs(Players:GetPlayers()) do
		for __, part in ipairs(player.Character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CollisionGroup = "Players"
			end
		end
	end
end

function HitboxService:ConnectPlayerAdded()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			for __, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CollisionGroup = "Players"
				end
			end
		end)
	end)
end

function HitboxService.HB_InfoEvent(player, vehicle, hitboxCFrame)
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			SendHB_Info:FireClient(otherPlayer, vehicle, hitboxCFrame)
		end 
	end
end

return HitboxService
