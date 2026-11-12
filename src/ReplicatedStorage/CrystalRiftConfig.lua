-- Общие настройки способности «Кристальный разлом» (сервер + клиент).
local Config = {
	RemoteName = "CrystalRiftRemote",
	EffectsFolderName = "CrystalRiftEffects",

	-- Управление: зажать — прицел, отпустить — каст
	Key = Enum.KeyCode.E,
	GamepadKey = Enum.KeyCode.ButtonY,

	Cooldown = 6,
	MinRange = 12,
	MaxRange = 70,

	-- Волна шипов
	StartOffset = 4, -- первый шип на таком расстоянии от игрока
	SpikeSpacing = 3.5,
	SpikeDelay = 0.045,
	SpikeWidth = 2.2,
	SpikeHeightMin = 4,
	SpikeHeightMax = 10, -- шипы растут по мере удаления от игрока
	SpikeLean = 0.35, -- наклон шипов по направлению волны
	SpikeJitter = 0.25,
	RiseTime = 0.22,
	MaxStepHeight = 6, -- перепад выше — волна упирается в препятствие

	-- Урон по пути
	HitRadius = 5,
	Damage = 20,
	KnockUp = 45,
	KnockBack = 18,
	SlowMultiplier = 0.45,
	SlowDuration = 1.6,
	FriendlyFire = false,

	-- Финальный взрыв
	FinaleSpikes = 7,
	FinaleRadius = 12,
	FinaleDamage = 30,
	FinaleCenterHeight = 16,

	-- Разрушение
	Lifetime = 2.2,
	ShardsPerSpike = 5,
	ShardLifetime = 1.6,

	GroundProbeUp = 15,
	GroundProbeDown = 40,

	Color = Color3.fromRGB(110, 205, 255),
	CoreColor = Color3.fromRGB(220, 250, 255),
}

return Config
