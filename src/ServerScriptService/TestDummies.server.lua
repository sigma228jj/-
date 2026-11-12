-- Тестовые манекены для проверки способности; возрождаются после смерти.
local Players = game:GetService("Players")

local POSITIONS = {
	Vector3.new(0, 5, -30),
	Vector3.new(-12, 5, -40),
	Vector3.new(12, 5, -40),
}

local function spawnDummy(position)
	local dummy = Players:CreateHumanoidModelFromDescription(HumanoidDescription.new(), Enum.HumanoidRigType.R15)
	dummy.Name = "Манекен"
	dummy:PivotTo(CFrame.new(position))
	dummy.Parent = workspace

	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	humanoid.MaxHealth = 150
	humanoid.Health = 150
	humanoid.Died:Connect(function()
		task.wait(3)
		dummy:Destroy()
		spawnDummy(position)
	end)
end

for _, position in ipairs(POSITIONS) do
	spawnDummy(position)
end
