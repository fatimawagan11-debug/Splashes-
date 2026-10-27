--[[
	Constipated Hub | DON'T SPLASH
	UI: ZetaPro
	Features: Brandon ESP (open) + full Nauru Hub feature set (rebuilt)
	Nauru list: Auto Bleed Out, Water Platform, Anti Slow Water, Auto Pull,
	Auto Ask Help, Flare Aimbot, Auto Throw Flare, Get Nearest Pebbles,
	Creature Proximity Alert, Equip Best, Open Equipment/Shop UI,
	Camera Mode, Timer Size, Return Lobby, full ESP suite
]]

repeat task.wait() until game:IsLoaded()

local Zeta = loadstring(game:HttpGet("https://raw.githubusercontent.com/realkalii/ZetaPro/main/src/init.luau"))()

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
local function alive() return GENV.__ConstipatedDS == GEN end

-- ===================== FLAGS =====================
local F = {
	-- Survival
	WaterPlatform = false,
	AntiSlowWater = false,
	AutoBleedOut = false,
	AutoPull = false,
	AutoAskHelp = false,
	AutoSprint = false,
	-- Combat / tools
	FlareAimbot = false,
	AutoThrowFlare = false,
	GetNearestPebbles = false,
	EquipBest = false,
	AimDown = true,
	FlareMaxRange = 120,
	FlareSmooth = 0.35,
	AlertRadius = 40,
	CreatureAlert = false,
	-- ESP
	EspPlayers = false,
	EspMonster = false,
	EspItems = false,
	EspPlatforms = false,
	EspVaults = false,
	EspCode = false,
	-- Visual
	FullBright = false,
	NoFog = false,
	CameraMode = false, -- 3rd person nudge
	TimerScale = 1,
}

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
	if hum then
		pcall(function() hum:EquipTool(tool) end)
	end
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

-- ===================== WATER PLATFORM (Nauru) =====================
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

-- Anti slow in water
task.spawn(function()
	while alive() do
		if F.AntiSlowWater then
			local hum = getHum()
			if hum and hum.WalkSpeed < 16 then
				hum.WalkSpeed = 16
			end
		end
		task.wait(0.15)
	end
end)

-- Auto sprint
task.spawn(function()
	while alive() do
		if F.AutoSprint then
			local hum = getHum()
			if hum and hum.WalkSpeed < 22 then
				hum.WalkSpeed = 22
			end
		end
		task.wait(0.25)
	end
end)

-- ===================== AUTO BLEED OUT / HELP / PULL =====================
-- Best-effort: fire common remote names / prompts near downed players
local function tryRemote(names, ...)
	for _, folder in ipairs({ ReplicatedStorage, Workspace, LP }) do
		for _, desc in ipairs(folder:GetDescendants()) do
			if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
				local n = string.lower(desc.Name)
				for _, want in ipairs(names) do
					if n:find(want, 1, true) then
						pcall(function()
							if desc:IsA("RemoteEvent") then
								desc:FireServer(...)
							else
								desc:InvokeServer(...)
							end
						end)
						return true
					end
				end
			end
		end
	end
	return false
end

task.spawn(function()
	while alive() do
		if F.AutoBleedOut then
			-- when near death / in water long: try bleed / give up remotes
			tryRemote({ "bleed", "giveup", "surrender", "die", "bleedout" })
		end
		if F.AutoAskHelp then
			tryRemote({ "askhelp", "help", "callhelp", "requesthelp", "sos" })
		end
		if F.AutoPull then
			local hrp = getHRP()
			if hrp then
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
						local d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
						if d < 25 then
							-- rope / pull prompts
							for _, desc in ipairs(p.Character:GetDescendants()) do
								if desc:IsA("ProximityPrompt") then
									local t = string.lower((desc.ActionText or "") .. (desc.ObjectText or ""))
									if t:find("pull", 1, true) or t:find("rescue", 1, true) or t:find("rope", 1, true) then
										firePrompt(desc)
									end
								end
							end
							tryRemote({ "pull", "rescue", "rope", "saveteammate" }, p)
						end
					end
				end
			end
		end
		task.wait(0.35)
	end
end)

-- ===================== FLARE AIMBOT + AUTO THROW =====================
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
						if F.AimDown then
							aimPos = aimPos + Vector3.new(0, -2, 0) -- water near feet
						end
						if F.FlareAimbot then
							aimAt(aimPos)
						end
						if F.AutoThrowFlare then
							local flare = findTool({ "flare" })
							if flare then
								equipTool(flare)
								task.wait(0.05)
								pcall(function()
									flare:Activate()
								end)
								-- also try mouse click via VIM
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

-- Get nearest pebbles
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
							if d < bestD and d < 80 then
								bestD, best = d, inst
							end
						end
					end
				end
				if best then
					local pos = best:IsA("BasePart") and best.Position
						or (best.PrimaryPart and best.PrimaryPart.Position)
						or best:FindFirstChildWhichIsA("BasePart").Position
					-- walk toward / touch
					pcall(function()
						hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
					end)
					for _, d in ipairs(best:GetDescendants()) do
						if d:IsA("ProximityPrompt") then firePrompt(d) end
					end
					if best:IsA("ProximityPrompt") then firePrompt(best) end
				end
			end
		end
		task.wait(0.8)
	end
end)

-- Equip best item (prefer flare > rope > bottle > pebble)
task.spawn(function()
	while alive() do
		if F.EquipBest then
			local order = {
				{ "flare" },
				{ "rope", "rescue" },
				{ "bottle" },
				{ "pebble", "rock" },
				{ "toy" },
			}
			for _, names in ipairs(order) do
				local t = findTool(names)
				if t then
					equipTool(t)
					break
				end
			end
		end
		task.wait(1)
	end
end)

-- Creature proximity alert
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
						Zeta:Notify({ Title = "Creature Alert", Content = string.format("%.0f studs", d), Duration = 2 })
					end
				end
			end
		end
		task.wait(0.4)
	end
end)

-- ===================== ESP =====================
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
					-- photo code pillars / number boards
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

-- Visuals
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
			pcall(function()
				local hum = getHum()
				if hum then
					hum.CameraOffset = Vector3.new(0, 1.5, 8)
				end
			end)
		end
		task.wait(0.5)
	end
end)

-- ===================== UI =====================
local Window = Zeta:CreateWindow({
	Title = "Constipated Hub",
	SubTitle = "DON'T SPLASH · Nauru feature pack",
	Theme = "Dark",
})

local TabMain = Window:AddTab({ Title = "Main", Icon = "home" })
local TabTools = Window:AddTab({ Title = "Tools", Icon = "wrench" })
local TabESP = Window:AddTab({ Title = "ESP", Icon = "eye" })
local TabVis = Window:AddTab({ Title = "Visuals", Icon = "sun" })
local TabMisc = Window:AddTab({ Title = "Misc", Icon = "settings" })

-- MAIN
local SecSurv = TabMain:AddSection("Survival (Nauru)")
SecSurv:AddToggle("WaterPlatform", {
	Title = "Water Platform / Anti Splash",
	Description = "Invisible pad under you — walk water without splash aggro",
	Default = false,
	Callback = function(v) F.WaterPlatform = v end,
})
SecSurv:AddToggle("AntiSlowWater", {
	Title = "Anti Slow In Water",
	Default = false,
	Callback = function(v) F.AntiSlowWater = v end,
})
SecSurv:AddToggle("AutoBleedOut", {
	Title = "Auto Bleed Out",
	Description = "Fires bleed/give-up when stuck",
	Default = false,
	Callback = function(v) F.AutoBleedOut = v end,
})
SecSurv:AddToggle("AutoAskHelp", {
	Title = "Auto Ask For Help",
	Default = false,
	Callback = function(v) F.AutoAskHelp = v end,
})
SecSurv:AddToggle("AutoPull", {
	Title = "Auto Pull Teammates",
	Description = "Rope/rescue prompts + remotes near downed players",
	Default = false,
	Callback = function(v) F.AutoPull = v end,
})
SecSurv:AddToggle("AutoSprint", {
	Title = "Auto Sprint Cap (~22)",
	Default = false,
	Callback = function(v) F.AutoSprint = v end,
})

-- TOOLS
local SecFlare = TabTools:AddSection("Flare")
SecFlare:AddToggle("FlareAimbot", {
	Title = "Flare Aimbot",
	Description = "Aims camera at creature (water-level)",
	Default = false,
	Callback = function(v) F.FlareAimbot = v end,
})
SecFlare:AddToggle("AutoThrowFlare", {
	Title = "Auto Throw Flare",
	Default = false,
	Callback = function(v) F.AutoThrowFlare = v end,
})
SecFlare:AddToggle("AimDown", {
	Title = "Aim Down (water)",
	Default = true,
	Callback = function(v) F.AimDown = v end,
})
SecFlare:AddSlider("FlareRange", {
	Title = "Max Range",
	Min = 20, Max = 200, Default = 120, Rounding = 0,
	Callback = function(v) F.FlareMaxRange = v end,
})
SecFlare:AddSlider("FlareSmooth", {
	Title = "Smoothing",
	Min = 0, Max = 0.9, Default = 0.35, Increment = 0.05,
	Callback = function(v) F.FlareSmooth = v end,
})

local SecPeb = TabTools:AddSection("Items")
SecPeb:AddToggle("GetPebbles", {
	Title = "Get Nearest Pebbles",
	Description = "TP-touch nearest pebble cluster",
	Default = false,
	Callback = function(v) F.GetNearestPebbles = v end,
})
SecPeb:AddToggle("EquipBest", {
	Title = "Equip Best Item",
	Description = "Flare → Rope → Bottle → Pebble",
	Default = false,
	Callback = function(v) F.EquipBest = v end,
})
SecPeb:AddToggle("CreatureAlert", {
	Title = "Creature Proximity Alert",
	Default = false,
	Callback = function(v) F.CreatureAlert = v end,
})
SecPeb:AddSlider("AlertRadius", {
	Title = "Alert Radius",
	Min = 10, Max = 100, Default = 40, Rounding = 0,
	Callback = function(v) F.AlertRadius = v end,
})

local SecUI = TabTools:AddSection("Menus")
SecUI:AddButton({
	Title = "Open Equipment UI",
	Callback = function()
		for _, g in ipairs(LP.PlayerGui:GetDescendants()) do
			local n = string.lower(g.Name)
			if (g:IsA("ScreenGui") or g:IsA("Frame")) and (n:find("equip", 1, true) or n:find("loadout", 1, true)) then
				pcall(function() g.Enabled = true; if g:IsA("Frame") then g.Visible = true end end)
			end
		end
		Zeta:Notify({ Title = "UI", Content = "Tried to open Equipment", Duration = 2 })
	end,
})
SecUI:AddButton({
	Title = "Open Shop / Upgrades",
	Callback = function()
		for _, g in ipairs(LP.PlayerGui:GetDescendants()) do
			local n = string.lower(g.Name)
			if (g:IsA("ScreenGui") or g:IsA("Frame")) and (n:find("shop", 1, true) or n:find("upgrade", 1, true) or n:find("store", 1, true)) then
				pcall(function() g.Enabled = true; if g:IsA("Frame") then g.Visible = true end end)
			end
		end
		Zeta:Notify({ Title = "UI", Content = "Tried to open Shop/Upgrades", Duration = 2 })
	end,
})

-- ESP
local SecEsp = TabESP:AddSection("Overlays")
SecEsp:AddToggle("EspPlayers", { Title = "Player ESP", Default = false, Callback = function(v) F.EspPlayers = v end })
SecEsp:AddToggle("EspMonster", { Title = "Creatures ESP", Default = false, Callback = function(v) F.EspMonster = v end })
SecEsp:AddToggle("EspItems", { Title = "Item ESP", Default = false, Callback = function(v) F.EspItems = v end })
SecEsp:AddToggle("EspPlatforms", { Title = "Platform ESP", Default = false, Callback = function(v) F.EspPlatforms = v end })
SecEsp:AddToggle("EspVaults", { Title = "Vault ESP", Default = false, Callback = function(v) F.EspVaults = v end })
SecEsp:AddToggle("EspCode", { Title = "Code / Pillar ESP", Default = false, Callback = function(v) F.EspCode = v end })
SecEsp:AddButton({
	Title = "Reload ESP",
	Callback = function()
		clearTags()
		Zeta:Notify({ Title = "ESP", Content = "Cleared — rescan soon", Duration = 2 })
	end,
})

-- VISUALS
local SecVis = TabVis:AddSection("World")
SecVis:AddToggle("FullBright", { Title = "Full Bright", Default = false, Callback = function(v) F.FullBright = v end })
SecVis:AddToggle("NoFog", { Title = "No Fog", Default = false, Callback = function(v) F.NoFog = v end })
SecVis:AddToggle("CameraMode", {
	Title = "Camera Mode (3rd person offset)",
	Default = false,
	Callback = function(v)
		F.CameraMode = v
		if not v then
			local hum = getHum()
			if hum then hum.CameraOffset = Vector3.zero end
		end
	end,
})
SecVis:AddSlider("TimerScale", {
	Title = "Timer Size (UI scale attempt)",
	Min = 0.5, Max = 2, Default = 1, Increment = 0.1,
	Callback = function(v)
		F.TimerScale = v
		for _, g in ipairs(LP.PlayerGui:GetDescendants()) do
			local n = string.lower(g.Name)
			if g:IsA("TextLabel") and (n:find("timer", 1, true) or n:find("time", 1, true)) then
				pcall(function() g.TextSize = math.floor(14 * v) end)
			end
		end
	end,
})

-- MISC
local SecMisc = TabMisc:AddSection("Hub")
SecMisc:AddButton({
	Title = "Return To Lobby",
	Callback = function()
		pcall(function()
			TeleportService:Teleport(game.PlaceId, LP)
		end)
		tryRemote({ "lobby", "returnlobby", "leaverun", "menu" })
	end,
})
SecMisc:AddButton({
	Title = "Unload Hub",
	Callback = function()
		GENV.__ConstipatedDS = GEN + 1
		clearTags()
		if marksFolder then marksFolder:Destroy() end
		local hum = getHum()
		if hum then hum.CameraOffset = Vector3.zero end
		pcall(function() Zeta:Unload() end)
	end,
})

Zeta:Notify({
	Title = "Constipated Hub",
	Content = "DON'T SPLASH · Nauru feature pack loaded",
	Duration = 4,
})
print("[Constipated Hub] DON'T SPLASH | Nauru features + Brandon ESP | ZetaPro")
