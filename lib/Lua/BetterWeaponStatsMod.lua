RegisterScript("lib/Lua/BetterWeaponStatsMod/blackmarketgui.lua", 2, "lib/managers/menu/blackmarketgui")
RegisterScript("lib/Lua/BetterWeaponStatsMod/IndexStatsToggle.lua", 0, "VK_F8")
RegisterScript("lib/Lua/BetterWeaponStatsMod/GreaterPrecisionToggle.lua", 0, "VK_F9")
if not GetBinding("VK_F8") then BindKey("VK_F8", "lib/Lua/BetterWeaponStatsMod/IndexStatsToggle.lua") end
if not GetBinding("VK_F9") then BindKey("VK_F9", "lib/Lua/BetterWeaponStatsMod/GreaterPrecisionToggle.lua") end