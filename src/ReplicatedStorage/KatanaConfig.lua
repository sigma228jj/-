-- Общие настройки катаны (сервер + клиент).
return {
	RemoteName = "KatanaRemote",
	EffectsFolderName = "KatanaEffects",
	ToolName = "Катана",

	Color = Color3.fromRGB(255, 60, 100), -- свечение лезвия и эффектов
	CoreColor = Color3.fromRGB(255, 220, 230),

	Keys = {
		Wave = Enum.KeyCode.Q,
		Dash = Enum.KeyCode.R,
		Ultimate = Enum.KeyCode.F,
	},

	-- ЛКМ: комбо из трёх ударов, третий — добивающий с отбросом
	Slash = {
		Cooldown = 0.35,
		ComboWindow = 0.9,
		Damage = { 14, 16, 28 },
		Range = 8,
		Width = 9,
		FinisherKnock = 45,
	},

	-- Q: летящая волна-полумесяц, пробивает всех на пути
	Wave = {
		Cooldown = 4,
		Damage = 30,
		Speed = 95,
		Range = 120,
		Width = 14,
		Height = 6,
	},

	-- R: рывок сквозь врагов с порезами
	Dash = {
		Cooldown = 5,
		Damage = 28,
		Distance = 34,
		Width = 7,
	},

	-- F: буря клинков — серия ударов вокруг + финальный взрыв
	Ultimate = {
		Cooldown = 18,
		Hits = 8,
		Interval = 0.12,
		Damage = 10,
		Radius = 16,
		FinalDamage = 40,
	},
}
