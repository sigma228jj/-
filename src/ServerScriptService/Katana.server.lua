-- Катана из партов: сборка модели, экипировка, удары и способности (сервер).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("KatanaConfig"))

local remote = Instance.new("RemoteEvent")
remote.Name = Config.RemoteName
remote.Parent = ReplicatedStorage

local fx = Instance.new("Folder")
fx.Name = Config.EffectsFolderName
fx.Parent = workspace

local rng = Random.new()

local SOUNDS = {
	Slash = "rbxasset://sounds/swordslash.wav",
	Lunge = "rbxasset://sounds/swordlunge.wav",
	Unsheath = "rbxasset://sounds/unsheath.wav",
}

local DARK = Color3.fromRGB(22, 22, 28)
local GOLD = Color3.fromRGB(205, 165, 75)
local STEEL = Color3.fromRGB(210, 215, 225)

---------------------------------------------------------------------------
-- Общие утилиты
---------------------------------------------------------------------------

local function newPart(className, props)
	local part = Instance.new(className)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

local function fxPart(props)
	props.Anchored = true
	props.Material = props.Material or Enum.Material.Neon
	return newPart("Part", props)
end

local function playSound(id, parent, volume, speed)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = speed or 1
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 3)
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDirection(root, aim)
	local dir = flat(aim - root.Position)
	if dir.Magnitude < 1 then
		dir = flat(root.CFrame.LookVector)
	end
	if dir.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return dir.Unit
end

local function isValidVector(v)
	if typeof(v) ~= "Vector3" then
		return false
	end
	local m = v.Magnitude
	return m == m and m ~= math.huge
end

local function isCharacterPart(instance)
	local model = instance:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- Луч, который пролетает сквозь персонажей и упирается только в стены.
local function castThroughCharacters(origin, vector, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	for _ = 1, 8 do
		local result = workspace:Raycast(origin, vector, params)
		if not result then
			return nil
		end
		if isCharacterPart(result.Instance) then
			params:AddToFilter(result.Instance:FindFirstAncestorOfClass("Model"))
		else
			return result
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Модель катаны
---------------------------------------------------------------------------

-- Лезвие идёт вдоль -Z от рукояти; все детали приварены к рукояти (Tsuka).
local function buildKatana()
	local model = Instance.new("Model")
	model.Name = "KatanaModel"

	local handle = newPart("Part", {
		Name = "Tsuka",
		Size = Vector3.new(0.22, 0.28, 1.3),
		Color = DARK,
		Material = Enum.Material.Fabric,
		Massless = true,
	})
	handle.Parent = model
	model.PrimaryPart = handle

	local function attach(className, props, offset)
		props.Massless = true
		local part = newPart(className, props)
		part.CFrame = offset
		local weld = Instance.new("Weld")
		weld.Part0 = handle
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part
		part.Parent = model
		return part
	end

	-- Навершие и обмотка рукояти
	attach("Part", { Name = "Kashira", Size = Vector3.new(0.26, 0.32, 0.12), Color = GOLD, Material = Enum.Material.Metal }, CFrame.new(0, 0, 0.71))
	for _, z in ipairs({ -0.45, -0.15, 0.15, 0.45 }) do
		attach("Part", {
			Name = "Ito",
			Size = Vector3.new(0.235, 0.15, 0.15),
			Color = Config.Color:Lerp(DARK, 0.5),
			Material = Enum.Material.Fabric,
		}, CFrame.new(0, 0, z) * CFrame.Angles(math.rad(45), 0, 0))
	end

	-- Гарда и муфта
	attach("Part", {
		Name = "Tsuba",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, 0.75, 0.75),
		Color = DARK,
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
	}, CFrame.new(0, 0, -0.69) * CFrame.Angles(0, math.rad(90), 0))
	attach("Part", { Name = "Habaki", Size = Vector3.new(0.1, 0.3, 0.16), Color = GOLD, Material = Enum.Material.Metal }, CFrame.new(0, 0, -0.81))

	-- Изогнутое лезвие из трёх сегментов + светящаяся кромка
	local segmentLength = 1.25
	local cf = CFrame.new(0, 0, -0.89)
	for _ = 1, 3 do
		cf = cf * CFrame.Angles(math.rad(3), 0, 0)
		attach("Part", {
			Name = "Blade",
			Size = Vector3.new(0.06, 0.22, segmentLength + 0.04),
			Color = STEEL,
			Material = Enum.Material.Metal,
			Reflectance = 0.35,
		}, cf * CFrame.new(0, 0, -segmentLength / 2))
		attach("Part", {
			Name = "Edge",
			Size = Vector3.new(0.066, 0.045, segmentLength + 0.04),
			Color = Config.Color,
			Material = Enum.Material.Neon,
		}, cf * CFrame.new(0, -0.09, -segmentLength / 2))
		cf = cf * CFrame.new(0, 0, -segmentLength)
	end
	local tip = attach("WedgePart", {
		Name = "Kissaki",
		Size = Vector3.new(0.06, 0.22, 0.4),
		Color = STEEL,
		Material = Enum.Material.Metal,
		Reflectance = 0.35,
	}, cf * CFrame.new(0, 0, -0.2))

	local light = Instance.new("PointLight")
	light.Color = Config.Color
	light.Range = 6
	light.Brightness = 1.2
	light.Parent = tip

	local a0 = Instance.new("Attachment")
	a0.Name = "TrailBase"
	a0.Position = Vector3.new(0, 0, -1.1)
	a0.Parent = handle
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailTip"
	a1.Position = (cf * CFrame.new(0, 0, -0.4)).Position
	a1.Parent = handle

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Config.CoreColor, Config.Color)
	trail.LightEmission = 1
	trail.Lifetime = 0.2
	trail.MinLength = 0
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Enabled = false
	trail.Parent = handle

	return model, trail
end

-- Положения катаны относительно тела (в руке / на поясе), для R15 и R6.
local function holdOffset(isR15)
	local y = isR15 and -0.15 or -0.9
	return CFrame.new(0, y, 0) * CFrame.Angles(math.rad(15), 0, 0) * CFrame.new(0, 0, -0.2)
end

local function sheathOffset(isR15)
	local base = isR15 and CFrame.new(-1.05, 0.1, 0) or CFrame.new(-1.1, -0.8, 0)
	return base * CFrame.Angles(math.rad(210), 0, 0) * CFrame.new(0, 0, -0.6)
end

local katanas = {} -- [character] = { model, trail, mount, hand, hip, isR15 }

local function setHeld(kat, held)
	kat.mount.Part0 = held and kat.hand or kat.hip
	kat.mount.C0 = held and holdOffset(kat.isR15) or sheathOffset(kat.isR15)
end

local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local hand = character:WaitForChild(isR15 and "RightHand" or "Right Arm", 10)
	local hip = character:WaitForChild(isR15 and "LowerTorso" or "Torso", 10)
	if not hand or not hip then
		return
	end

	local model, trail = buildKatana()
	local mount = Instance.new("Weld")
	mount.Name = "KatanaMount"
	mount.Part1 = model.PrimaryPart
	mount.Parent = model.PrimaryPart

	local kat = { model = model, trail = trail, mount = mount, hand = hand, hip = hip, isR15 = isR15, trailToken = 0 }
	setHeld(kat, false)
	model.Parent = character
	katanas[character] = kat

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == Config.ToolName then
			setHeld(kat, true)
			playSound(SOUNDS.Unsheath, hand, 0.5)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child.Name == Config.ToolName then
			setHeld(kat, false)
		end
	end)
	character.Destroying:Connect(function()
		katanas[character] = nil
	end)
end

local function enableTrail(kat, duration)
	kat.trailToken += 1
	local token = kat.trailToken
	kat.trail.Enabled = true
	task.delay(duration, function()
		if kat.trailToken == token then
			kat.trail.Enabled = false
		end
	end)
end

-- Процедурная анимация: крутим плечевой сустав в пространстве торса (работает и для R15, и для R6).
local function getShoulder(character)
	local upper = character:FindFirstChild("RightUpperArm")
	if upper then
		return upper:FindFirstChild("RightShoulder")
	end
	local torso = character:FindFirstChild("Torso")
	return torso and torso:FindFirstChild("Right Shoulder")
end

local function swingArm(character, keyframes)
	local shoulder = getShoulder(character)
	if not shoulder then
		return
	end
	local base = shoulder:GetAttribute("KatanaBaseC0")
	if not base then
		base = shoulder.C0
		shoulder:SetAttribute("KatanaBaseC0", base)
	end
	local token = (shoulder:GetAttribute("KatanaSwing") or 0) + 1
	shoulder:SetAttribute("KatanaSwing", token)

	task.spawn(function()
		for _, frame in ipairs(keyframes) do
			if not shoulder.Parent or shoulder:GetAttribute("KatanaSwing") ~= token then
				return
			end
			local target = CFrame.new(base.Position) * frame[1] * base.Rotation
			TweenService:Create(shoulder, TweenInfo.new(frame[2], Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = target }):Play()
			task.wait(frame[2])
		end
	end)
end

local function deg(x, y, z)
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

---------------------------------------------------------------------------
-- Визуальные эффекты
---------------------------------------------------------------------------

-- Полумесяц из неоновых сегментов вокруг начала координат, дугой вперёд (-Z).
local function buildCrescent(radius, sweepDeg, thickness, segments)
	local model = Instance.new("Model")
	model.Name = "Crescent"
	local sweep = math.rad(sweepDeg)
	local step = sweep / segments
	local length = 2 * radius * math.sin(step / 2) + 0.2
	for i = 0, segments - 1 do
		local angle = -sweep / 2 + step * (i + 0.5)
		local taper = math.sin(((i + 0.5) / segments) * math.pi)
		local part = fxPart({
			Name = "Segment",
			Size = Vector3.new(math.max(thickness * taper, 0.08), 0.15, length),
			Color = i % 3 == 1 and Config.CoreColor or Config.Color,
			Transparency = 0.05,
			CFrame = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius) * CFrame.Angles(0, math.rad(90), 0),
		})
		part.Parent = model
	end
	model.WorldPivot = CFrame.new()
	return model
end

local function slashArc(cframe, radius, sweepDeg, thickness, duration, segments)
	local arc = buildCrescent(radius, sweepDeg, thickness, segments or 12)
	arc:PivotTo(cframe)
	arc.Parent = fx
	for _, part in ipairs(arc:GetChildren()) do
		local outward = part.Position - cframe.Position
		local push = outward.Magnitude > 0.01 and outward.Unit * radius * 0.3 or Vector3.zero
		TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			CFrame = part.CFrame + push,
		}):Play()
	end
	Debris:AddItem(arc, duration + 0.05)
end

local function impactBurst(position, size)
	local sphere = fxPart({
		Name = "Burst",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one,
		Color = Config.CoreColor,
		Transparency = 0.1,
		CFrame = CFrame.new(position),
	})
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Config.CoreColor, Config.Color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Speed = NumberRange.new(20, 40)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Drag = 4
	sparks.Rate = 0
	sparks.Parent = sphere
	sphere.Parent = fx
	sparks:Emit(30)
	TweenService:Create(sphere, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.one * size,
		Transparency = 1,
	}):Play()
	Debris:AddItem(sphere, 0.8)
end

local function shockRing(position, diameter)
	local ring = fxPart({
		Name = "Shockwave",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2, 2),
		Color = Config.Color,
		Transparency = 0.15,
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
	})
	ring.Parent = fx
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, diameter, diameter),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
end

-- Неоновый «призрак» персонажа на месте, откуда он рванул.
local function afterimage(character, offset)
	local ghost = Instance.new("Model")
	ghost.Name = "Afterimage"
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1
			and not part:FindFirstAncestor("KatanaModel") and not part:FindFirstAncestorOfClass("Accessory") then
			local copy = fxPart({
				Name = "Ghost",
				Size = part.Size,
				CFrame = part.CFrame + offset,
				Color = Config.Color,
				Transparency = 0.4,
			})
			copy.Parent = ghost
			TweenService:Create(copy, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end
	ghost.Parent = fx
	Debris:AddItem(ghost, 0.45)
end

local function damageNumber(position, amount, big)
	local anchor = fxPart({
		Name = "DamageNumber",
		Size = Vector3.new(0.1, 0.1, 0.1),
		Transparency = 1,
		CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))),
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(big and 120 or 80, big and 50 or 34)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = tostring(math.floor(amount + 0.5))
	label.TextColor3 = big and Config.Color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	anchor.Parent = fx
	TweenService:Create(anchor, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = anchor.CFrame + Vector3.new(0, 3.5, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(anchor, 0.85)
end

---------------------------------------------------------------------------
-- Урон
---------------------------------------------------------------------------

local function getAlive(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function isAlly(attacker, model)
	local victim = Players:GetPlayerFromCharacter(model)
	return victim ~= nil and not attacker.Neutral and not victim.Neutral and victim.Team == attacker.Team
end

local function flash(model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.OutlineColor = Config.Color
	highlight.FillTransparency = 0.2
	highlight.Parent = model
	TweenService:Create(highlight, TweenInfo.new(0.3), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(highlight, 0.3)
end

local function knock(model, humanoid, root, velocity)
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		-- Физикой персонажа владеет его клиент — отброс применяет он.
		remote:FireClient(victim, "Knock", velocity)
	else
		if root:CanSetNetworkOwnership() then
			root:SetNetworkOwner(nil)
		end
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = velocity
	end
end

local function dealDamage(attacker, model, damage, knockVelocity, big)
	local humanoid, root = getAlive(model)
	if not humanoid then
		return
	end
	local tag = Instance.new("ObjectValue")
	tag.Name = "creator"
	tag.Value = attacker
	tag.Parent = humanoid
	Debris:AddItem(tag, 2)

	humanoid:TakeDamage(damage)
	flash(model)
	damageNumber(root.Position + Vector3.new(0, 3, 0), damage, big)
	if knockVelocity then
		knock(model, humanoid, root, knockVelocity)
	end
end

local function overlapParams(character)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fx, character }
	return params
end

-- Вызывает callback один раз для каждого живого врага среди найденных деталей.
local function forEachTarget(attacker, parts, hitSet, callback)
	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model ~= attacker.Character and not hitSet[model] then
			local humanoid, root = getAlive(model)
			if humanoid and not isAlly(attacker, model) then
				hitSet[model] = true
				callback(model, root)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Состояние игрока и перезарядки
---------------------------------------------------------------------------

local states = {}

local function getState(player)
	local state = states[player]
	if not state then
		state = { ready = {}, combo = 0, lastSlash = 0, busyUntil = 0 }
		states[player] = state
	end
	return state
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

local function getContext(player)
	local character = player.Character
	if not character or not character:FindFirstChild(Config.ToolName) then
		return nil
	end
	local humanoid, root = getAlive(character)
	local kat = katanas[character]
	if not humanoid or not kat then
		return nil
	end
	return character, humanoid, root, kat
end

local function tryUse(player, ability, cooldown)
	local state = getState(player)
	local now = os.clock()
	if now < state.busyUntil or now < (state.ready[ability] or 0) then
		return false
	end
	state.ready[ability] = now + cooldown
	remote:FireClient(player, "Cooldown", ability, cooldown)
	return true
end

---------------------------------------------------------------------------
-- Способности
---------------------------------------------------------------------------

local COMBO = {
	{ windup = deg(120, 0, 35), strike = deg(35, 0, -45), roll = 25 },
	{ windup = deg(80, 0, -50), strike = deg(90, 0, 60), roll = -20 },
	{ windup = deg(170, 0, 0), strike = deg(30, 0, 0), roll = 80 },
}

local function doSlash(player)
	local character, _, root, kat = getContext(player)
	if not character or not tryUse(player, "Slash", Config.Slash.Cooldown) then
		return
	end

	local state = getState(player)
	local now = os.clock()
	if now - state.lastSlash > Config.Slash.ComboWindow or state.combo >= #COMBO then
		state.combo = 0
	end
	state.combo += 1
	state.lastSlash = now

	local index = state.combo
	local step = COMBO[index]
	local finisher = index == #COMBO

	swingArm(character, { { step.windup, 0.07 }, { step.strike, 0.1 }, { CFrame.identity, 0.2 } })
	enableTrail(kat, 0.3)
	playSound(SOUNDS.Slash, root, 0.6, finisher and 0.8 or rng:NextNumber(1, 1.15))
	remote:FireClient(player, "Slash", index)

	task.delay(0.08, function()
		if not root.Parent then
			return
		end
		local look = root.CFrame.LookVector
		slashArc(root.CFrame * CFrame.new(0, 0.5, 0) * deg(0, 0, step.roll), finisher and 7 or 5.5, finisher and 200 or 150, finisher and 1.4 or 1, 0.25)

		local range = Config.Slash.Range * (finisher and 1.3 or 1)
		local parts = workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(0, 0, -range / 2), Vector3.new(Config.Slash.Width, 7, range), overlapParams(character))
		forEachTarget(player, parts, {}, function(model)
			local push = finisher and (look * Config.Slash.FinisherKnock + Vector3.new(0, 25, 0)) or look * 8
			dealDamage(player, model, Config.Slash.Damage[index], push, finisher)
		end)
	end)
end

local function launchWave(player, character, origin, direction)
	local W = Config.Wave
	local radius = W.Width / 2
	local crescent = buildCrescent(radius, 150, 1.8, 16)
	local cf = CFrame.lookAt(origin, origin + direction) * deg(0, 0, 12)
	crescent:PivotTo(cf)

	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Config.CoreColor, Config.Color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.Speed = NumberRange.new(2, 6)
	sparks.Lifetime = NumberRange.new(0.2, 0.4)
	sparks.Rate = 80
	sparks.Parent = crescent:GetChildren()[8]
	crescent.Parent = fx

	local traveled = 0
	local hitSet = {}
	local params = overlapParams(character)
	local finished = false
	local connection

	local function finish(impactPosition)
		if finished then
			return
		end
		finished = true
		connection:Disconnect()
		if impactPosition then
			impactBurst(impactPosition, 8)
		end
		sparks.Enabled = false
		for _, part in ipairs(crescent:GetChildren()) do
			TweenService:Create(part, TweenInfo.new(0.2), { Transparency = 1 }):Play()
		end
		Debris:AddItem(crescent, 0.5)
	end

	connection = RunService.Heartbeat:Connect(function(dt)
		local distance = W.Speed * dt
		local front = (cf * CFrame.new(0, 0, -radius)).Position
		local wall = castThroughCharacters(front, direction * distance, { fx, character })
		if wall then
			finish(wall.Position)
			return
		end

		cf = cf + direction * distance
		traveled += distance
		crescent:PivotTo(cf)

		local parts = workspace:GetPartBoundsInBox(cf * CFrame.new(0, 0, -radius * 0.6), Vector3.new(W.Width, W.Height, radius * 1.2), params)
		forEachTarget(player, parts, hitSet, function(model, targetRoot)
			impactBurst(targetRoot.Position, 5)
			dealDamage(player, model, W.Damage, direction * 35 + Vector3.new(0, 22, 0), true)
		end)

		if traveled >= W.Range then
			finish(nil)
		end
	end)
end

local function doWave(player, aim)
	local character, _, root, kat = getContext(player)
	if not character or not tryUse(player, "Wave", Config.Wave.Cooldown) then
		return
	end
	local direction = flatDirection(root, aim)
	swingArm(character, { { deg(90, 0, -70), 0.08 }, { deg(90, 0, 70), 0.1 }, { CFrame.identity, 0.25 } })
	enableTrail(kat, 0.3)
	playSound(SOUNDS.Lunge, root, 0.7, 1.1)
	remote:FireClient(player, "Wave")
	task.delay(0.1, function()
		if root.Parent then
			launchWave(player, character, root.Position + Vector3.new(0, 0.5, 0), direction)
		end
	end)
end

local function doDash(player, aim)
	local character, _, root, kat = getContext(player)
	if not character or not tryUse(player, "Dash", Config.Dash.Cooldown) then
		return
	end
	local D = Config.Dash
	local state = getState(player)
	state.busyUntil = os.clock() + 0.25

	local direction = flatDirection(root, aim)
	local start = root.Position
	local wall = castThroughCharacters(start, direction * D.Distance, { fx, character })
	local distance = wall and math.max(0, (wall.Position - start).Magnitude - 2.5) or D.Distance
	local finish = start + direction * distance

	for i = 0, 3 do
		afterimage(character, direction * distance * (i / 4))
	end

	if distance > 0.5 then
		local line = fxPart({
			Name = "DashLine",
			Size = Vector3.new(0.35, 0.35, distance),
			Color = Config.CoreColor,
			CFrame = CFrame.lookAt((start + finish) / 2, finish),
		})
		line.Parent = fx
		TweenService:Create(line, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(0.05, 0.05, distance) }):Play()
		Debris:AddItem(line, 0.45)
	end

	character:PivotTo(CFrame.lookAt(finish, finish + direction))
	swingArm(character, { { deg(30, 0, -60), 0.05 }, { deg(100, 0, 60), 0.12 }, { CFrame.identity, 0.25 } })
	enableTrail(kat, 0.35)
	playSound(SOUNDS.Lunge, root, 0.8, 0.9)
	remote:FireClient(player, "Dash")

	if distance <= 0.5 then
		return
	end
	local parts = workspace:GetPartBoundsInBox(CFrame.lookAt((start + finish) / 2, finish), Vector3.new(D.Width, 7, distance + 4), overlapParams(character))
	local victims = {}
	forEachTarget(player, parts, {}, function(model, targetRoot)
		table.insert(victims, { model = model, root = targetRoot })
	end)

	-- Удар «догоняет» жертв чуть позже — эффект мгновенного пореза.
	task.delay(0.18, function()
		for _, victim in ipairs(victims) do
			if victim.root.Parent then
				slashArc(CFrame.new(victim.root.Position) * deg(0, rng:NextNumber(0, 360), rng:NextNumber(-60, 60)), 3.5, 160, 0.8, 0.25)
				dealDamage(player, victim.model, D.Damage, direction * 15 + Vector3.new(0, 30, 0), true)
			end
		end
		if #victims > 0 then
			playSound(SOUNDS.Slash, root, 0.8, 0.7)
		end
	end)
end

local function doUltimate(player)
	local character, humanoid, root, kat = getContext(player)
	if not character or not tryUse(player, "Ultimate", Config.Ultimate.Cooldown) then
		return
	end
	local U = Config.Ultimate
	local duration = U.Hits * U.Interval + 0.4
	getState(player).busyUntil = os.clock() + duration

	root.Anchored = true
	remote:FireClient(player, "Ultimate", duration)
	playSound(SOUNDS.Unsheath, root, 0.9, 0.8)

	task.spawn(function()
		local ok, err = pcall(function()
			local params = overlapParams(character)
			for _ = 1, U.Hits do
				if not root.Parent or humanoid.Health <= 0 then
					return
				end
				local center = root.Position
				slashArc(
					CFrame.new(center) * deg(0, rng:NextNumber(0, 360), rng:NextNumber(-70, 70)),
					rng:NextNumber(U.Radius * 0.5, U.Radius * 0.9),
					220,
					1.2,
					0.3
				)
				swingArm(character, { { deg(rng:NextNumber(60, 170), 0, rng:NextNumber(-60, 60)), 0.05 }, { deg(rng:NextNumber(20, 90), 0, rng:NextNumber(-60, 60)), 0.06 } })
				enableTrail(kat, 0.2)
				playSound(SOUNDS.Slash, root, 0.5, rng:NextNumber(0.9, 1.3))
				forEachTarget(player, workspace:GetPartBoundsInRadius(center, U.Radius, params), {}, function(model)
					dealDamage(player, model, U.Damage, Vector3.new(0, 8, 0), false)
				end)
				task.wait(U.Interval)
			end

			local center = root.Position
			slashArc(CFrame.new(center), U.Radius, 360, 2.5, 0.5, 28)
			shockRing(center - Vector3.new(0, 2.5, 0), U.Radius * 2.6)
			impactBurst(center, 10)
			swingArm(character, { { deg(90, 0, -80), 0.05 }, { deg(90, 0, 80), 0.12 }, { CFrame.identity, 0.25 } })
			playSound(SOUNDS.Lunge, root, 1, 0.6)
			forEachTarget(player, workspace:GetPartBoundsInRadius(center, U.Radius * 1.1, params), {}, function(model, targetRoot)
				local away = flat(targetRoot.Position - center)
				away = away.Magnitude > 0.1 and away.Unit or Vector3.zero
				dealDamage(player, model, U.FinalDamage, away * 60 + Vector3.new(0, 40, 0), true)
			end)
		end)
		if root.Parent then
			root.Anchored = false
		end
		if not ok then
			warn("Katana ultimate error:", err)
		end
	end)
end

remote.OnServerEvent:Connect(function(player, action, aim)
	if action == "Slash" then
		doSlash(player)
	elseif not isValidVector(aim) then
		return
	elseif action == "Wave" then
		doWave(player, aim)
	elseif action == "Dash" then
		doDash(player, aim)
	elseif action == "Ultimate" then
		doUltimate(player)
	end
end)

---------------------------------------------------------------------------
-- Выдача инструмента
---------------------------------------------------------------------------

local tool = Instance.new("Tool")
tool.Name = Config.ToolName
tool.RequiresHandle = false -- модель вешаем на руку сами, чтобы не зависеть от Grip
tool.CanBeDropped = false
tool.ToolTip = "ЛКМ — удар, Q — волна, R — рывок, F — буря клинков"
tool.Parent = StarterPack

local function onPlayer(player)
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		task.spawn(setupCharacter, player.Character)
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack and not backpack:FindFirstChild(Config.ToolName) then
			tool:Clone().Parent = backpack
		end
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
