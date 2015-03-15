--Version 3.3
RegisterScript("lib/Lua/BetterWeaponStatsMod/blackmarketgui.lua", 2, "lib/managers/menu/blackmarketgui")
RegisterScript("lib/Lua/BetterWeaponStatsMod/toggle.lua", 0, "VK_F9")
if not GetBinding("VK_F9") then BindKey("VK_F9", "lib/Lua/BetterWeaponStatsMod/toggle.lua") end