--[[
	Constipated Hub | DON'T SPLASH
	UI: Orion Lib
	Remotes: StillWater (in-game) + StillWaterLobby (lobby)
]]

repeat task.wait() until game:IsLoaded()

local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/jensonhirst/Orion/main/source"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local function getChar()
	return LP.Character
end
local function getHRP()
	local c = getChar()
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.__ConstipatedDS = (GENV.__ConstipatedDS or 0) + 1
local GEN = GENV.__ConstipatedDS
local function alive()
	return GENV.__ConstipatedDS == GEN
end

-- ===================== REMOTES =====================
local function path(root, ...)
	local cur = root
	for _, name in ipairs({ ... }) do
		if not cur then return nil end
		cur = cur:FindFirstChild(name)
	end
	return cur
end

local Remotes = {}
local function refreshRemotes()
	local SW = path(ReplicatedStorage, "StillWater", "Remotes")
	local Lobby = path(ReplicatedStorage, "StillWaterLobby", "Remotes")
	Remotes.BleedOut = SW and SW:FindFirstChild("BleedOut")
	Remotes.AskForHelp = SW and SW:FindFirstChild("AskForHelp")
	Remotes.SelfRescue = SW and SW:FindFirstChild("SelfRescue")
	Remotes.RescueHold = SW and SW:FindFirstChild("RescueHold")
	Remotes.UseItem = SW and SW:FindFirstChild("UseItem")
	Remotes.FriendRevive = SW and SW:FindFirstChild("FriendRevive")
	Remotes.ReturnToLobby = SW and SW:FindFirstChild("ReturnToLobby")
	Remotes.PlayAgain = SW and SW:FindFirstChild("PlayAgain")
	Remotes.Photo = SW and SW:FindFirstChild("Photo")
	Remotes.ShopAction = (SW and SW:FindFirstChild("ShopAction")) or (Lobby and Lobby:FindFirstChild("ShopAction"))
	Remotes.Push = SW and SW:FindFirstChild("Push")
	Remotes.Msg = SW and SW:FindFirstChild("Msg")
	Remotes.MemStep = SW and SW:FindFirstChild("MemStep")
	Remotes.RequestRescuePurchase = SW and SW:FindFirstChild("RequestRescuePurchase")
	Remotes.RescuePurchaseClosed = SW and SW:FindFirstChild("RescuePurchaseClosed")
	Remotes.DoubleCoins = SW and SW:FindFirstChild("DoubleCoins")
	Remotes.GiveCoins = (SW and SW:FindFirstChild("GiveCoins")) or (Lobby and Lobby:FindFirstChild("GiveCoins"))
	Remotes.SetStat = (SW and SW:FindFirstChild("SetStat")) or (Lobby and Lobby:FindFirstChild("SetStat"))
	Remotes.AddCurrency = (SW and SW:FindFirstChild("AddCurrency")) or (Lobby and Lobby:FindFirstChild("AddCurrency"))
	Remotes.UnlockAll = (SW and SW:FindFirstChild("UnlockAll")) or (Lobby and Lobby:FindFirstChild("UnlockAll"))
	Remotes.OpenPanel = Lobby and Lobby:FindFirstChild("OpenPanel")
	Remotes.PartyAction = Lobby and Lobby:FindFirstChild("PartyAction")
	Remotes.SaveSettings = Lobby and Lobby:FindFirstChild("SaveSettings")
	Remotes.ClaimGroupReward = Lobby and Lobby:FindFirstChild("ClaimGroupReward")
end
refreshRemotes()
task.spawn(function()
	while alive() do
		refreshRemotes()
		task.wait(3)
	end
end)

local function fire(r, ...)
	if not r then return false end
	local ok = pcall(function(...)
		if r:IsA("RemoteEvent") then
			r:FireServer(...)
		elseif r:IsA("RemoteFunction") then
			r:InvokeServer(...)
		end
	end, ...)
	return ok
end

-- ===================== FLAGS =====================
local F = {
	WaterPlatform = false,
	AntiSlowWater = false,
	AutoBleedOut = false,
	AutoAskHelp = false,
	AutoSelfRescue = false,
	AutoPull = false,
	AutoSprint = false,
	FlareAimbot = false,
	AutoThrowFlare = false,
	GetNearestPebbles = false,
	EquipBest = false,
	AimDown = true,
	FlareMaxRange = 120,
	FlareSmooth = 0.35,
	AlertRadius = 40,
	CreatureAlert = false,
	EspPlayers = false,
	EspMonster = false,
	EspItems = false,
	EspPlatforms = false,
	EspVaults = false,
	EspCode = false,
	FullBright = false,
	NoFog = false,
	CameraMode = false,
}

-- ===================== HELPERS =====================
local marksFolder = Workspace:FindFirstChild("Constipated_DS_Marks")
if marksFolder then marksFolder:Destroy() end
marksFolder = Instance.new("Folder")
marksFolder.Name = "Constipated_DS_Marks"
marksFolder.Parent = Workspace

local tagged, platformAdorns, vaultLabels = {}, {}, {}
local monsterWords = { "monster", "creature", "entity", "beast", "hunter", "locust" }
local itemWords = { "pebble", "rock", "bottle", "flare", "battery", "key", "tool", "pickup", "collectible", "rope", "toy" }
local platformWords = { "platform", "pad", "tile", "step", "sinking", "spinner", "spinplatform", "collapse", "temporary" }

local function matchName(name, words)
	local s = string.lower(name or "")
	for _, w in ipairs(words) do
		if s:find(w, 1, true) then return true end
	end
	return false
end

local function clearTags()
	for _, h in pairs(tagged) do pcall(function() h:Destroy() end) end
	table.clear(tagged)
	for _, a in pairs(platformAdorns) do pcall(function() a:Destroy() end) end
	table.clear(platformAdorns)
	for _, b in pairs(vaultLabels) do pcall(function() b:Destroy() end) end
	table.clear(vaultLabels)
end

local function tagModel(inst, color)
	if tagged[inst] then
		tagged[inst].FillColor = color
		tagged[inst].OutlineColor = color
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "ConstipatedESP"
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.55
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = inst
	tagged[inst] = h
end

local function isPlatform(inst)
	if not inst:IsA("BasePart") then return false end
	if LP.Character and inst:IsDescendantOf(LP.Character) then return false end
	if inst.Size.X < 1.5 or inst.Size.Z < 1.5 or inst.Size.Y > 16 then return false end
	local parent = inst.Parent
	local name = string.lower(inst.Name .. " " .. (parent and parent.Name or ""))
	if matchName(name, platformWords) then return true end
	for k in pairs(inst:GetAttributes()) do
		local key = string.lower(tostring(k))
		if key == "cansink" or key == "issinking" or key == "sinking"
			or key == "issafe" or key == "stable" or key == "platform" or key == "isplatform" then
			return true
		end
	end
	return false
end

local function tagPlatform(inst)
	if platformAdorns[inst] then return end
	local part = inst:IsA("BasePart") and inst or (inst:IsA("Model") and inst:FindFirstChildWhichIsA("BasePart", true))
	if not part then return end
	local adorn = Instance.new("BoxHandleAdornment")
	adorn.Name = "ConstipatedPlatform"
	adorn.Adornee = part
	adorn.Size = part.Size + Vector3.new(0.08, 0.08, 0.08)
	adorn.Color3 = Color3.fromRGB(70, 255, 120)
	adorn.Transparency = 0.55
	adorn.AlwaysOnTop = true
	adorn.ZIndex = 5
	adorn.Parent = marksFolder
	platformAdorns[inst] = adorn
end

local function vaultPrompt(inst)
	if not inst:IsA("ProximityPrompt") then return false end
	local words = string.lower(
		(inst.ActionText or "") .. " " .. (inst.ObjectText or "") .. " " .. (inst.Parent and inst.Parent.Name or "")
	)
	return words:find("valve", 1, true) or words:find("maintenance control", 1, true)
end

local function vaultTarget(prompt)
	local node = prompt.Parent
	if not node then return nil end
	local fallback = node
	for _ = 1, 4 do
		if not node or node == Workspace then break end
		if node:IsA("Model") and node:FindFirstChildWhichIsA("BasePart", true) then return node end
		if node:IsA("BasePart") then fallback = node end
		node = node.Parent
	end
	return fallback
end

local function vaultStatus(prompt)
	local txt = string.lower((prompt.ActionText or "") .. " " .. (prompt.ObjectText or ""))
	if not prompt.Enabled or txt:find("close valve", 1, true) then return "activated" end
	if txt:find("open valve", 1, true) then return "available" end
	return "unknown"
end

local function labelVault(target, mode)
	local anchor = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then return end
	local bb = Instance.new("BillboardGui")
	bb.Name = "ConstipatedVault"
	bb.Adornee = anchor
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(170, 36)
	bb.StudsOffsetWorldSpace = Vector3.new(0, math.max(anchor.Size.Y / 2 + 2, 3), 0)
	bb.Parent = marksFolder
	local root = getHRP()
	local distance = root and math.floor((root.Position - anchor.Position).Magnitude + 0.5)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.Text = "VAULT • " .. string.upper(mode) .. (distance and (" • " .. distance .. "s") or "")
	label.TextColor3 = mode == "available" and Color3.fromRGB(255, 105, 105)
		or mode == "activated" and Color3.fromRGB(80, 245, 150)
		or Color3.fromRGB(220, 220, 220)
	label.Parent = bb
	table.insert(vaultLabels, bb)
end

local function findMonster()
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and not Players:GetPlayerFromCharacter(inst)
			and matchName(inst.Name, monsterWords)
			and (inst:FindFirstChildOfClass("Humanoid") or inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")) then
			return inst
		end
	end
	return nil
end

local function findTool(names)
	local backpack = LP:FindFirstChild("Backpack")
	local char = getChar()
	local function check(parent)
		if not parent then return nil end
		for _, t in ipairs(parent:GetChildren()) do
			if t:IsA("Tool") then
				local n = string.lower(t.Name)
				for _, want in ipairs(names) do
					if n:find(want, 1, true) then return t end
				end
			end
		end
	end
	return check(char) or check(backpack)
end

local function equipTool(tool)
	if not tool then return end
	local hum = getHum()
	if hum then pcall(function() hum:EquipTool(tool) end) end
end

local function firePrompt(prompt)
	if not prompt then return end
	pcall(function()
		if fireproximityprompt then
			fireproximityprompt(prompt)
		else
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration or 0.1)
			prompt:InputHoldEnd()
		end
	end)
end

-- ===================== LOOPS =====================
local ghostPart
local function ensureGhost()
	if ghostPart and ghostPart.Parent then return ghostPart end
	ghostPart = Instance.new("Part")
	ghostPart.Name = "ConstipatedWaterPad"
	ghostPart.Size = Vector3.new(8, 1, 8)
	ghostPart.Anchored = true
	ghostPart.CanCollide = true
	ghostPart.Transparency = 1
	ghostPart.Material = Enum.Material.SmoothPlastic
	ghostPart.Parent = marksFolder
	return ghostPart
end

task.spawn(function()
	while alive() do
		if F.WaterPlatform then
			local hrp = getHRP()
			local g = ensureGhost()
			if hrp then
				g.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - 3.35, hrp.Position.Z)
				g.CanCollide = true
			end
		elseif ghostPart then
			ghostPart.CanCollide = false
		end
		RunService.Heartbeat:Wait()
	end
end)

task.spawn(function()
	while alive() do
		if F.AntiSlowWater then
			local hum = getHum()
			if hum and hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
		end
		if F.AutoSprint then
			local hum = getHum()
			if hum and hum.WalkSpeed < 22 then hum.WalkSpeed = 22 end
		end
		task.wait(0.2)
	end
end)

task.spawn(function()
	while alive() do
		if F.AutoBleedOut then
			fire(Remotes.BleedOut)
		end
		if F.AutoAskHelp then
			fire(Remotes.AskForHelp)
		end
		if F.AutoSelfRescue then
			fire(Remotes.SelfRescue)
		end
		if F.AutoPull then
			fire(Remotes.RescueHold)
			local hrp = getHRP()
			if hrp then
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= LP and p.Character then
						local phr = p.Character:FindFirstChild("HumanoidRootPart")
						if phr and (phr.Position - hrp.Position).Magnitude < 30 then
							fire(Remotes.FriendRevive, p)
							fire(Remotes.FriendRevive, p.UserId)
							fire(Remotes.FriendRevive, p.Name)
							for _, d in ipairs(p.Character:GetDescendants()) do
								if d:IsA("ProximityPrompt") then
									local t = string.lower((d.ActionText or "") .. (d.ObjectText or ""))
									if t:find("pull", 1, true) or t:find("rescue", 1, true) or t:find("rope", 1, true) then
										firePrompt(d)
									end
								end
							end
						end
					end
				end
			end
		end
		task.wait(0.4)
	end
end)

local function aimAt(pos)
	if not Camera then return end
	local origin = Camera.CFrame.Position
	local target = CFrame.lookAt(origin, pos)
	if F.FlareSmooth > 0 then
		Camera.CFrame = Camera.CFrame:Lerp(target, math.clamp(1 - F.FlareSmooth, 0.1, 1))
	else
		Camera.CFrame = target
	end
end

task.spawn(function()
	while alive() do
		if F.FlareAimbot or F.AutoThrowFlare then
			local monster = findMonster()
			local hrp = getHRP()
			if monster and hrp then
				local part = monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart")
				if part then
					local dist = (part.Position - hrp.Position).Magnitude
					if dist <= F.FlareMaxRange then
						local aimPos = part.Position
						if F.AimDown then aimPos = aimPos + Vector3.new(0, -2, 0) end
						if F.FlareAimbot then aimAt(aimPos) end
						if F.AutoThrowFlare then
							local flare = findTool({ "flare" })
							if flare then
								equipTool(flare)
								task.wait(0.05)
								fire(Remotes.UseItem, "Flare")
								fire(Remotes.UseItem, flare.Name)
								fire(Remotes.UseItem)
								pcall(function() flare:Activate() end)
								pcall(function()
									VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
									VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
								end)
							end
						end
					end
				end
			end
		end
		task.wait(0.12)
	end
end)

task.spawn(function()
	while alive() do
		if F.GetNearestPebbles then
			local hrp = getHRP()
			if hrp then
				local best, bestD = nil, 1e9
				for _, inst in ipairs(Workspace:GetDescendants()) do
					if (inst:IsA("BasePart") or inst:IsA("Model") or inst:IsA("Tool"))
						and matchName(inst.Name, { "pebble", "rock", "stone" })
						and not (LP.Character and inst:IsDescendantOf(LP.Character)) then
						local pos = inst:IsA("BasePart") and inst.Position
							or (inst.PrimaryPart and inst.PrimaryPart.Position)
							or (inst:FindFirstChildWhichIsA("BasePart") and inst:FindFirstChildWhichIsA("BasePart").Position)
						if pos then
							local d = (pos - hrp.Position).Magnitude
							if d < bestD and d < 80 then bestD, best = d, inst end
						end
					end
				end
				if best then
					local pos = best:IsA("BasePart") and best.Position
						or (best.PrimaryPart and best.PrimaryPart.Position)
						or best:FindFirstChildWhichIsA("BasePart").Position
					pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end)
					for _, d in ipairs(best:GetDescendants()) do
						if d:IsA("ProximityPrompt") then firePrompt(d) end
					end
				end
			end
		end
		task.wait(0.8)
	end
end)

task.spawn(function()
	while alive() do
		if F.EquipBest then
			local order = { { "flare" }, { "rope", "rescue" }, { "bottle" }, { "pebble", "rock" }, { "toy" } }
			for _, names in ipairs(order) do
				local t = findTool(names)
				if t then equipTool(t) break end
			end
		end
		task.wait(1)
	end
end)

local lastAlert = 0
task.spawn(function()
	while alive() do
		if F.CreatureAlert then
			local hrp = getHRP()
			local monster = findMonster()
			if hrp and monster then
				local part = monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart")
				if part then
					local d = (part.Position - hrp.Position).Magnitude
					if d <= F.AlertRadius and (os.clock() - lastAlert) > 2.5 then
						lastAlert = os.clock()
						pcall(function()
							StarterGui:SetCore("SendNotification", {
								Title = "CREATURE NEAR",
								Text = string.format("%.0f studs away", d),
								Duration = 2,
							})
						end)
						OrionLib:MakeNotification({
							Name = "Creature Alert",
							Content = string.format("%.0f studs", d),
							Time = 2,
						})
					end
				end
			end
		end
		task.wait(0.4)
	end
end)

task.spawn(function()
	while alive() do
		clearTags()
		if F.EspPlayers then
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LP and p.Character then
					tagModel(p.Character, Color3.fromRGB(70, 210, 255))
				end
			end
		end
		if F.EspMonster or F.EspItems or F.EspPlatforms or F.EspVaults or F.EspCode then
			local count, seenVaults = 0, {}
			for _, inst in ipairs(Workspace:GetDescendants()) do
				count += 1
				if count > 22000 then break end
				if F.EspVaults and vaultPrompt(inst) then
					local target = vaultTarget(inst)
					if target and not seenVaults[target] then
						seenVaults[target] = true
						local mode = vaultStatus(inst)
						local color = mode == "available" and Color3.fromRGB(255, 85, 85)
							or mode == "activated" and Color3.fromRGB(70, 245, 140)
							or Color3.fromRGB(190, 190, 190)
						tagModel(target, color)
						labelVault(target, mode)
					end
				end
				if F.EspMonster and inst:IsA("Model") and not Players:GetPlayerFromCharacter(inst)
					and matchName(inst.Name, monsterWords)
					and (inst:FindFirstChildOfClass("Humanoid") or inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")) then
					tagModel(inst, Color3.fromRGB(255, 75, 105))
				elseif F.EspItems and (inst:IsA("Tool") or inst:IsA("Model") or inst:IsA("BasePart"))
					and matchName(inst.Name, itemWords)
					and not (LP.Character and inst:IsDescendantOf(LP.Character)) then
					tagModel(inst, Color3.fromRGB(255, 200, 80))
				elseif F.EspPlatforms and isPlatform(inst) then
					tagPlatform(inst)
				elseif F.EspCode and inst:IsA("BasePart") then
					local n = string.lower(inst.Name .. " " .. (inst.Parent and inst.Parent.Name or ""))
					if n:find("code", 1, true) or n:find("pillar", 1, true) or n:find("number", 1, true) or n:find("photo", 1, true) then
						tagModel(inst, Color3.fromRGB(180, 100, 255))
					end
				end
			end
		end
		task.wait(1.4)
	end
end)

task.spawn(function()
	while alive() do
		if F.FullBright then
			Lighting.Ambient = Color3.new(1, 1, 1)
			Lighting.Brightness = 2
			Lighting.ClockTime = 14
		end
		if F.NoFog then
			Lighting.FogEnd = 1e6
			pcall(function()
				for _, v in ipairs(Lighting:GetChildren()) do
					if v:IsA("Atmosphere") then v.Density = 0 end
				end
			end)
		end
		if F.CameraMode then
			local hum = getHum()
			if hum then hum.CameraOffset = Vector3.new(0, 1.5, 8) end
		end
		task.wait(0.5)
	end
end)

-- ===================== ORION UI =====================
local Window = OrionLib:MakeWindow({
	Name = "Constipated Hub | DON'T SPLASH",
	HidePremium = true,
	SaveConfig = false,
	ConfigFolder = "ConstipatedDS",
	IntroEnabled = true,
	IntroText = "Constipated Hub",
})

local TabMain = Window:MakeTab({ Name = "Main", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local TabTools = Window:MakeTab({ Name = "Tools", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local TabESP = Window:MakeTab({ Name = "ESP", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local TabVis = Window:MakeTab({ Name = "Visuals", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local TabMisc = Window:MakeTab({ Name = "Misc", Icon = "rbxassetid://4483345998", PremiumOnly = false })

TabMain:AddSection({ Name = "Survival" })
TabMain:AddToggle({
	Name = "Water Platform / Anti Splash",
	Default = false,
	Callback = function(v) F.WaterPlatform = v end,
})
TabMain:AddToggle({
	Name = "Anti Slow In Water",
	Default = false,
	Callback = function(v) F.AntiSlowWater = v end,
})
TabMain:AddToggle({
	Name = "Auto Bleed Out",
	Default = false,
	Callback = function(v) F.AutoBleedOut = v end,
})
TabMain:AddToggle({
	Name = "Auto Ask For Help",
	Default = false,
	Callback = function(v) F.AutoAskHelp = v end,
})
TabMain:AddToggle({
	Name = "Auto Self Rescue",
	Default = false,
	Callback = function(v) F.AutoSelfRescue = v end,
})
TabMain:AddToggle({
	Name = "Auto Pull / Friend Revive",
	Default = false,
	Callback = function(v) F.AutoPull = v end,
})
TabMain:AddToggle({
	Name = "Auto Sprint Cap (~22)",
	Default = false,
	Callback = function(v) F.AutoSprint = v end,
})

TabMain:AddSection({ Name = "One-shots" })
TabMain:AddButton({
	Name = "Bleed Out Now",
	Callback = function()
		fire(Remotes.BleedOut)
		OrionLib:MakeNotification({ Name = "BleedOut", Content = "Fired", Time = 2 })
	end,
})
TabMain:AddButton({
	Name = "Ask Help Now",
	Callback = function()
		fire(Remotes.AskForHelp)
		OrionLib:MakeNotification({ Name = "AskForHelp", Content = "Fired", Time = 2 })
	end,
})
TabMain:AddButton({
	Name = "Self Rescue Now",
	Callback = function()
		fire(Remotes.SelfRescue)
		OrionLib:MakeNotification({ Name = "SelfRescue", Content = "Fired", Time = 2 })
	end,
})

TabTools:AddSection({ Name = "Flare" })
TabTools:AddToggle({
	Name = "Flare Aimbot",
	Default = false,
	Callback = function(v) F.FlareAimbot = v end,
})
TabTools:AddToggle({
	Name = "Auto Throw Flare",
	Default = false,
	Callback = function(v) F.AutoThrowFlare = v end,
})
TabTools:AddToggle({
	Name = "Aim Down (water)",
	Default = true,
	Callback = function(v) F.AimDown = v end,
})
TabTools:AddSlider({
	Name = "Max Range",
	Min = 20,
	Max = 200,
	Default = 120,
	Increment = 5,
	Callback = function(v) F.FlareMaxRange = v end,
})
TabTools:AddSlider({
	Name = "Smoothing",
	Min = 0,
	Max = 90,
	Default = 35,
	Increment = 5,
	Callback = function(v) F.FlareSmooth = v / 100 end,
})

TabTools:AddSection({ Name = "Items" })
TabTools:AddToggle({
	Name = "Get Nearest Pebbles",
	Default = false,
	Callback = function(v) F.GetNearestPebbles = v end,
})
TabTools:AddToggle({
	Name = "Equip Best Item",
	Default = false,
	Callback = function(v) F.EquipBest = v end,
})
TabTools:AddToggle({
	Name = "Creature Proximity Alert",
	Default = false,
	Callback = function(v) F.CreatureAlert = v end,
})
TabTools:AddSlider({
	Name = "Alert Radius",
	Min = 10,
	Max = 100,
	Default = 40,
	Increment = 5,
	Callback = function(v) F.AlertRadius = v end,
})
TabTools:AddButton({
	Name = "Use Item (remote)",
	Callback = function()
		fire(Remotes.UseItem)
		OrionLib:MakeNotification({ Name = "UseItem", Content = "Fired", Time = 2 })
	end,
})
TabTools:AddButton({
	Name = "Photo / Code Snap",
	Callback = function()
		fire(Remotes.Photo)
		OrionLib:MakeNotification({ Name = "Photo", Content = "Fired", Time = 2 })
	end,
})

TabESP:AddSection({ Name = "Overlays" })
TabESP:AddToggle({ Name = "Player ESP", Default = false, Callback = function(v) F.EspPlayers = v end })
TabESP:AddToggle({ Name = "Creatures ESP", Default = false, Callback = function(v) F.EspMonster = v end })
TabESP:AddToggle({ Name = "Item ESP", Default = false, Callback = function(v) F.EspItems = v end })
TabESP:AddToggle({ Name = "Platform ESP", Default = false, Callback = function(v) F.EspPlatforms = v end })
TabESP:AddToggle({ Name = "Vault ESP", Default = false, Callback = function(v) F.EspVaults = v end })
TabESP:AddToggle({ Name = "Code / Pillar ESP", Default = false, Callback = function(v) F.EspCode = v end })
TabESP:AddButton({
	Name = "Reload ESP",
	Callback = function()
		clearTags()
		OrionLib:MakeNotification({ Name = "ESP", Content = "Cleared — rescan soon", Time = 2 })
	end,
})

TabVis:AddSection({ Name = "World" })
TabVis:AddToggle({
	Name = "Full Bright",
	Default = false,
	Callback = function(v) F.FullBright = v end,
})
TabVis:AddToggle({
	Name = "No Fog",
	Default = false,
	Callback = function(v) F.NoFog = v end,
})
TabVis:AddToggle({
	Name = "Camera Mode (3rd person)",
	Default = false,
	Callback = function(v)
		F.CameraMode = v
		if not v then
			local hum = getHum()
			if hum then hum.CameraOffset = Vector3.zero end
		end
	end,
})

TabMisc:AddSection({ Name = "Lobby / Run" })
TabMisc:AddButton({
	Name = "Return To Lobby",
	Callback = function()
		fire(Remotes.ReturnToLobby)
		pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
	end,
})
TabMisc:AddButton({
	Name = "Play Again",
	Callback = function()
		fire(Remotes.PlayAgain)
	end,
})
TabMisc:AddButton({
	Name = "Open Panel (lobby)",
	Callback = function()
		fire(Remotes.OpenPanel)
	end,
})
TabMisc:AddButton({
	Name = "Refresh Remotes",
	Callback = function()
		refreshRemotes()
		local found = 0
		for k, v in pairs(Remotes) do
			if v then found += 1 end
		end
		OrionLib:MakeNotification({
			Name = "Remotes",
			Content = found .. " bound (StillWater)",
			Time = 3,
		})
	end,
})
TabMisc:AddButton({
	Name = "Unload Hub",
	Callback = function()
		GENV.__ConstipatedDS = GEN + 1
		clearTags()
		if marksFolder then marksFolder:Destroy() end
		local hum = getHum()
		if hum then hum.CameraOffset = Vector3.zero end
		OrionLib:Destroy()
	end,
})

OrionLib:MakeNotification({
	Name = "Constipated Hub",
	Content = "DON'T SPLASH loaded · Orion + StillWater remotes",
	Image = "rbxassetid://4483345998",
	Time = 5,
})

print("[Constipated Hub] DON'T SPLASH | Orion | StillWater remotes")
