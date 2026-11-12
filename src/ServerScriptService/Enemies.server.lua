-- Враги-ронины: преследуют ближайшего игрока, бьют вблизи, возрождаются. Плюс счёт убийств.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ENEMY_COUNT = 6
local SPAWN_RADIUS = 45
local MAX_HEALTH = 120
local WALK_SPEED = 13
local AGGRO_RANGE = 80
local ATTACK_RANGE = 5
local ATTACK_DAMAGE = 10
local ATTACK_COOLDOWN = 1.3
local RESPAWN_TIME = 4
local KILL_HEAL = 25

local rng = Random.new()

local function setupStats(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local kills = Instance.new("IntValue")
	kills.Name = "Убийства"
	kills.Parent = stats
	stats.Parent = player
end

Players.PlayerAdded:Connect(setupStats)
for _, player in ipairs(Players:GetPlayers()) do
	setupStats(player)
end

local function nearestPlayerRoot(position)
	local best, bestDistance = nil, AGGRO_RANGE
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = root, distance
			end
		end
	end
	return best, bestDistance
end

local function addHealthBar(model, humanoid)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 30)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 120, 120)
	label.TextStrokeTransparency = 0.3
	label.Text = model.Name
	label.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 18)
	back.Size = UDim2.new(1, 0, 0, 8)
	back.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
	back.BorderSizePixel = 0
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
	fill.BorderSizePixel = 0
	fill.Parent = back

	humanoid.HealthChanged:Connect(function(health)
		fill.Size = UDim2.fromScale(math.clamp(health / humanoid.MaxHealth, 0, 1), 1)
	end)
end

local function attack(targetRoot)
	local humanoid = targetRoot.Parent and targetRoot.Parent:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid:TakeDamage(ATTACK_DAMAGE)

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 0, 0)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.Parent = targetRoot.Parent
	TweenService:Create(highlight, TweenInfo.new(0.3), { FillTransparency = 1 }):Play()
	Debris:AddItem(highlight, 0.3)
end

local function runAI(humanoid, root, home)
	local lastAttack = 0
	local nextWander = 0
	while humanoid.Parent and humanoid.Health > 0 and root.Parent do
		local target, distance = nearestPlayerRoot(root.Position)
		if target then
			humanoid:MoveTo(target.Position)
			if distance <= ATTACK_RANGE and os.clock() - lastAttack >= ATTACK_COOLDOWN then
				lastAttack = os.clock()
				attack(target)
			end
		elseif os.clock() > nextWander then
			nextWander = os.clock() + rng:NextNumber(2, 4)
			humanoid:MoveTo(home + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)))
		end
		task.wait(0.2)
	end
end

local function creditKill(humanoid)
	local tag = humanoid:FindFirstChild("creator")
	local killer = tag and tag.Value
	if not (killer and killer:IsA("Player")) then
		return
	end
	local stats = killer:FindFirstChild("leaderstats")
	local kills = stats and stats:FindFirstChild("Убийства")
	if kills then
		kills.Value += 1
	end
	local killerHumanoid = killer.Character and killer.Character:FindFirstChildOfClass("Humanoid")
	if killerHumanoid and killerHumanoid.Health > 0 then
		killerHumanoid.Health = math.min(killerHumanoid.MaxHealth, killerHumanoid.Health + KILL_HEAL)
	end
end

local spawnEnemy

function spawnEnemy(home)
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(70, 60, 60)
	local cloth = Color3.fromRGB(120, 20, 25)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = cloth
	description.LeftLegColor = Color3.fromRGB(25, 25, 30)
	description.RightLegColor = Color3.fromRGB(25, 25, 30)

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Ронин"
	model:PivotTo(CFrame.new(home + Vector3.new(0, 4, 0)))

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health = MAX_HEALTH
	humanoid.WalkSpeed = WALK_SPEED
	addHealthBar(model, humanoid)
	model.Parent = workspace

	-- Сервер владеет физикой NPC, чтобы отбросы от катаны срабатывали.
	if root:CanSetNetworkOwnership() then
		root:SetNetworkOwner(nil)
	end

	humanoid.Died:Connect(function()
		creditKill(humanoid)
		task.wait(RESPAWN_TIME)
		model:Destroy()
		spawnEnemy(home)
	end)

	task.spawn(runAI, humanoid, root, home)
end

for i = 1, ENEMY_COUNT do
	local angle = (i / ENEMY_COUNT) * math.pi * 2
	local home = Vector3.new(math.cos(angle) * SPAWN_RADIUS, 0, math.sin(angle) * SPAWN_RADIUS)
	task.spawn(spawnEnemy, home)
end
