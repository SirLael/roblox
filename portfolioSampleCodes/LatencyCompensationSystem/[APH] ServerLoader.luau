local ServerScriptService = game:GetService("ServerScriptService")

local APH_Folder = ServerScriptService:WaitForChild("[APH] - ServerScriptService")
local Modules = APH_Folder:WaitForChild("Modules")
local Remotes = APH_Folder:WaitForChild("Remotes")

local HitboxService = require(Modules:WaitForChild("HitboxService"))
HitboxService:Init()