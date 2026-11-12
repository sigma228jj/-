-- Клиент «Кристального разлома»: прицел, ввод (клавиатура / геймпад / тач), UI перезарядки, отброс, тряска камеры.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("CrystalRiftConfig"))
local remote = ReplicatedStorage:WaitForChild(Config.RemoteName)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ACTION = "CrystalRift"
local aiming = false
local cooldownEnd = 0
local cooldownTotal = Config.Cooldown
local shakeAmount = 0

-- UI ------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "CrystalRiftUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -100)
panel.Size = UDim2.fromOffset(240, 52)
panel.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
panel.BackgroundTransparency = 0.15
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", panel)
stroke.Color = Config.Color
stroke.Thickness = 2

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 6)
title.Size = UDim2.new(1, -24, 0, 20)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "[" .. Config.Key.Name .. "] Кристальный разлом"
title.Parent = panel

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(12, 6)
status.Size = UDim2.new(1, -24, 0, 20)
status.Font = Enum.Font.GothamBold
status.TextSize = 15
status.TextXAlignment = Enum.TextXAlignment.Right
status.TextColor3 = Config.Color
status.Parent = panel

local barBack = Instance.new("Frame")
barBack.Position = UDim2.new(0, 12, 1, -18)
barBack.Size = UDim2.new(1, -24, 0, 8)
barBack.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
barBack.BorderSizePixel = 0
barBack.Parent = panel
Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = Config.Color
barFill.BorderSizePixel = 0
barFill.Parent = barBack
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

local function pulsePanel(color)
	stroke.Color = color
	TweenService:Create(stroke, TweenInfo.new(0.4), { Color = Config.Color }):Play()
end

-- Прицел (локальные детали под камерой видны только этому игроку) --------------

local function makeIndicatorPart(shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Config.Color
	part.Transparency = 0.55
	part.Shape = shape
	return part
end

local pathIndicator = makeIndicatorPart(Enum.PartType.Block)
local endIndicator = makeIndicatorPart(Enum.PartType.Cylinder)

local function getAimPoint()
	local ignore = { camera }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local effects = workspace:FindFirstChild(Config.EffectsFolderName)
	if effects then
		table.insert(ignore, effects)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	-- На тач-устройствах нет курсора: целимся в центр экрана.
	local screenPoint
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		screenPoint = camera.ViewportSize / 2
	else
		screenPoint = UserInputService:GetMouseLocation()
	end
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return result and result.Position or (ray.Origin + ray.Direction * 500)
end

local function getRoot()
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function updateIndicator()
	local humanoid, root = getRoot()
	if not root then
		return
	end
	local target = getAimPoint()
	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	if flat.Magnitude < 1 then
		local look = root.CFrame.LookVector
		flat = Vector3.new(look.X, 0, look.Z)
	end
	local direction = flat.Unit
	local distance = math.clamp(flat.Magnitude, Config.MinRange, Config.MaxRange)

	local groundY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2 + 0.1
	local start = Vector3.new(root.Position.X, groundY, root.Position.Z) + direction * Config.StartOffset
	local finish = Vector3.new(root.Position.X, groundY, root.Position.Z) + direction * distance
	local length = math.max((finish - start).Magnitude, 0.5)

	local color = os.clock() < cooldownEnd and Color3.fromRGB(255, 90, 90) or Config.Color
	pathIndicator.Color = color
	endIndicator.Color = color

	pathIndicator.Size = Vector3.new(Config.SpikeWidth, 0.15, length)
	pathIndicator.CFrame = CFrame.lookAt((start + finish) / 2, finish)

	local diameter = Config.FinaleRadius * 2
	endIndicator.Size = Vector3.new(0.15, diameter, diameter)
	endIndicator.CFrame = CFrame.new(finish) * CFrame.Angles(0, os.clock() * 2, math.rad(90))
end

local function startAim()
	aiming = true
	pathIndicator.Parent = camera
	endIndicator.Parent = camera
	RunService:BindToRenderStep("CrystalRiftAim", Enum.RenderPriority.Camera.Value + 2, updateIndicator)
end

local function stopAim()
	aiming = false
	RunService:UnbindFromRenderStep("CrystalRiftAim")
	pathIndicator.Parent = nil
	endIndicator.Parent = nil
end

local function tryCast()
	if os.clock() < cooldownEnd then
		pulsePanel(Color3.fromRGB(255, 90, 90))
		return
	end
	if not getRoot() then
		return
	end
	remote:FireServer("Cast", getAimPoint())
end

-- Ввод: зажать — прицел, отпустить — каст. Для тача CAS сам создаёт кнопку.
local function onAction(_, state)
	if state == Enum.UserInputState.Begin then
		startAim()
	elseif state == Enum.UserInputState.End then
		if aiming then
			stopAim()
			tryCast()
		end
	elseif state == Enum.UserInputState.Cancel then
		if aiming then
			stopAim()
		end
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction(ACTION, onAction, true, Config.Key, Config.GamepadKey)
ContextActionService:SetTitle(ACTION, "Разлом")

player.CharacterRemoving:Connect(function()
	if aiming then
		stopAim()
	end
end)

-- Тряска камеры --------------------------------------------------------------

local function shake(amount)
	shakeAmount = math.max(shakeAmount, amount)
end

RunService:BindToRenderStep("CrystalRiftShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shakeAmount <= 0.001 then
		shakeAmount = 0
		return
	end
	local a = math.rad(shakeAmount)
	camera.CFrame = camera.CFrame
		* CFrame.Angles((math.random() - 0.5) * a, (math.random() - 0.5) * a, (math.random() - 0.5) * a * 0.5)
	shakeAmount = shakeAmount * math.exp(-dt * 8)
end)

-- События сервера ------------------------------------------------------------

remote.OnClientEvent:Connect(function(event, value)
	if event == "Cast" and typeof(value) == "number" then
		cooldownTotal = value
		cooldownEnd = os.clock() + value
		pulsePanel(Config.CoreColor)
		shake(1.5)
	elseif event == "Cooldown" and typeof(value) == "number" then
		cooldownEnd = os.clock() + value
		pulsePanel(Color3.fromRGB(255, 90, 90))
	elseif event == "Knock" and typeof(value) == "Vector3" then
		local humanoid, root = getRoot()
		if root then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			root.AssemblyLinearVelocity = value
			shake(4)
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local remaining = cooldownEnd - os.clock()
	if remaining > 0 then
		barFill.Size = UDim2.fromScale(1 - remaining / cooldownTotal, 1)
		barFill.BackgroundColor3 = Color3.fromRGB(90, 110, 140)
		status.Text = string.format("%.1f", remaining)
	else
		barFill.Size = UDim2.fromScale(1, 1)
		barFill.BackgroundColor3 = Config.Color
		status.Text = aiming and "Цель..." or "Готово"
	end
end)
