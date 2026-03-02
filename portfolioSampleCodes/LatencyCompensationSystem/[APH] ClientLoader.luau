local ReplicatedStorage = game:GetService("ReplicatedStorage")

local APH_Folder = ReplicatedStorage:WaitForChild("[APH] - ReplicatedStorage")
local Modules = APH_Folder:WaitForChild("Modules")
local Remotes = APH_Folder:WaitForChild("Remotes")

local HitboxPredictor = require(Modules:WaitForChild("HitboxPredictor"))
HitboxPredictor:Init()

print("initializing")
