local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local APH_Folder = ReplicatedStorage:WaitForChild("[APH] - ReplicatedStorage")
local Modules = APH_Folder:WaitForChild("Modules")
local Remotes = APH_Folder:WaitForChild("Remotes")
local SendHB_Info = Remotes:WaitForChild("SendHB_Info")
local APH_Config = require(Modules:WaitForChild("APH_Config"))

local CustomSeat = APH_Config.customVehicleSeat
local customSeatName = APH_Config.vehicleSeatName
local alpha = APH_Config.suavizationFactor


local HitboxPredictor = {}

HitboxPredictor.Car = nil
HitboxPredictor.CarHitbox = nil
HitboxPredictor.lastWeld = {}
local player = nil
local Character = nil
local died = false
local preRender = nil

local Setuped = false
local TargetCFrames = {} -- [vehicle] = hitboxCFrame

function HitboxPredictor:Init()
	--if Setuped then return end
	--Setuped = true

	player = Players.LocalPlayer
	Character = player.Character or player.CharacterAdded:Wait()
	
	player.CharacterAdded:Connect(function(newChar)
		self.OnCharacterAdded(newChar)
	end)

	SendHB_Info.OnClientEvent:Connect(function(vehicle, hitboxCFrame)
		HitboxPredictor.SendHB_InfoEvent(vehicle, hitboxCFrame)
	end)
	
	RunService.RenderStepped:Connect(function(dt)
		for vehicle, targetCFrame in pairs(TargetCFrames) do
			if vehicle.PrimaryPart then
				local lerped = vehicle.PrimaryPart.CFrame:Lerp(targetCFrame, alpha)
				vehicle:PivotTo(lerped)
			else
				TargetCFrames[vehicle] = nil
			end
		end
	end)

	self:ConnectCharacterEvents()
end

function HitboxPredictor.OnCharacterAdded(newChar)
	Character = newChar
	HitboxPredictor:ConnectCharacterEvents()
	died = false
end

function HitboxPredictor:ConnectCharacterEvents()
	local humanoid = Character:FindFirstChild('Humanoid')
	if not humanoid then return end

	self:ConnectCharacterSit(Character)
	self:HumanoidSeatDetection(humanoid)
	humanoid.Died:Connect(function()
		self:OnCharacterDied()
	end)
end

function HitboxPredictor.SendHB_InfoEvent(vehicle, hitboxCFrame)
	if not vehicle or not hitboxCFrame then return end
	if not vehicle.PrimaryPart then return end
	
	TargetCFrames[vehicle] = hitboxCFrame
end

function HitboxPredictor:ConnectCharacterSit(Character)
	local humanoid = Character:WaitForChild("Humanoid")

	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		self.HumanoidSeatDetection(humanoid)
	end)
end

function HitboxPredictor.HumanoidSeatDetection(humanoid)
	local seat = humanoid.SeatPart
	if seat then
		local vehicle = HitboxPredictor:FindLastAncestorModel(seat)
		local vehicleSeat = HitboxPredictor:GetVehicleSeat(vehicle)

		if not vehicle or not vehicleSeat then return end
		HitboxPredictor.CharacterSeatedInCar(vehicle)
	else
		HitboxPredictor.CharacterLeftCar()
	end
end

function HitboxPredictor.CharacterSeatedInCar(vehicle)
	HitboxPredictor:UpdateCar(vehicle)
	HitboxPredictor:ConnectPreRender()
end

function HitboxPredictor.CharacterLeftCar()
	if died then return end
	
	local vehicle = HitboxPredictor.Car
	if not vehicle then return end
	
	HitboxPredictor:DisconnectPreRender()
end

function HitboxPredictor.ConfigurateHitbox()
	local hitboxPart = HitboxPredictor.CarHitbox
	if hitboxPart and hitboxPart:IsA("BasePart") then
		hitboxPart.Massless = true
	end
	return hitboxPart
end

function HitboxPredictor:ConnectPreRender()
	if preRender or not HitboxPredictor.Car or not HitboxPredictor.CarHitbox then return end

	local weldConstraint = HitboxPredictor.CarHitbox:FindFirstChildOfClass("WeldConstraint")
	if weldConstraint then
		HitboxPredictor.lastWeld = {Part0 = weldConstraint.Part0, Part1 = weldConstraint.Part1}
		weldConstraint:Destroy()
	end

	local hitboxPart = self.ConfigurateHitbox()

	local smoothForward = 0

	local alpha = APH_Config.clientAlpha
	local predictionTime = APH_Config.predictionTime
	preRender = RunService.PreRender:Connect(function(dt)
		local car = HitboxPredictor.Car
		local Hitbox = hitboxPart
		if not car or not Hitbox or not car.PrimaryPart then
			if not died then
				self:DisconnectPreRender()
			end
			return
		end

		local worldVel = car.PrimaryPart.AssemblyLinearVelocity
		local localVel = car.PrimaryPart.CFrame:VectorToObjectSpace(worldVel)
		local rawForward = localVel.Z -- positive = forward, negative = backward
		smoothForward = smoothForward + alpha * (rawForward - smoothForward)
		local predictedDist = smoothForward * predictionTime
		local predictedCF = car.PrimaryPart.CFrame * CFrame.new(0, 0, predictedDist)

		Hitbox.CFrame = predictedCF
		SendHB_Info:FireServer(car, Hitbox.CFrame)
	end)
end

function HitboxPredictor:DisconnectPreRender()
	if preRender then
		preRender:Disconnect()
		preRender = nil
	end
	if died then return end
	if HitboxPredictor.lastWeld ~= {} and HitboxPredictor.CarHitbox and HitboxPredictor.Car then
		HitboxPredictor.CarHitbox.CFrame = HitboxPredictor.Car.PrimaryPart.CFrame
		HitboxPredictor.lastWeld = {}
		self:CreateWeldConstraint()
	end
end

function HitboxPredictor:CreateWeldConstraint()
	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = HitboxPredictor.lastWeld.Part0
	weldConstraint.Part1 = HitboxPredictor.lastWeld.Part1
	weldConstraint.Parent = HitboxPredictor.CarHitbox
	return weldConstraint
end

function HitboxPredictor:UpdateCar(vehicle)
	local APH_Hitbox = vehicle:FindFirstChild(APH_Config.APH_Hitbox_Name, true)
	if not APH_Hitbox then return end

	HitboxPredictor.Car = vehicle
	HitboxPredictor.CarHitbox = APH_Hitbox
end

function HitboxPredictor:FindLastAncestorModel(obj)
	local lastModel = nil
	local current = obj.Parent

	while current and current ~= workspace do
		if current:IsA("Model") then
			lastModel = current
		end
		current = current.Parent
	end

	return lastModel
end

function HitboxPredictor:GetVehicleSeat(vehicle)
	if CustomSeat then
		for _, part in ipairs(vehicle:GetDescendants()) do
			if part.Name == customSeatName and part:IsA("Seat") then
				return part
			end
		end
	else
		for _, part in ipairs(vehicle:GetDescendants()) do
			if part:IsA("VehicleSeat") then
				return part
			end
		end
	end

	return nil
end

function HitboxPredictor:OnCharacterDied()
	died = true
end

return HitboxPredictor
