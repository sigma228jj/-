-- Серверная часть «Кристального разлома»: проверка каста, генерация шипов, урон, разрушение.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("CrystalRiftConfig"))

local remote = Instance.new("RemoteEvent")
remote.Name = Config.RemoteName
remote.Parent = ReplicatedStorage

local effects = Instance.new("Folder")
effects.Name = Config.EffectsFolderName
effects.Parent = workspace

local rng = Random.new()
local lastCast = {}

Players.PlayerRemoving:Connect(function(player)
	lastCast[player] = nil
end)

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function getAlive(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
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

-- Луч вниз; персонажей (и NPC) пропускаем, чтобы шип не вырос у кого-то на голове.
local function findGround(position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { effects }
	params.IgnoreWater = false

	local origin = position + Vector3.new(0, Config.GroundProbeUp, 0)
	local direction = Vector3.new(0, -(Config.GroundProbeUp + Config.GroundProbeDown), 0)
	for _ = 1, 5 do
		local result = workspace:Raycast(origin, direction, params)
		if not result then
			return nil
		end
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			params:AddToFilter(model)
		else
			return result.Position, result.Normal, result.Instance
		end
	end
	return nil
end

-- Есть ли стена между двумя точками земли.
local function isBlocked(fromPos, toPos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { effects }
	local lift = Vector3.new(0, 2, 0)
	local offset = (toPos + lift) - (fromPos + lift)
	local result = workspace:Raycast(fromPos + lift, offset, params)
	if not result then
		return false
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	return not (model and model:FindFirstChildOfClass("Humanoid"))
end

local function alignToUp(position, up)
	local axis = Vector3.yAxis:Cross(up)
	if axis.Magnitude < 1e-4 then
		return CFrame.new(position)
	end
	local angle = math.acos(math.clamp(Vector3.yAxis:Dot(up), -1, 1))
	return CFrame.new(position) * CFrame.fromAxisAngle(axis.Unit, angle)
end

local function spawnRubble(position, groundPart, width)
	local material, color = Enum.Material.Rock, Color3.fromRGB(105, 100, 95)
	if groundPart and groundPart:IsA("BasePart") and not groundPart:IsA("Terrain") then
		material, color = groundPart.Material, groundPart.Color
	end
	for i = 1, 3 do
		local angle = (i / 3) * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
		local radius = width * rng:NextNumber(0.7, 1.1)
		local s = rng:NextNumber(0.8, 1.5)
		local rock = makePart({
			Name = "Rubble",
			Size = Vector3.new(s, s, s),
			Material = material,
			Color = color,
			CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * radius, s * 0.2, math.sin(angle) * radius))
				* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28)),
		})
		rock.Parent = effects
		task.delay(Config.Lifetime, function()
			if rock.Parent then
				TweenService:Create(rock, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(rock, Config.Lifetime + 0.6)
	end
end

-- Шип = стеклянная оболочка + неоновое ядро + ромбовидный кончик; поднимается из-под земли.
local function createSpike(position, up, height, width, groundPart)
	local base = alignToUp(position, up) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)

	local model = Instance.new("Model")
	model.Name = "CrystalSpike"

	local shell = makePart({
		Name = "Shell",
		Size = Vector3.new(width, height, width),
		Material = Enum.Material.Glass,
		Color = Config.Color,
		Transparency = 0.25,
		Reflectance = 0.15,
		CFrame = CFrame.Angles(0, math.rad(45), 0),
	})
	shell.Parent = model

	local core = makePart({
		Name = "Core",
		Size = Vector3.new(width * 0.4, height * 0.85, width * 0.4),
		Material = Enum.Material.Neon,
		Color = Config.CoreColor,
		CFrame = CFrame.new(),
	})
	core.Parent = model

	local tipSize = width * 0.72
	local tip = makePart({
		Name = "Tip",
		Size = Vector3.new(tipSize, tipSize, tipSize),
		Material = Enum.Material.Glass,
		Color = Config.Color,
		Transparency = 0.2,
		CFrame = CFrame.new(0, height / 2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
	})
	tip.Parent = model

	local light = Instance.new("PointLight")
	light.Color = Config.Color
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = core

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(Config.CoreColor, Config.Color)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Speed = NumberRange.new(6, 14)
	sparkles.SpreadAngle = Vector2.new(60, 60)
	sparkles.Lifetime = NumberRange.new(0.3, 0.6)
	sparkles.Rate = 0
	sparkles.Parent = tip

	model.PrimaryPart = shell

	local finalCF = base * CFrame.new(0, height / 2 - 0.6, 0)
	local startCF = base * CFrame.new(0, -height / 2 - 0.5, 0)
	model:PivotTo(startCF)
	model.Parent = effects

	-- TweenService не умеет двигать модели, поэтому твиним CFrameValue и двигаем по нему.
	local driver = Instance.new("CFrameValue")
	driver.Value = startCF
	driver.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local tween = TweenService:Create(
		driver,
		TweenInfo.new(Config.RiseTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = finalCF }
	)
	tween.Completed:Connect(function()
		driver:Destroy()
	end)
	tween:Play()

	sparkles:Emit(12)
	spawnRubble(position, groundPart, width)
	return model
end

local function shatter(model)
	local shell = model.PrimaryPart
	if not shell then
		model:Destroy()
		return
	end
	local pivot = shell.CFrame
	local size = shell.Size
	for _ = 1, Config.ShardsPerSpike do
		local shard = Instance.new("Part")
		shard.Name = "Shard"
		shard.Size = Vector3.new(rng:NextNumber(0.3, 0.8), rng:NextNumber(0.6, 1.4), rng:NextNumber(0.3, 0.8))
		shard.CFrame = pivot
			* CFrame.new(
				rng:NextNumber(-size.X / 2, size.X / 2),
				rng:NextNumber(-size.Y / 2, size.Y / 2),
				rng:NextNumber(-size.Z / 2, size.Z / 2)
			)
			* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
		shard.Material = Enum.Material.Glass
		shard.Color = Config.Color
		shard.Transparency = 0.2
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CastShadow = false
		shard.Parent = effects

		local outward = shard.Position - pivot.Position
		outward = Vector3.new(outward.X, 0, outward.Z)
		if outward.Magnitude < 0.1 then
			outward = Vector3.xAxis
		end
		shard.AssemblyLinearVelocity = outward.Unit * rng:NextNumber(10, 22) + Vector3.new(0, rng:NextNumber(15, 30), 0)
		shard.AssemblyAngularVelocity = rng:NextUnitVector() * 12

		TweenService:Create(shard, TweenInfo.new(Config.ShardLifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
		}):Play()
		Debris:AddItem(shard, Config.ShardLifetime)
	end
	model:Destroy()
end

local function applySlow(humanoid)
	local token = (humanoid:GetAttribute("CrystalSlowToken") or 0) + 1
	humanoid:SetAttribute("CrystalSlowToken", token)
	if humanoid:GetAttribute("CrystalBaseSpeed") == nil then
		humanoid:SetAttribute("CrystalBaseSpeed", humanoid.WalkSpeed)
	end
	humanoid.WalkSpeed = humanoid:GetAttribute("CrystalBaseSpeed") * Config.SlowMultiplier

	-- Токен: повторное замедление продлевает эффект, а не восстанавливает скорость раньше времени.
	task.delay(Config.SlowDuration, function()
		if humanoid.Parent and humanoid:GetAttribute("CrystalSlowToken") == token then
			humanoid.WalkSpeed = humanoid:GetAttribute("CrystalBaseSpeed")
			humanoid:SetAttribute("CrystalBaseSpeed", nil)
		end
	end)
end

local function flash(model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Config.Color
	highlight.OutlineColor = Config.CoreColor
	highlight.FillTransparency = 0.3
	highlight.Parent = model
	TweenService:Create(highlight, TweenInfo.new(0.5), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(highlight, 0.5)
end

local function knock(model, humanoid, root, velocity)
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		-- Персонажем игрока физически владеет его клиент, поэтому импульс применяет клиент.
		remote:FireClient(victim, "Knock", velocity)
	else
		if root:CanSetNetworkOwnership() then
			root:SetNetworkOwner(nil)
		end
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = velocity
	end
end

local function isAlly(caster, model)
	if Config.FriendlyFire then
		return false
	end
	local victim = Players:GetPlayerFromCharacter(model)
	return victim ~= nil and not caster.Neutral and not victim.Neutral and victim.Team == caster.Team
end

local function damageArea(caster, center, radius, damage, hitSet, pushDirection)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { effects, caster.Character }

	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius, params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not hitSet[model] then
			local humanoid, root = getAlive(model)
			if humanoid and not isAlly(caster, model) then
				hitSet[model] = true

				local tag = Instance.new("ObjectValue")
				tag.Name = "creator"
				tag.Value = caster
				tag.Parent = humanoid
				Debris:AddItem(tag, 2)

				humanoid:TakeDamage(damage)
				applySlow(humanoid)
				flash(model)

				local push = pushDirection
				if not push then
					local away = root.Position - center
					away = Vector3.new(away.X, 0, away.Z)
					push = away.Magnitude > 0.1 and away.Unit or Vector3.zero
				end
				knock(model, humanoid, root, push * Config.KnockBack + Vector3.new(0, Config.KnockUp, 0))
			end
		end
	end
end

local function shockwave(position)
	local ring = makePart({
		Name = "Shockwave",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2, 2),
		Material = Enum.Material.Neon,
		Color = Config.CoreColor,
		Transparency = 0.2,
		CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	ring.Parent = effects
	local diameter = Config.FinaleRadius * 2.4
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, diameter, diameter),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
end

local function finale(caster, center, normal, spawned)
	shockwave(center)
	table.insert(spawned, createSpike(center, normal, Config.FinaleCenterHeight, Config.SpikeWidth * 2, nil))

	for i = 1, Config.FinaleSpikes do
		local angle = (i / Config.FinaleSpikes) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local pos, groundNormal, groundPart = findGround(center + outward * rng:NextNumber(3.5, 5.5))
		if pos then
			local up = (groundNormal + outward * 0.8).Unit
			local height = rng:NextNumber(Config.SpikeHeightMax * 0.8, Config.SpikeHeightMax * 1.2)
			table.insert(spawned, createSpike(pos, up, height, Config.SpikeWidth * 1.3, groundPart))
		end
	end

	damageArea(caster, center + Vector3.new(0, 2, 0), Config.FinaleRadius, Config.FinaleDamage, {}, nil)
end

local function runRift(caster, origin, direction, distance)
	local hitSet = {}
	local spawned = {}
	local steps = math.max(1, math.floor((distance - Config.StartOffset) / Config.SpikeSpacing) + 1)
	local lastGround, lastNormal = nil, nil
	local previousPoint = origin

	for i = 1, steps do
		local flat = origin + direction * (Config.StartOffset + (i - 1) * Config.SpikeSpacing)
		local probe = Vector3.new(flat.X, lastGround and lastGround.Y or origin.Y, flat.Z)
		local pos, normal, groundPart = findGround(probe)

		-- Волна обрывается над пропастью, на резком перепаде или упираясь в стену.
		if not pos then
			break
		end
		if lastGround and math.abs(pos.Y - lastGround.Y) > Config.MaxStepHeight then
			break
		end
		if isBlocked(previousPoint, pos) then
			break
		end

		local progress = steps > 1 and (i - 1) / (steps - 1) or 1
		local height = lerp(Config.SpikeHeightMin, Config.SpikeHeightMax, progress) + rng:NextNumber(-1, 1)
		local jitter = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * Config.SpikeJitter
		local up = (normal + direction * Config.SpikeLean + jitter).Unit
		table.insert(spawned, createSpike(pos, up, height, Config.SpikeWidth, groundPart))

		damageArea(caster, pos + Vector3.new(0, 2, 0), Config.HitRadius, Config.Damage, hitSet, direction)

		lastGround, lastNormal = pos, normal
		previousPoint = pos
		task.wait(Config.SpikeDelay)
	end

	if lastGround then
		finale(caster, lastGround, lastNormal, spawned)
	end

	task.wait(Config.Lifetime)
	for index, spike in ipairs(spawned) do
		if spike.Parent then
			shatter(spike)
		end
		-- Шипы рассыпаются волной, в том же порядке, в каком выросли.
		if index % 2 == 0 then
			task.wait(0.03)
		end
	end
end

remote.OnServerEvent:Connect(function(player, action, target)
	if action ~= "Cast" or typeof(target) ~= "Vector3" then
		return
	end
	local magnitude = target.Magnitude
	if magnitude ~= magnitude or magnitude == math.huge then
		return -- NaN / inf от клиента
	end

	local character = player.Character
	if not character then
		return
	end
	local humanoid, root = getAlive(character)
	if not humanoid then
		return
	end

	local now = os.clock()
	local last = lastCast[player]
	if last and now - last < Config.Cooldown then
		remote:FireClient(player, "Cooldown", Config.Cooldown - (now - last))
		return
	end

	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	if flat.Magnitude < 1 then
		local look = root.CFrame.LookVector
		flat = Vector3.new(look.X, 0, look.Z)
	end
	if flat.Magnitude < 1e-3 then
		return
	end

	lastCast[player] = now
	remote:FireClient(player, "Cast", Config.Cooldown)

	local distance = math.clamp(flat.Magnitude, Config.MinRange, Config.MaxRange)
	task.spawn(runRift, player, root.Position, flat.Unit, distance)
end)
