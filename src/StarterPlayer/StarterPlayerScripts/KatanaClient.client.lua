-- Клиент катаны: ввод, кнопки способностей, перезарядки, отброс и эффекты камеры.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("KatanaConfig"))
local remote = ReplicatedStorage:WaitForChild(Config.RemoteName)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ABILITIES = {
	{ id = "Slash", key = "ЛКМ", name = "Удар" },
	{ id = "Wave", key = Config.Keys.Wave.Name, name = "Волна", action = "KatanaWave" },
	{ id = "Dash", key = Config.Keys.Dash.Name, name = "Рывок", action = "KatanaDash" },
	{ id = "Ultimate", key = Config.Keys.Ultimate.Name, name = "Буря клинков", action = "KatanaUltimate" },
}

local equippedTool = nil
local activatedConnection = nil
local readyAt = {}
local durations = {}
local shakeAmount = 0

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "KatanaUI"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -165)
bar.Size = UDim2.fromOffset(4 * 80 + 3 * 8, 80)
bar.BackgroundTransparency = 1
bar.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = bar

local slots = {}

for order, ability in ipairs(ABILITIES) do
	local slot = Instance.new("Frame")
	slot.LayoutOrder = order
	slot.Size = UDim2.fromOffset(80, 80)
	slot.BackgroundColor3 = Color3.fromRGB(20, 18, 26)
	slot.BackgroundTransparency = 0.1
	slot.ClipsDescendants = true
	slot.Parent = bar
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", slot)
	stroke.Color = Config.Color
	stroke.Thickness = 2

	local key = Instance.new("TextLabel")
	key.BackgroundTransparency = 1
	key.Position = UDim2.fromOffset(6, 4)
	key.Size = UDim2.new(1, -12, 0, 18)
	key.Font = Enum.Font.GothamBlack
	key.TextSize = 16
	key.TextXAlignment = Enum.TextXAlignment.Left
	key.TextColor3 = Config.Color
	key.Text = ability.key
	key.ZIndex = 3
	key.Parent = slot

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 4, 1, -30)
	name.Size = UDim2.new(1, -8, 0, 26)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = ability.name
	name.ZIndex = 3
	name.Parent = slot

	local overlay = Instance.new("Frame")
	overlay.AnchorPoint = Vector2.new(0, 1)
	overlay.Position = UDim2.fromScale(0, 1)
	overlay.Size = UDim2.fromScale(1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 2
	overlay.Parent = slot

	local timer = Instance.new("TextLabel")
	timer.BackgroundTransparency = 1
	timer.Size = UDim2.fromScale(1, 1)
	timer.Font = Enum.Font.GothamBlack
	timer.TextSize = 24
	timer.TextColor3 = Color3.new(1, 1, 1)
	timer.TextStrokeTransparency = 0.3
	timer.Text = ""
	timer.ZIndex = 4
	timer.Parent = slot

	slots[ability.id] = { stroke = stroke, overlay = overlay, timer = timer }
end

local function flashSlot(id, color)
	local slot = slots[id]
	if slot then
		slot.stroke.Color = color
		TweenService:Create(slot.stroke, TweenInfo.new(0.4), { Color = Config.Color }):Play()
	end
end

---------------------------------------------------------------------------
-- Прицел и использование
---------------------------------------------------------------------------

local function getRoot()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function getAimPoint()
	local ignore = { camera }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	for _, name in ipairs({ Config.EffectsFolderName, "CrystalRiftEffects" }) do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

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

-- Разворачиваем персонажа к прицелу перед ударом (клиент владеет своим персонажем).
local function faceAim(aim)
	local _, root = getRoot()
	if not root then
		return
	end
	local dir = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	if dir.Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	end
end

local function useAbility(id)
	if not equippedTool or not getRoot() then
		return
	end
	if os.clock() < (readyAt[id] or 0) then
		flashSlot(id, Color3.fromRGB(255, 80, 80))
		return
	end
	local aim = getAimPoint()
	faceAim(aim)
	remote:FireServer(id, aim)
end

local actionToAbility = {}
for _, ability in ipairs(ABILITIES) do
	if ability.action then
		actionToAbility[ability.action] = ability
	end
end

local function onAction(actionName, state)
	if state == Enum.UserInputState.Begin then
		useAbility(actionToAbility[actionName].id)
	end
	return Enum.ContextActionResult.Sink
end

local function equip(tool)
	equippedTool = tool
	gui.Enabled = true
	activatedConnection = tool.Activated:Connect(function()
		useAbility("Slash")
	end)
	for _, ability in ipairs(ABILITIES) do
		if ability.action then
			ContextActionService:BindAction(ability.action, onAction, true, Config.Keys[ability.id])
			ContextActionService:SetTitle(ability.action, ability.name)
		end
	end
end

local function unequip()
	equippedTool = nil
	gui.Enabled = false
	if activatedConnection then
		activatedConnection:Disconnect()
		activatedConnection = nil
	end
	for _, ability in ipairs(ABILITIES) do
		if ability.action then
			ContextActionService:UnbindAction(ability.action)
		end
	end
end

local function onCharacter(character)
	if equippedTool then
		unequip()
	end
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == Config.ToolName then
			equip(child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child == equippedTool then
			unequip()
		end
	end)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

---------------------------------------------------------------------------
-- Камера: тряска, FOV, цвет
---------------------------------------------------------------------------

local function shake(amount)
	shakeAmount = math.max(shakeAmount, amount)
end

RunService:BindToRenderStep("KatanaShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shakeAmount <= 0.001 then
		shakeAmount = 0
		return
	end
	local a = math.rad(shakeAmount)
	camera.CFrame = camera.CFrame * CFrame.Angles((math.random() - 0.5) * a, (math.random() - 0.5) * a, (math.random() - 0.5) * a * 0.5)
	shakeAmount = shakeAmount * math.exp(-dt * 9)
end)

local baseFov = camera.FieldOfView
local function fovKick(amount, time)
	camera.FieldOfView = baseFov + amount
	TweenService:Create(camera, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = baseFov }):Play()
end

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "KatanaUltimateTint"
tint.Parent = Lighting

---------------------------------------------------------------------------
-- События сервера
---------------------------------------------------------------------------

remote.OnClientEvent:Connect(function(event, a, b)
	if event == "Cooldown" and typeof(a) == "string" and typeof(b) == "number" then
		readyAt[a] = os.clock() + b
		durations[a] = b
		flashSlot(a, Config.CoreColor)
	elseif event == "Slash" then
		shake(a == 3 and 1.6 or 0.6)
	elseif event == "Wave" then
		shake(1.2)
		fovKick(6, 0.3)
	elseif event == "Dash" then
		shake(1.5)
		fovKick(18, 0.45)
	elseif event == "Ultimate" and typeof(a) == "number" then
		fovKick(12, a)
		tint.TintColor = Config.Color:Lerp(Color3.new(1, 1, 1), 0.6)
		tint.Saturation = -0.4
		tint.Contrast = 0.25
		TweenService:Create(tint, TweenInfo.new(a + 0.4), { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 }):Play()
		task.spawn(function()
			local stop = os.clock() + a
			while os.clock() < stop do
				shake(1)
				task.wait(0.1)
			end
			shake(4)
		end)
	elseif event == "Knock" and typeof(a) == "Vector3" then
		local humanoid, root = getRoot()
		if root then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			root.AssemblyLinearVelocity = a
			shake(3)
		end
	end
end)

RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		return
	end
	local now = os.clock()
	for id, slot in pairs(slots) do
		local remaining = (readyAt[id] or 0) - now
		if remaining > 0 and durations[id] then
			slot.overlay.Size = UDim2.fromScale(1, remaining / durations[id])
			slot.timer.Text = remaining >= 1 and string.format("%d", math.ceil(remaining)) or ""
		else
			slot.overlay.Size = UDim2.fromScale(1, 0)
			slot.timer.Text = ""
		end
	end
end)
