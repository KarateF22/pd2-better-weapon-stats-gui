toggle_greater_precision = true

local _blackmarketgui_function_ptr1 = BlackMarketGui.mouse_moved
local _blackmarketgui_function_ptr2 = BlackMarketGui._get_base_stats
local _blackmarketgui_function_ptr3 = BlackMarketGui._get_skill_stats
local _blackmarketgui_function_ptr4 = BlackMarketGui._get_mods_stats
local _blackmarketgui_function_ptr5 = BlackMarketGui.show_stats
local _blackmarketgui_function_ptr6 = BlackMarketGui._get_stats
local _blackmarketgui_function_ptr7 = BlackMarketGui._get_weapon_mod_stats
local _blackmarketgui_function_ptr8 = BlackMarketGui._pre_reload
local _blackmarketgui_function_ptr9 = BlackMarketGui.update_info_text



function BlackMarketGui:_get_base_stats(name)
	if not toggle_greater_precision then return _blackmarketgui_function_ptr2(self, name) end
	
	local base_stats = {}
	local index
	local tweak_stats = tweak_data.weapon.stats
	local modifier_stats = tweak_data.weapon[name].stats_modifiers
	for _, stat in pairs(self._stats_shown) do
		base_stats[stat.name] = {}
		if stat.name == "magazine" then
			base_stats[stat.name].index = 0
			base_stats[stat.name].value = tweak_data.weapon[name].CLIP_AMMO_MAX
		elseif stat.name == "totalammo" then
			index = math.clamp(tweak_data.weapon[name].stats.total_ammo_mod, 1, #tweak_stats.total_ammo_mod)
			base_stats[stat.name].index = tweak_data.weapon[name].stats.total_ammo_mod
			base_stats[stat.name].value = tweak_data.weapon[name].AMMO_MAX
		elseif stat.name == "fire_rate" then
			local fire_rate = 60 / tweak_data.weapon[name].fire_mode_data.fire_rate
			base_stats[stat.name].value = fire_rate
		elseif tweak_stats[stat.name] then
			index = math.clamp(tweak_data.weapon[name].stats[stat.name], 1, #tweak_stats[stat.name])
			base_stats[stat.name].index = tweak_data.weapon[name].stats[stat.name]
			base_stats[stat.name].value = stat.index and index or tweak_stats[stat.name][index] * tweak_data.gui.stats_present_multiplier
			local offset = math.min(tweak_stats[stat.name][1], tweak_stats[stat.name][#tweak_stats[stat.name]]) * tweak_data.gui.stats_present_multiplier
			if stat.offset then base_stats[stat.name].value = base_stats[stat.name].value - offset end
			if stat.revert then
				local max_stat = math.max(tweak_stats[stat.name][1], tweak_stats[stat.name][#tweak_stats[stat.name]]) * tweak_data.gui.stats_present_multiplier
				if stat.revert then max_stat = max_stat - offset end
				base_stats[stat.name].value = max_stat - base_stats[stat.name].value
			end
			if modifier_stats and modifier_stats[stat.name] and stat.name == "damage" then
				local mod = modifier_stats[stat.name]
				if stat.revert and not stat.index then
					local real_base_value = tweak_stats[stat.name][index]
					local modded_value = real_base_value * mod
					local offset = math.min(tweak_stats[stat.name][1], tweak_stats[stat.name][#tweak_stats[stat.name]])
					if stat.offset then modded_value = modded_value - offset end
					local max_stat = math.max(tweak_stats[stat.name][1], tweak_stats[stat.name][#tweak_stats[stat.name]])
					if stat.revert then max_stat = max_stat - offset end
					local new_value = (max_stat - modded_value) * tweak_data.gui.stats_present_multiplier
					if mod ~= 0 and (modded_value > tweak_stats[stat.name][1] or modded_value < tweak_stats[stat.name][#tweak_stats[stat.name]]) then
						new_value = (new_value + base_stats[stat.name].value / mod) / 2
					end
					base_stats[stat.name].value = new_value
				else
					base_stats[stat.name].value = base_stats[stat.name].value * mod
				end
			end
		end
	end
	return base_stats
end



function BlackMarketGui:_get_skill_stats(name, category, slot, base_stats, mods_stats, silencer, single_mod, auto_mod)
	if not toggle_greater_precision then return _blackmarketgui_function_ptr3(self, name, category, slot, base_stats, mods_stats, silencer, single_mod, auto_mod) end

	local skill_stats = {}
	for _, stat in pairs(self._stats_shown) do
		skill_stats[stat.name] = {}
		skill_stats[stat.name].value = 0
	end
	local custom_data = {}
	custom_data[category] = managers.blackmarket:get_crafted_category_slot(category, slot)
	local detection_risk = managers.blackmarket:get_suspicion_offset_from_custom_data(custom_data, tweak_data.player.SUSPICION_OFFSET_LERP or 0.75)
	detection_risk = math.round(detection_risk * 100)
	local base_value, modifier, multiplier
	local weapon_tweak = tweak_data.weapon[name]
	for _, stat in pairs(self._stats_shown) do
		if weapon_tweak.stats[stat.stat_name or stat.name] or stat.name == "totalammo" or stat.name == "fire_rate" then
			if stat.name == "magazine" then
				skill_stats[stat.name].value = managers.player:upgrade_value(name, "clip_ammo_increase", 0)
				if not weapon_tweak.upgrade_blocks or not weapon_tweak.upgrade_blocks.weapon or not table.contains(weapon_tweak.upgrade_blocks.weapon, "clip_ammo_increase") then
					skill_stats[stat.name].value = skill_stats[stat.name].value + managers.player:upgrade_value("weapon", "clip_ammo_increase", 0)
				end
				if not weapon_tweak.upgrade_blocks or not weapon_tweak.upgrade_blocks[weapon_tweak.category] or not table.contains(weapon_tweak.upgrade_blocks[weapon_tweak.category], "clip_ammo_increase") then
					skill_stats[stat.name].value = skill_stats[stat.name].value + managers.player:upgrade_value(weapon_tweak.category, "clip_ammo_increase", 0)
				end
				skill_stats[stat.name].skill_in_effect = managers.player:has_category_upgrade(name, "clip_ammo_increase") or managers.player:has_category_upgrade("weapon", "clip_ammo_increase")
			elseif stat.name == "totalammo" then
			else
				base_value = math.max(base_stats[stat.name].value + mods_stats[stat.name].value, 0)
				multiplier = 1
				modifier = 0
				local crafted_weapon = managers.blackmarket:get_crafted_category_slot(category, slot)
				local blueprint = crafted_weapon and crafted_weapon.blueprint
				if stat.name == "damage" then
					multiplier = managers.blackmarket:damage_multiplier(name, weapon_tweak.category, silencer, detection_risk, nil, blueprint)
					modifier = managers.blackmarket:damage_addend(name, weapon_tweak.category, silencer, detection_risk, nil, blueprint) * tweak_data.gui.stats_present_multiplier * multiplier
				elseif stat.name == "spread" then
					local fire_mode = single_mod and "single" or auto_mod and "auto" or weapon_tweak.FIRE_MODE or "single"
					multiplier = managers.blackmarket:accuracy_multiplier(name, weapon_tweak.category, silencer, nil, fire_mode, blueprint)
				elseif stat.name == "recoil" then
					multiplier = managers.blackmarket:recoil_multiplier(name, weapon_tweak.category, silencer, blueprint)
					--modifier = -managers.blackmarket:recoil_addend(name, weapon_tweak.category, silencer, blueprint) * tweak_data.gui.stats_present_multiplier
					modifier = 0 --recoil_addend currently always returns 0 anyways, so this prevents future breakage
				elseif stat.name == "suppression" then
					multiplier = managers.blackmarket:threat_multiplier(name, weapon_tweak.category, silencer)
				elseif stat.name == "concealment" then
				elseif stat.name == "fire_rate" then
					multiplier = managers.blackmarket:fire_rate_multiplier(name, weapon_tweak.category, silencer, detection_risk, nil, blueprint)
				end
				
				if stat.revert then multiplier = 1 / math.max(multiplier, 0.01) end
				
				skill_stats[stat.name].skill_in_effect = multiplier ~= 1 or modifier ~= 0
				if stat.name == "spread" then
					skill_stats[stat.name].value = multiplier - 1
				elseif stat.name == "recoil" then
					skill_stats[stat.name].value = 30 - (((30 - base_value) / 10) / multiplier) * 10 - base_value			
				else
					skill_stats[stat.name].value = modifier + base_value * multiplier - base_value
				end
			end
		end
	end
	return skill_stats
end



function BlackMarketGui:_get_mods_stats(name, base_stats, equipped_mods)
	if not toggle_greater_precision then return _blackmarketgui_function_ptr4(self, name, base_stats, equipped_mods) end

	local mods_stats = {}
	local modifier_stats = tweak_data.weapon[name].stats_modifiers
	for _, stat in pairs(self._stats_shown) do
		mods_stats[stat.name] = {}
		mods_stats[stat.name].index = 0
		mods_stats[stat.name].value = 0
	end
	if equipped_mods then
		local tweak_stats = tweak_data.weapon.stats
		local tweak_factory = tweak_data.weapon.factory.parts
		local factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(name)
		local default_blueprint = managers.weapon_factory:get_default_blueprint_by_factory_id(factory_id)
		local part_data
		for _, mod in ipairs(equipped_mods) do
			part_data = managers.weapon_factory:get_part_data_by_part_id_from_weapon(mod, factory_id, default_blueprint)
			if part_data then
				for _, stat in pairs(self._stats_shown) do
					if part_data.stats then
						if stat.name == "magazine" then
							local ammo = part_data.stats.extra_ammo
							ammo = ammo and ammo + (tweak_data.weapon[name].stats.extra_ammo or 0)
							mods_stats[stat.name].value = mods_stats[stat.name].value + (ammo and tweak_data.weapon.stats.extra_ammo[ammo] or 0)
						elseif stat.name == "totalammo" then
							local ammo = part_data.stats.total_ammo_mod
							mods_stats[stat.name].index = mods_stats[stat.name].index + (ammo or 0)
						else
							mods_stats[stat.name].index = mods_stats[stat.name].index + (part_data.stats[stat.name] or 0)
						end
					end
				end
			end
		end
		local index, stat_name
		for _, stat in pairs(self._stats_shown) do
			stat_name = stat.name
			if mods_stats[stat.name].index and tweak_stats[stat_name] then
				if stat.name == "concealment" then
					index = base_stats[stat.name].index + mods_stats[stat.name].index
				else
					index = math.clamp(base_stats[stat.name].index + mods_stats[stat.name].index, 1, #tweak_stats[stat_name])
				end
				mods_stats[stat.name].value = stat.index and index or tweak_stats[stat_name][index] * tweak_data.gui.stats_present_multiplier
				local offset = math.min(tweak_stats[stat_name][1], tweak_stats[stat_name][#tweak_stats[stat_name]]) * tweak_data.gui.stats_present_multiplier
				if stat.offset then
					mods_stats[stat.name].value = mods_stats[stat.name].value - offset
				end
				if stat.revert then
					local max_stat = math.max(tweak_stats[stat_name][1], tweak_stats[stat_name][#tweak_stats[stat_name]]) * tweak_data.gui.stats_present_multiplier
					if stat.revert then
						max_stat = max_stat - offset
					end
					mods_stats[stat.name].value = max_stat - mods_stats[stat.name].value
				end
				if modifier_stats and modifier_stats[stat.name] and stat.name == "damage" then
					local mod = modifier_stats[stat.name]
					if stat.revert and not stat.index then
						local real_base_value = tweak_stats[stat_name][index]
						local modded_value = real_base_value * mod
						local offset = math.min(tweak_stats[stat_name][1], tweak_stats[stat_name][#tweak_stats[stat_name]])
						if stat.offset then
							modded_value = modded_value - offset
						end
						local max_stat = math.max(tweak_stats[stat_name][1], tweak_stats[stat_name][#tweak_stats[stat_name]])
						if stat.revert then
							max_stat = max_stat - offset
						end
						local new_value = (max_stat - modded_value) * tweak_data.gui.stats_present_multiplier
						if mod ~= 0 and (modded_value > tweak_stats[stat_name][1] or modded_value < tweak_stats[stat_name][#tweak_stats[stat_name]]) then
							new_value = (new_value + mods_stats[stat.name].value / mod) / 2
						end
						mods_stats[stat.name].value = new_value
					else
						mods_stats[stat.name].value = mods_stats[stat.name].value * mod
					end
				end
				mods_stats[stat.name].value = mods_stats[stat.name].value - base_stats[stat.name].value
			end
		end
	end
	return mods_stats
end



function BlackMarketGui:show_stats()
	if not toggle_greater_precision then return _blackmarketgui_function_ptr5(self) end

	if not self._stats_panel or not self._rweapon_stats_panel or not self._armor_stats_panel or not self._mweapon_stats_panel then return end
	self._stats_panel:hide()
	self._rweapon_stats_panel:hide()
	self._armor_stats_panel:hide()
	self._mweapon_stats_panel:hide()
	if not self._slot_data then return end
	if not self._slot_data.comparision_data then return end
	local weapon = managers.blackmarket:get_crafted_category_slot(self._slot_data.category, self._slot_data.slot)
	local name = weapon and weapon.weapon_id or self._slot_data.name
	local category = self._slot_data.category
	local slot = self._slot_data.slot
	local value = 0
	if tweak_data.weapon[self._slot_data.name] then
		local equipped_item = managers.blackmarket:equipped_item(category)
		local equipped_slot = managers.blackmarket:equipped_weapon_slot(category)
		local equip_base_stats, equip_mods_stats, equip_skill_stats = self:_get_stats(equipped_item.weapon_id, category, equipped_slot)
		local base_stats, mods_stats, skill_stats = self:_get_stats(name, category, slot)
		self._rweapon_stats_panel:show()
		self:hide_armor_stats()
		self:hide_melee_weapon_stats()
		self:set_stats_titles(
		{name = "base", x = 170},
		{name = "mod", text_id = "bm_menu_stats_mod", color = tweak_data.screen_colors.stats_mods, x = 215}, 
		{name = "skill", alpha = 0.75}
		)
		if slot ~= equipped_slot then
			for _, title in pairs(self._stats_titles) do title:hide() end

			self:set_stats_titles({name = "total", show = true}, {
				name = "equip",
				show = true,
				text_id = "bm_menu_equipped",
				alpha = 0.75,
				x = 105
			})
		else
			for _, title in pairs(self._stats_titles) do title:show() end

			self:set_stats_titles({name = "total", hide = true}, {
				name = "equip",
				text_id = "bm_menu_stats_total",
				alpha = 1,
				x = 120
			})
		end

		for i, stat in ipairs(self._stats_shown) do
						
			value = base_stats[stat.name].value + mods_stats[stat.name].value + skill_stats[stat.name].value
			
			if slot == equipped_slot then
				self._stats_texts[stat.name].name:set_text(utf8.to_upper(managers.localization:text("bm_menu_" .. stat.name)))
				
				local base = base_stats[stat.name].value
				self._stats_texts[stat.name].equip:set_alpha(1)
				local value2, based, mod, skill
				if stat.name == "spread" then
					local ads_spread_mul = tweak_data.weapon[name].spread.steelsight
					if ads_spread_mul < 1 then ads_spread_mul = 1 / (2 - ads_spread_mul) end
					ads_spread_mul = 1
					based = 20 - ((20 - base) * ads_spread_mul)
					mod = 20 - (20 - base - mods_stats[stat.name].value) * ads_spread_mul - based
					skill = 0
					value2 = based + mod
				else
					value2 = value
					based = base
					mod = mods_stats[stat.name].value
					skill = skill_stats[stat.name].value
				end
				
				local decimals = (stat.name == "magazine" or stat.name == "totalammo" or stat.name == "concealment" or stat.name == "fire_rate") and "%0.0f" or "%0.2f"
				if stat.name == "damage" and (value2 > 9999 or based > 9999 or mod > 9999) then decimals = "%0.1f" end
				
				self._stats_texts[stat.name].equip:set_text(string.format(decimals, value2) or "")
				self._stats_texts[stat.name].base:set_text(string.format(decimals, based) or "")
				self._stats_texts[stat.name].mods:set_text((mods_stats[stat.name].value == 0 and "") or (mods_stats[stat.name].value > 0 and "+" or "") .. string.format(decimals, mod) or "")
				if stat.name == "spread" then self._stats_texts[stat.name].skill:set_text("")
				else self._stats_texts[stat.name].skill:set_text(skill_stats[stat.name].skill_in_effect and ((skill_stats[stat.name].value > 0 and "+" or "") .. string.format(decimals, skill)) or "")
				end
				
				self._stats_texts[stat.name].total:set_text("")
				if value > base then
					self._stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.stats_positive)
				elseif value < base then
					self._stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.stats_negative)
				else
					self._stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.text)
				end

				self._stats_texts[stat.name].total:set_color(tweak_data.screen_colors.text)
			else
				
				self._stats_texts[stat.name].name:set_text(utf8.to_upper(managers.localization:text("bm_menu_" .. stat.name)))
			
				local equip = equip_base_stats[stat.name].value + equip_mods_stats[stat.name].value + equip_skill_stats[stat.name].value
				self._stats_texts[stat.name].equip:set_alpha(0.75)
				local decimals = (stat.name == "magazine" or stat.name == "totalammo" or stat.name == "concealment" or stat.name == "fire_rate") and "%0.0f" or "%0.2f"
				local equip2 = equip - (stat.name == "spread" and equip_skill_stats[stat.name].value or 0)
				local value2 = value - (stat.name == "spread" and skill_stats[stat.name].value or 0)
				if stat.name == "damage" and (equip2 > 9999 or value2 > 9999) then decimals = "%0.1f" end
				self._stats_texts[stat.name].equip:set_text(string.format(decimals, equip2))
				self._stats_texts[stat.name].base:set_text("")
				self._stats_texts[stat.name].mods:set_text("")
				self._stats_texts[stat.name].skill:set_text("")
				self._stats_texts[stat.name].total:set_text(string.format(decimals, value2))
				if value2 > equip2 then
					self._stats_texts[stat.name].total:set_color(tweak_data.screen_colors.stats_positive)
				elseif value2 < equip2 then
					self._stats_texts[stat.name].total:set_color(tweak_data.screen_colors.stats_negative)
				else
					self._stats_texts[stat.name].total:set_color(tweak_data.screen_colors.text)
				end
				self._stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.text)
			end
		end
	elseif tweak_data.blackmarket.armors[self._slot_data.name] then
		local equipped_item = managers.blackmarket:equipped_item(category)
		local equipped_slot = managers.blackmarket:equipped_armor_slot()
		local equip_base_stats, equip_mods_stats, equip_skill_stats = self:_get_armor_stats(equipped_item)
		local base_stats, mods_stats, skill_stats = self:_get_armor_stats(self._slot_data.name)
		self._armor_stats_panel:show()
		self:hide_weapon_stats()
		self:hide_melee_weapon_stats()
		self:set_stats_titles({name = "base", x = 185}, {
			name = "mod",
			text_id = "bm_menu_stats_skill",
			color = tweak_data.screen_colors.resource,
			x = 245
		}, {name = "skill", alpha = 0})
		if self._slot_data.name ~= equipped_slot then
			for _, title in pairs(self._stats_titles) do title:hide() end
			
			self:set_stats_titles({name = "total", show = true}, {
				name = "equip",
				show = true,
				text_id = "bm_menu_equipped",
				alpha = 0.75,
				x = 105
			})
		else
			for _, title in pairs(self._stats_titles) do title:show() end

			self:set_stats_titles({name = "total", hide = true}, {
				name = "equip",
				text_id = "bm_menu_stats_total",
				alpha = 1,
				x = 120
			})
		end

		for i, stat in ipairs(self._armor_stats_shown) do
			self._armor_stats_texts[stat.name].name:set_text(utf8.to_upper(managers.localization:text("bm_menu_" .. stat.name)))
			value = base_stats[stat.name].value + mods_stats[stat.name].value + skill_stats[stat.name].value
			if self._slot_data.name == equipped_slot then
				local base = base_stats[stat.name].value
				self._armor_stats_texts[stat.name].equip:set_alpha(1)
				self._armor_stats_texts[stat.name].equip:set_text(value)
				self._armor_stats_texts[stat.name].base:set_text(base)

				self._armor_stats_texts[stat.name].skill:set_text((0 < skill_stats[stat.name].value and "+" or "") .. skill_stats[stat.name].value or "")
				self._armor_stats_texts[stat.name].total:set_text("")
				self._armor_stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.text)
				if value ~= 0 and value > base then
					self._armor_stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.stats_positive)
				elseif value ~= 0 and value < base then
					self._armor_stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.stats_negative)
				else
					self._armor_stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.text)
				end

				self._armor_stats_texts[stat.name].total:set_color(tweak_data.screen_colors.text)
			else
				local equip = equip_base_stats[stat.name].value + equip_mods_stats[stat.name].value + equip_skill_stats[stat.name].value
				self._armor_stats_texts[stat.name].equip:set_alpha(0.75)
				self._armor_stats_texts[stat.name].equip:set_text(equip)
				self._armor_stats_texts[stat.name].base:set_text("")
				self._armor_stats_texts[stat.name].skill:set_text("")
				self._armor_stats_texts[stat.name].total:set_text(value)
				if value > equip then
					self._armor_stats_texts[stat.name].total:set_color(tweak_data.screen_colors.stats_positive)
				elseif value < equip then
					self._armor_stats_texts[stat.name].total:set_color(tweak_data.screen_colors.stats_negative)
				else
					self._armor_stats_texts[stat.name].total:set_color(tweak_data.screen_colors.text)
				end

				self._armor_stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.text)
			end

		end

	elseif tweak_data.blackmarket.melee_weapons[self._slot_data.name] then
		self:hide_armor_stats()
		self:hide_weapon_stats()
		self._mweapon_stats_panel:show()
		self:set_stats_titles({name = "base", x = 185}, {
			name = "mod",
			text_id = "bm_menu_stats_skill",
			color = tweak_data.screen_colors.resource,
			x = 245
		}, {name = "skill", alpha = 0})
		local equipped_item = managers.blackmarket:equipped_item(category)
		local equip_base_stats, equip_mods_stats, equip_skill_stats = self:_get_melee_weapon_stats(equipped_item)
		local base_stats, mods_stats, skill_stats = self:_get_melee_weapon_stats(self._slot_data.name)
		if self._slot_data.name ~= equipped_item then
			for _, title in pairs(self._stats_titles) do
				title:hide()
			end
			self:set_stats_titles({name = "total", show = true}, {
				name = "equip",
				show = true,
				text_id = "bm_menu_equipped",
				alpha = 0.75,
				x = 105
			})
		else
			for title_name, title in pairs(self._stats_titles) do
				title:show()
			end
			self:set_stats_titles({name = "total", hide = true}, {
				name = "equip",
				text_id = "bm_menu_stats_total",
				alpha = 1,
				x = 120
			})
		end
		local value_min, value_max, skill_value_min, skill_value_max, skill_value
		for _, stat in ipairs(self._mweapon_stats_shown) do
			self._mweapon_stats_texts[stat.name].name:set_text(utf8.to_upper(managers.localization:text("bm_menu_" .. stat.name)))
			if stat.range then
				value_min = math.max(base_stats[stat.name].min_value + mods_stats[stat.name].min_value + skill_stats[stat.name].min_value, 0)
				value_max = math.max(base_stats[stat.name].max_value + mods_stats[stat.name].max_value + skill_stats[stat.name].max_value, 0)
			end
			value = math.max(base_stats[stat.name].value + mods_stats[stat.name].value + skill_stats[stat.name].value, 0)
			if self._slot_data.name == equipped_item then
				local base, base_min, base_max, skill, skill_min, skill_max
				if stat.range then
					base_min = base_stats[stat.name].min_value
					base_max = base_stats[stat.name].max_value
					skill_min = skill_stats[stat.name].min_value
					skill_max = skill_stats[stat.name].max_value
				end
				base = base_stats[stat.name].value
				skill = skill_stats[stat.name].value
				local format_string = "%0." .. tostring(stat.num_decimals or 0) .. "f"
				local equip_text = value and string.format(format_string, value)
				local base_text = base and string.format(format_string, base)
				local skill_text = skill_stats[stat.name].value and string.format(format_string, skill_stats[stat.name].value)
				local base_min_text = base_min and string.format(format_string, base_min)
				local base_max_text = base_max and string.format(format_string, base_max)
				local value_min_text = value_min and string.format(format_string, value_min)
				local value_max_text = value_max and string.format(format_string, value_max)
				local skill_min_text = skill_min and string.format(format_string, skill_min)
				local skill_max_text = skill_max and string.format(format_string, skill_max)
				if stat.range then
					if base_min ~= base_max then
						base_text = base_min_text .. " (" .. base_max_text .. ")"
					end
					if value_min ~= value_max then
						equip_text = value_min_text .. " (" .. value_max_text .. ")"
					end
					if skill_min ~= skill_max then
						skill_text = skill_min_text .. " (" .. skill_max_text .. ")"
					end
				end
				if stat.suffix then
					base_text = base_text .. tostring(stat.suffix)
					equip_text = equip_text .. tostring(stat.suffix)
					skill_text = skill_text .. tostring(stat.suffix)
				end
				if stat.prefix then
					base_text = tostring(stat.prefix) .. base_text
					equip_text = tostring(stat.prefix) .. equip_text
					skill_text = tostring(stat.prefix) .. skill_text
				end
				self._mweapon_stats_texts[stat.name].equip:set_alpha(1)
				self._mweapon_stats_texts[stat.name].equip:set_text(equip_text)
				self._mweapon_stats_texts[stat.name].base:set_text(base_text)
				if skill_stats[stat.name].skill_in_effect then
				else
				end
				self._mweapon_stats_texts[stat.name].skill:set_text((0 < skill_stats[stat.name].value and "+" or "") .. skill_text or "")
				self._mweapon_stats_texts[stat.name].total:set_text("")
				self._mweapon_stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.text)
				local positive = value ~= 0 and value > base
				local negative = value ~= 0 and value < base
				if stat.inverse then
					local temp = positive
					positive = negative
					negative = temp
				end
				if stat.range then
					if positive then
						self._mweapon_stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.stats_positive)
					elseif negative then
						self._mweapon_stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.stats_negative)
					end
				elseif positive then
					self._mweapon_stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.stats_positive)
				elseif negative then
					self._mweapon_stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.stats_negative)
				else
					self._mweapon_stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.text)
				end
				self._mweapon_stats_texts[stat.name].total:set_color(tweak_data.screen_colors.text)
			else
				local equip, equip_min, equip_max
				if stat.range then
					equip_min = math.max(equip_base_stats[stat.name].min_value + equip_mods_stats[stat.name].min_value + equip_skill_stats[stat.name].min_value, 0)
					equip_max = math.max(equip_base_stats[stat.name].max_value + equip_mods_stats[stat.name].max_value + equip_skill_stats[stat.name].max_value, 0)
				end
				equip = math.max(equip_base_stats[stat.name].value + equip_mods_stats[stat.name].value + equip_skill_stats[stat.name].value, 0)
				local format_string = "%0." .. tostring(stat.num_decimals or 0) .. "f"
				local equip_text = equip and string.format(format_string, equip)
				local total_text = value and string.format(format_string, value)
				local equip_min_text = equip_min and string.format(format_string, equip_min)
				local equip_max_text = equip_max and string.format(format_string, equip_max)
				local total_min_text = value_min and string.format(format_string, value_min)
				local total_max_text = value_max and string.format(format_string, value_max)
				local color_ranges = {}
				if stat.range then
					if equip_min ~= equip_max then
						equip_text = equip_min_text .. " (" .. equip_max_text .. ")"
					end
					if value_min ~= value_max then
						total_text = total_min_text .. " (" .. total_max_text .. ")"
					end
				end
				if stat.suffix then
					equip_text = equip_text .. tostring(stat.suffix)
					total_text = total_text .. tostring(stat.suffix)
				end
				if stat.prefix then
					equip_text = tostring(stat.prefix) .. equip_text
					total_text = tostring(stat.prefix) .. total_text
				end
				self._mweapon_stats_texts[stat.name].equip:set_alpha(0.75)
				self._mweapon_stats_texts[stat.name].equip:set_text(equip_text)
				self._mweapon_stats_texts[stat.name].base:set_text("")
				self._mweapon_stats_texts[stat.name].skill:set_text("")
				self._mweapon_stats_texts[stat.name].total:set_text(total_text)
				if stat.range then
					local positive = value_min > equip_min
					local negative = value_min < equip_min
					if stat.inverse then
						local temp = positive
						positive = negative
						negative = temp
					end
					local color_range_min = {
						start = 0,
						stop = utf8.len(total_min_text),
						color = nil
					}
					if positive then
						color_range_min.color = tweak_data.screen_colors.stats_positive
					elseif negative then
						color_range_min.color = tweak_data.screen_colors.stats_negative
					else
						color_range_min.color = tweak_data.screen_colors.text
					end
					table.insert(color_ranges, color_range_min)
					positive = value_max > equip_max
					negative = value_max < equip_max
					if stat.inverse then
						local temp = positive
						positive = negative
						negative = temp
					end
					local color_range_max = {
						start = color_range_min.stop + 1,
						stop = nil,
						color = nil
					}
					color_range_max.stop = color_range_max.start + 3 + utf8.len(total_max_text)
					if positive then
						color_range_max.color = tweak_data.screen_colors.stats_positive
					elseif negative then
						color_range_max.color = tweak_data.screen_colors.stats_negative
					else
						color_range_max.color = tweak_data.screen_colors.text
					end
					table.insert(color_ranges, color_range_max)
				else
					local positive = value > equip
					local negative = value < equip
					if stat.inverse then
						local temp = positive
						positive = negative
						negative = temp
					end
					local color_range = {
						start = 0,
						stop = utf8.len(equip_text),
						color = nil
					}
					if positive then
						color_range.color = tweak_data.screen_colors.stats_positive
					elseif negative then
						color_range.color = tweak_data.screen_colors.stats_negative
					else
						color_range.color = tweak_data.screen_colors.text
					end
					table.insert(color_ranges, color_range)
				end
				self._mweapon_stats_texts[stat.name].total:set_color(tweak_data.screen_colors.text)
				self._mweapon_stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.text)
				for _, color_range in ipairs(color_ranges) do
					self._mweapon_stats_texts[stat.name].total:set_range_color(color_range.start, color_range.stop, color_range.color)
				end
			end
		end
	else
		local equip, stat_changed
		local tweak_parts = tweak_data.weapon.factory.parts[self._slot_data.name]
		local mod_stats = self:_get_stats_for_mod(self._slot_data.name, name, category, slot)
		local hide_equip = mod_stats.equip.name == mod_stats.chosen.name
		self._rweapon_stats_panel:show()
		self:hide_armor_stats()
		self:hide_melee_weapon_stats()
		for _, title in pairs(self._stats_titles) do title:hide() end
		if not mod_stats.equip.name then
			self._stats_titles.equip:hide()
		else
			self._stats_titles.equip:show()
			self._stats_titles.equip:set_text(utf8.to_upper(managers.localization:text("bm_menu_equipped")))
			self._stats_titles.equip:set_alpha(0.75)
			self._stats_titles.equip:set_x(105)
		end

		if not hide_equip then self._stats_titles.total:show() end
		for i, stat in ipairs(self._stats_shown) do
			self._stats_texts[stat.name].name:set_text(utf8.to_upper(managers.localization:text("bm_menu_" .. stat.name)))
			value = mod_stats.chosen[stat.name]
			equip = mod_stats.equip[stat.name]
			stat_changed = tweak_parts and tweak_parts.stats[stat.stat_name or stat.name] and value ~= 0 and 1 or 0.5

			for stat_name, stat_text in pairs(self._stats_texts[stat.name]) do if stat_name ~= "name" then stat_text:set_text("") end end
			for name, column in pairs(self._stats_texts[stat.name]) do column:set_alpha(stat_changed) end
			
			local decimals = (stat.name == "magazine" or stat.name == "totalammo" or stat.name == "concealment") and "%0.0f" or "%0.2f"
			local value2, equip2
			value2 = value
			equip2 = equip
			self._stats_texts[stat.name].total:set_text(not hide_equip and stat_changed == 1 and (( value > 0 and "+" or "") .. string.format(decimals, value2) or ""))
			self._stats_texts[stat.name].equip:set_text((equip == 0 and "") or (equip > 0 and "+" or "") .. string.format(decimals, equip2))
			self._stats_texts[stat.name].equip:set_alpha(0.75)
			if value > equip then
				self._stats_texts[stat.name].total:set_color(tweak_data.screen_colors.stats_positive)
			elseif value < equip then
				self._stats_texts[stat.name].total:set_color(tweak_data.screen_colors.stats_negative)
			else
				self._stats_texts[stat.name].total:set_color(tweak_data.screen_colors.text)
			end
			self._stats_texts[stat.name].equip:set_color(tweak_data.screen_colors.text)
		end
	end
	local modslist_panel = self._stats_panel:child("modslist_panel")
	local y = 0
	if self._rweapon_stats_panel:visible() then
		for i, child in ipairs(self._rweapon_stats_panel:children()) do y = math.max(y, child:bottom()) end
	elseif self._armor_stats_panel:visible() then
		for i, child in ipairs(self._armor_stats_panel:children()) do y = math.max(y, child:bottom()) end
	elseif self._mweapon_stats_panel:visible() then
		for i, child in ipairs(self._mweapon_stats_panel:children()) do y = math.max(y, child:bottom()) end
	end
	modslist_panel:set_top(y + 10)
	self._stats_panel:show()
end



function BlackMarketGui:_get_stats(name, category, slot)
	if not toggle_greater_precision then return _blackmarketgui_function_ptr6(self, name, category, slot) end
	
	local equipped_mods
	local silencer = false
	local single_mod = false
	local auto_mod = false
	local blueprint = managers.blackmarket:get_weapon_blueprint(category, slot)
	if blueprint then
		equipped_mods = deep_clone(blueprint)
		local factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(name)
		local default_blueprint = managers.weapon_factory:get_default_blueprint_by_factory_id(factory_id)
		if equipped_mods then
			silencer = managers.weapon_factory:has_perk("silencer", factory_id, equipped_mods)
			single_mod = managers.weapon_factory:has_perk("fire_mode_single", factory_id, equipped_mods)
			auto_mod = managers.weapon_factory:has_perk("fire_mode_auto", factory_id, equipped_mods)
		end
	end
	local base_stats = self:_get_base_stats(name)
	local mods_stats = self:_get_mods_stats(name, base_stats, equipped_mods)
	local skill_stats = self:_get_skill_stats(name, category, slot, base_stats, mods_stats, silencer, single_mod, auto_mod)
	local clip_ammo, max_ammo, ammo_data = self:get_weapon_ammo_info(name, tweak_data.weapon[name].stats.extra_ammo, base_stats.totalammo.index + mods_stats.totalammo.index)
	base_stats.totalammo.value = ammo_data.base
	mods_stats.totalammo.value = ammo_data.mod
	skill_stats.totalammo.value = ammo_data.skill
	skill_stats.totalammo.skill_in_effect = ammo_data.skill_in_effect
	local my_clip = base_stats.magazine.value + mods_stats.magazine.value + skill_stats.magazine.value
	if max_ammo < my_clip then mods_stats.magazine.value = mods_stats.magazine.value + (max_ammo - my_clip) end
	return base_stats, mods_stats, skill_stats
end



function BlackMarketGui:_get_weapon_mod_stats(mod_name, weapon_name, base_stats, mods_stats, equipped_mods)
	if not toggle_greater_precision then return _blackmarketgui_function_ptr7(self, mod_name, weapon_name, base_stats, mods_stats, equipped_mods) end

	local tweak_stats = tweak_data.weapon.stats
	local tweak_factory = tweak_data.weapon.factory.parts
	local modifier_stats = tweak_data.weapon[weapon_name].stats_modifiers
	local factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(weapon_name)
	local default_blueprint = managers.weapon_factory:get_default_blueprint_by_factory_id(factory_id)
	local part_data
	local mod_stats = {}
	mod_stats.chosen = {}
	mod_stats.equip = {}
	for _, stat in pairs( self._stats_shown ) do
		mod_stats.chosen[stat.name] = 0
		mod_stats.equip[stat.name] = 0
	end
	mod_stats.chosen.name = mod_name
	if equipped_mods then
		for _, mod in ipairs( equipped_mods ) do
			if tweak_factory[mod] and tweak_factory[mod_name].type == tweak_factory[mod].type then
				mod_stats.equip.name = mod
			else --originally "break"
			end
		end
	end
	local curr_stats = base_stats
	local index
	for _, mod in pairs( mod_stats ) do
		part_data = mod.name and managers.weapon_factory:get_part_data_by_part_id_from_weapon(mod.name, factory_id, default_blueprint) or nil
		for _, stat in pairs( self._stats_shown ) do
			if part_data and part_data.stats then
				if stat.name == "magazine" then
					local ammo = part_data.stats.extra_ammo
					ammo = ammo and ammo + (tweak_data.weapon[weapon_name].stats.extra_ammo or 0)
					mod[stat.name] = ammo and tweak_data.weapon.stats.extra_ammo[ammo] or 0
				elseif stat.name == "totalammo" then
					local chosen_index = part_data.stats.total_ammo_mod or 0
					chosen_index = math.clamp(base_stats[stat.name].index + chosen_index, 1, #tweak_stats.total_ammo_mod)
					mod[stat.name] = base_stats[stat.name].value * tweak_stats.total_ammo_mod[chosen_index]
				else
					local chosen_index = part_data.stats[stat.name] or 0
					if tweak_stats[stat.name] then
						index = math.clamp(curr_stats[stat.name].index + chosen_index, 1, #tweak_stats[stat.name])
						mod[stat.name] = stat.index and index or tweak_stats[stat.name][index] * tweak_data.gui.stats_present_multiplier
						local offset = math.min(tweak_stats[stat.name][1], tweak_stats[stat.name][#tweak_stats[stat.name]]) * tweak_data.gui.stats_present_multiplier
						if stat.offset then mod[stat.name] = mod[stat.name] - offset end
						if stat.revert then
							local max_stat = math.max(tweak_stats[stat.name][1], tweak_stats[stat.name][#tweak_stats[stat.name]]) * tweak_data.gui.stats_present_multiplier
							if stat.revert then max_stat = max_stat - offset end
							mod[stat.name] = max_stat - mod[stat.name]
						end
						if modifier_stats and modifier_stats[stat.name] and stat.name == "damage" then
							local mod_stat = modifier_stats[stat.name]
							if stat.revert and not stat.index then
								local real_base_value = tweak_stats[stat.name][index]
								local modded_value = real_base_value * mod_stat
								local offset = math.min(tweak_stats[stat.name][1], tweak_stats[stat.name][#tweak_stats[stat.name]])
								if stat.offset then modded_value = modded_value - offset end
								local max_stat = math.max(tweak_stats[stat.name][1], tweak_stats[stat.name][#tweak_stats[stat.name]])
								if stat.revert then max_stat = max_stat - offset end 
								local new_value = (max_stat - modded_value) * tweak_data.gui.stats_present_multiplier
								if mod_stat ~= 0 and (modded_value > tweak_stats[stat.name][1] or modded_value < tweak_stats[stat.name][#tweak_stats[stat.name]]) then
									new_value = (new_value + mod[stat.name] / mod_stat) / 2
								end
								mod[stat.name] = new_value
							else
								mod[stat.name] = mod[stat.name] * mod_stat
							end
						end
						mod[stat.name] = mod[stat.name] - curr_stats[stat.name].value
					end
				end
			end
		end
	end
	return mod_stats
end



function BlackMarketGui:mouse_moved(o, x, y, ...)
	if not toggle_greater_precision then return _blackmarketgui_function_ptr1(self, o, x, y, ...) end
	
	if self._enabled and not self._renaming_item then
		self:_check_popup(x, y)
	end
	return _blackmarketgui_function_ptr1(self, o, x, y, ...)
end



function BlackMarketGui:_pre_reload(...)
	self:_delete_popups()
	return _blackmarketgui_function_ptr8(self, ...)
end



function BlackMarketGui:update_info_text(...)
	if not toggle_greater_precision then return _blackmarketgui_function_ptr9(self, ...) end
	
	self:_check_update_info(self._slot_data, self._tabs[self._selected]._data)
	return _blackmarketgui_function_ptr9(self, ...)
end



function BlackMarketGui:_delete_popups()
	if self._equipped_stat_popup then
		self._equipped_stat_popup:delete()
		self._equipped_stat_popup = nil
	end
	if self._selected_stat_popup then
		self._selected_stat_popup:delete()
		self._selected_stat_popup = nil
	end
end



function BlackMarketGui:_check_update_info(slot_data, tab_data)
	if self._popup_stat then
		self:_create_stat_popup()
	end
end



function BlackMarketGui:_check_popup(x, y)
	local panels = {
		self._rweapon_stats_panel,
		self._mweapon_stats_panel,
		self._armor_stats_panel,
	}
	
	for _, p in ipairs(panels) do
		if p:visible() and p:inside(x, y) then
			for i, stat_row in ipairs(p:children()) do
				if stat_row:visible() and stat_row:inside(x, y) then
					if self._popup_stat ~= i then
						self._popup_stat = i
						self:_create_stat_popup()
					end
					return
				end
			end
		end
	end
	
	self._popup_stat = nil
	self:_delete_popups()
end



function BlackMarketGui:_create_stat_popup()
	self._equipped_stat_popup = self._equipped_stat_popup or InventoryStatsPopup:new(self._panel, self._popup_stat, true)
	self._equipped_stat_popup:update(self._popup_stat, self:_get_popup_data(true))
	self._equipped_stat_popup:set_position(self._stats_panel:x() - 10 - self._equipped_stat_popup:w(), self._panel:h()/2 - self._equipped_stat_popup:h()/2)
	
	if not self._slot_data.equipped then
		self._selected_stat_popup = self._selected_stat_popup or InventoryStatsPopup:new(self._panel, false)
		self._selected_stat_popup:update(self._popup_stat, self:_get_popup_data(false))
		self._selected_stat_popup:set_position(self._equipped_stat_popup._panel:x() - self._selected_stat_popup:w(), self._equipped_stat_popup._panel:y())
	elseif self._selected_stat_popup then
		self._selected_stat_popup:delete()
		self._selected_stat_popup = nil
	end
end



function BlackMarketGui:_get_popup_data(equipped)
	local category = self._slot_data.category
	local data

	if tweak_data.weapon[self._slot_data.name] then
		local slot = equipped and managers.blackmarket:equipped_weapon_slot(category) or self._slot_data.slot
		local weapon = equipped and managers.blackmarket:equipped_item(category) or managers.blackmarket:get_crafted_category_slot(category, slot)
		local name = equipped and weapon.weapon_id or weapon and weapon.weapon_id or self._slot_data.name
		local factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(name)
		local blueprint = managers.blackmarket:get_weapon_blueprint(category, slot)
		local ammo_data = factory_id and blueprint and managers.weapon_factory:get_ammo_data_from_weapon(factory_id, blueprint) or {}
		local custom_stats = factory_id and blueprint and managers.weapon_factory:get_custom_stats_from_weapon(factory_id, blueprint)
		if custom_stats then
			for part_id, stats in pairs(custom_stats) do
				if tweak_data.weapon.factory.parts[part_id].type ~= "ammo" then
					if stats.ammo_pickup_min_mul then
						ammo_data.ammo_pickup_min_mul = ammo_data.ammo_pickup_min_mul and ammo_data.ammo_pickup_min_mul * stats.ammo_pickup_min_mul or stats.ammo_pickup_min_mul
					end
					if stats.ammo_pickup_max_mul then
						ammo_data.ammo_pickup_max_mul = ammo_data.ammo_pickup_max_mul and ammo_data.ammo_pickup_max_mul * stats.ammo_pickup_max_mul or stats.ammo_pickup_max_mul
					end
				end
			end
		end
		local base_stats, mods_stats, skill_stats = managers.menu_component._blackmarket_gui:_get_stats(name, category, slot)
		data = {
			base_stats = base_stats,
			mods_stats = mods_stats,
			skill_stats = skill_stats,
			inventory_category = category,
			inventory_slot = slot,
			stat_table = self._stats_shown,
			name = name,
			localized_name = managers.localization:text(tweak_data.weapon[name].name_id),
			category = tweak_data.weapon[name].category,
			tweak = tweak_data.weapon[name],
			weapon = weapon,
			factory_id = factory_id,
			blueprint = blueprint,
			ammo_data = ammo_data,
			silencer = factory_id and blueprint and managers.weapon_factory:has_perk("silencer", factory_id, blueprint),
			--weapon_modified = factory_id and blueprint and managers.blackmarket:is_weapon_modified(factory_id, blueprint),
		}
		if data.tweak.category == "saw" then return nil end
	elseif tweak_data.blackmarket.armors[self._slot_data.name] then
		local name = equipped and managers.blackmarket:equipped_item(category) or self._slot_data.name
		data = {
			inventory_category = category,
			--inventory_slot = slot,
			stat_table = self._armor_stats_shown,
			name = name,
			localized_name = managers.localization:text(tweak_data.blackmarket.armors[name].name_id),
			--category = tweak_data.weapon[name].category,
			--tweak = tweak_data.weapon[name],
			--factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(name),
			--blueprint = managers.blackmarket:get_weapon_blueprint(category, slot),
		}
	elseif tweak_data.blackmarket.melee_weapons[self._slot_data.name] then
		local name = equipped and managers.blackmarket:equipped_item(category) or self._slot_data.name
		data = {
			inventory_category = category,
			--inventory_slot = slot,
			stat_table = self._mweapon_stats_shown,
			name = name,
			localized_name = managers.localization:text(tweak_data.blackmarket.melee_weapons[name].name_id),
			--category = tweak_data.weapon[name].category,
			--tweak = tweak_data.weapon[name],
			--factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(name),
			--blueprint = managers.blackmarket:get_weapon_blueprint(category, slot),
		}
	else
		local selected_mod = tweak_data.weapon.factory.parts[self._slot_data.name]
		local equipped_mod
		local blueprint = managers.blackmarket:get_weapon_blueprint(self._slot_data.category, self._slot_data.slot)
		if blueprint then
			for _, mod in ipairs(blueprint) do
				if tweak_data.weapon.factory.parts[mod].type == selected_mod.type then
					equipped_mod = tweak_data.weapon.factory.parts[mod]
					break
				end
			end
		end
		local name = equipped and equipped_mod or selected_mod
		if not name then return nil end
		local localized_name
		if equipped then
			if equipped_mod then
				for _, mod in ipairs(tweak_data.weapon.factory[managers.weapon_factory:get_factory_id_by_weapon_id(managers.blackmarket:equipped_item(category).weapon_id)].default_blueprint) do
					if equipped_mod == tweak_data.weapon.factory.parts[mod] then
						localized_name = "Default Part"
						break
					end
				end
			else
				localized_name = "No Part"
			end
		end
		data = {
			inventory_category = "mods",
			--inventory_slot = slot,
			stat_table = self._stats_shown,
			name = name,
			localized_name = localized_name or managers.localization:text(name.name_id),
			stats = equipped and not equipped_mod and {} or name.stats,
			type = name.type
		}
	end
	
	return data
end



InventoryStatsPopup = InventoryStatsPopup or class()

InventoryStatsPopup.FONT_SCALE = 0.85
InventoryStatsPopup.VERTICAL_MARGIN = 10
InventoryStatsPopup.HORIZONTAL_MARGIN = 10
InventoryStatsPopup.ROW_MARGIN = 0

function InventoryStatsPopup:init(parent, equipped)
	self._panel = parent:panel({ name = "stats_popup", visible = true, layer = 10, })
	self._bg = self._panel:rect({ name = "bg", w = 10000, h = 10000, blend_mode = "normal", color = Color.black, layer = 10, })
	self._left_border = self._panel:rect({ name = "left_border", h = 10000, w = 3, blend_mode = "normal", color = Color.white, layer = 10, })
	self._right_border = self._panel:rect({ name = "right_border", h = 10000, w = 3, blend_mode = "normal", color = Color.white, layer = 10, })
	self._top_border = self._panel:rect({ name = "top_border", h = 3, w = 10000, blend_mode = "normal", color = Color.white, layer = 10, })
	self._bottom_border = self._panel:rect({ name = "bottom_border", h = 3, w = 10000, blend_mode = "normal", color = Color.white, layer = 10, })
	self._header = self._panel:text({ name = "header", align = "center", vertical = "center", color = Color.white, layer = 10,
		y = InventoryStatsPopup.VERTICAL_MARGIN,
		font = tweak_data.menu.pd2_small_font,
		font_size = tweak_data.menu.pd2_small_font_size * 1.25 * InventoryStatsPopup.FONT_SCALE,
		h = tweak_data.menu.pd2_small_font_size * 1.5 * InventoryStatsPopup.FONT_SCALE,
	})
	
	self._equipped = equipped
	self._rows = {}
end

function InventoryStatsPopup:delete()
	self:_clear()
	for _, child in ipairs(self._panel:children()) do
		self._panel:remove(child)
	end
	self._panel:parent():remove(self._panel)
end

function InventoryStatsPopup:_clear()
	for _, row in ipairs(self._rows) do
		row:delete()
	end
	
	self._rows = {}
	self._stat = nil
	self._data = nil
	self._panel:set_visible(false)
end

function InventoryStatsPopup:update(stat_index, data)
	self:_clear()
	if data then
		self._stat = stat_index
		self._data = data
		
		local cbk_name = string.format("_%s_%s", data.inventory_category, data.stat_table[stat_index].name)
		if self[cbk_name] then
			self[cbk_name](self)
			return self:_finalize()
		end
	end
end

function InventoryStatsPopup:h()
	return self._panel:h()
end

function InventoryStatsPopup:w()
	return self._panel:w()
end

function InventoryStatsPopup:set_position(x, y)
	self._panel:set_position(x, y)
end

function InventoryStatsPopup:_finalize()
	if #self._rows <= 0 then
		self._panel:set_visible(false)
		return false
	end
	
	self._header:set_text(self._data.localized_name .. (self._equipped and " (E)" or " (S)"))
	local _, _, header_width, _ = self._header:text_rect()
	local max_left_width = 0
	local max_right_width = 0
	local offset = self._header:bottom() + InventoryStatsPopup.VERTICAL_MARGIN
	
	for _, row in ipairs(self._rows) do
		max_left_width = math.max(max_left_width, row:left_w())
		max_right_width = math.max(max_right_width, row:right_w())
	end
	local max_width = math.max(max_left_width + max_right_width + 12 * InventoryStatsPopup.FONT_SCALE, header_width)
	for _, row in ipairs(self._rows) do
		row:set_top(offset)
		row:set_w(max_width)
		offset = offset + row:h()
	end

	offset = offset + InventoryStatsPopup.VERTICAL_MARGIN
	self._panel:set_visible(true)
	self._panel:set_size(max_width + InventoryStatsPopup.HORIZONTAL_MARGIN * 2, offset)
	self._header:set_w(self._panel:w())
	self._right_border:set_right(max_width + InventoryStatsPopup.HORIZONTAL_MARGIN * 2)
	self._bottom_border:set_bottom(offset)
	return true
end

function InventoryStatsPopup:_add_row(args)
	local new_row = InventoryStatsPopupRow:new(self._panel, args and (args.height or args.h), args and (args.scale or args.s))
	table.insert(self._rows, new_row)
	return new_row
end
InventoryStatsPopup.row = InventoryStatsPopup._add_row

function InventoryStatsPopup:_delete_row(row)
	for i, r in ipairs(self._rows) do
		if r == row then
			table.remove(i)
			break
		end
	end
	row:delete()
end

function InventoryStatsPopup:_text_color(value, threshold, compare)
	if compare == ">" then
		return value > threshold and Color.green or value < threshold and Color.red or Color.white
	else
		return value < threshold and Color.green or value > threshold and Color.red or Color.white
	end
end



InventoryStatsPopupRow = InventoryStatsPopupRow or class()

InventoryStatsPopupRow.COMPONENT_SPACING = 4

function InventoryStatsPopupRow:init(parent, height, scale)
	self._scale = scale or 1	
	self._text_components = 0
	self._total_left_width = 0
	self._total_right_width = 0
	self._left_aligned = {}
	self._right_aligned = {}

	self._panel = parent:panel({
		name = "row",
		h = ((height or tweak_data.menu.pd2_small_font_size) + InventoryStatsPopup.ROW_MARGIN) * InventoryStatsPopup.FONT_SCALE * self._scale,
		layer = 11,
	})
end

function InventoryStatsPopupRow:delete()
	for _, child in ipairs(self._panel:children()) do
		self._panel:remove(child)
	end
	self._panel:parent():remove(self._panel)
end

function InventoryStatsPopupRow:add_left_text(text, args)
	local args = args or {}
	args.align = "left"
	return self:add_text(text, args)
end
InventoryStatsPopupRow.l_text = InventoryStatsPopupRow.add_left_text

function InventoryStatsPopupRow:add_right_text(text, args)
	local args = args or {}
	args.align = "right"
	return self:add_text(text, args)
end
InventoryStatsPopupRow.r_text = InventoryStatsPopupRow.add_right_text

function InventoryStatsPopupRow:add_text(text, args)
	local function format_numbers(text)
		for num, _ in text:gmatch("([0-9]+%.[0-9]+)") do
			text = text:gsub(num, string.format("%f", num):gsub('%.?0+$', ""))
		end
		return text
	end

	local args = args or {}
	local text = string.format(text, unpack(args.data or {}))
	local align = args.align == "right" and "right" or "left"
	
	text = args.no_trim and text or format_numbers(text)
	local tmp = self._panel:text({
		name = "text_" .. tostring(self._text_components),
		text = text:gsub("\t", "   "),
		align = align,
		vertical = "center",
		color = args.color or Color.white,
		font = tweak_data.menu.pd2_small_font,
		font_size = (args.font_size or (args.font_scale or 1) * (self._panel:h() - InventoryStatsPopup.ROW_MARGIN * InventoryStatsPopup.FONT_SCALE)) * self._scale,
		h = self._panel:h(),
		layer = 12,
	})
	local _, _, w, _ = tmp:text_rect()
	
	self._text_components = self._text_components + 1
	tmp:set_w(w)
	tmp:set_center(self._panel:center())
	if align == "left" then
		self._total_left_width = self._total_left_width + w
		table.insert(self._left_aligned, tmp)
	else
		self._total_right_width = self._total_right_width + w
		table.insert(self._right_aligned, 1, tmp)
	end
	return self
end

function InventoryStatsPopupRow:add_border(args)
	local args = args or {}
	local tmp = self._panel:rect({
		blend_mode = "normal",
		color = args.color or Color.white,
		h = args.h or 1,
		w = 10000,
		layer = 12,
	})
	tmp:set_center(self._panel:center())
	return self
end

function InventoryStatsPopupRow:set_w(width)
	self._panel:set_w(width + InventoryStatsPopup.HORIZONTAL_MARGIN * 2)
	
	if #self._left_aligned > 0 then
		self._left_aligned[1]:set_left(InventoryStatsPopup.HORIZONTAL_MARGIN)
		for i = 2, #self._left_aligned, 1 do
			self._left_aligned[i]:set_left(self._left_aligned[i-1]:right() + InventoryStatsPopupRow.COMPONENT_SPACING)
		end
	end
	
	if #self._right_aligned > 0 then
		self._right_aligned[1]:set_right(self._panel:w() - InventoryStatsPopup.HORIZONTAL_MARGIN)
		for i = 2, #self._right_aligned, 1 do
			self._right_aligned[i]:set_right(self._right_aligned[i-1]:left() - InventoryStatsPopupRow.COMPONENT_SPACING)
		end
	end
end

function InventoryStatsPopupRow:set_top(pos)
	self._panel:set_top(pos)
end

function InventoryStatsPopupRow:w()
	return self:left_w() + self:right_w()
end

function InventoryStatsPopupRow:h()
	return self._panel:h()
end

function InventoryStatsPopupRow:left_w()
	return self._total_left_width + (#self._left_aligned - 1) * InventoryStatsPopupRow.COMPONENT_SPACING
end

function InventoryStatsPopupRow:right_w()
	return self._total_right_width + (#self._right_aligned - 1) * InventoryStatsPopupRow.COMPONENT_SPACING
end



function InventoryStatsPopup:_primaries_magazine()
	local reload_mul = managers.blackmarket:_convert_add_to_mul(1 + (1 - managers.player:upgrade_value(self._data.category, "reload_speed_multiplier", 1)) + (1 - managers.player:upgrade_value("weapon", "passive_reload_speed_multiplier", 1)) + (1 - managers.player:upgrade_value(self._data.name, "reload_speed_multiplier", 1)))
	local mag = self._data.base_stats.magazine.value + self._data.mods_stats.magazine.value + self._data.skill_stats.magazine.value
	local reload_not_empty = self._data.tweak.timers and self._data.tweak.timers.reload_not_empty
	local reload_empty = self._data.tweak.timers and self._data.tweak.timers.reload_empty
	local rof = 60 / (self._data.base_stats.fire_rate.value + self._data.mods_stats.fire_rate.value + self._data.skill_stats.fire_rate.value)
	
	if reload_not_empty and reload_empty then
		if reload_not_empty ~= reload_empty then
			self:row():l_text("Reload Time:")
			self:row({ s = 0.9 }):l_text("\tTactical:"):r_text("%.2fs", {data = {reload_not_empty / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tEmpty:"):r_text("%.2fs", {data = {reload_empty / reload_mul}})
		else
			self:row():l_text("Reload Time:"):r_text("%.2fs", {data = {reload_not_empty / reload_mul}})
		end
	else
		self:row():l_text("Reload Time:")
		if self._data.name == "striker" then
			self:row({ s = 0.9 }):l_text("\tFirst Shell:"):r_text("%.2fs", {data = {1 / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tEach Additional Shell:"):r_text("%.2fs", {data = {18 / 30 / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tFull:"):r_text("%.2fs", {data = {(12 / 30 + mag * 18 / 30) / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tEnd delay (Cancelable):"):r_text("%.2fs", {data = {0.4 / reload_mul}})
		else
			self:row({ s = 0.9 }):l_text("\tFirst Shell:"):r_text("%.2fs", {data = {(17 / 30 - 0.03) / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tEach Additional Shell:"):r_text("%.2fs", {data = {17 / 30 / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tFull:"):r_text("%.2fs", {data = {(-0.03 + mag * 17 / 30) / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tEnd delay (Cancelable):")
			self:row({ s = 0.81 }):l_text("\t\tPartial Reload:"):r_text("%.2fs", {data = {0.3 / reload_mul}})
			self:row({ s = 0.81 }):l_text("\t\tFull Reload:"):r_text("%.2fs", {data = {0.7 / reload_mul}})
		end
	end
	self:row({ h = 15 })
	self:row():l_text("Time To Empty:"):r_text("%.2fs", {data = {mag * rof - rof}})
end



function InventoryStatsPopup:_primaries_totalammo()
	local pickup = self._data.tweak.AMMO_PICKUP
	local ammo_data = self._data.ammo_data
	local skill_pickup = 1 + managers.player:upgrade_value("player", "pick_up_ammo_multiplier", 1) + managers.player:upgrade_value("player", "pick_up_ammo_multiplier_2", 1) - 2
	local ammo_pickup_min_mul = ammo_data and ammo_data.ammo_pickup_min_mul or skill_pickup
	local ammo_pickup_max_mul = ammo_data and ammo_data.ammo_pickup_max_mul or skill_pickup

	self:row():l_text("Index Values:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%d", {data = {self._data.base_stats.totalammo.index}})
	self:row({ s = 0.9 }):l_text("\tMod:"):r_text("%d", {data = {self._data.mods_stats.totalammo.index}})
	local bounded_total = math.clamp(self._data.base_stats.totalammo.index + self._data.mods_stats.totalammo.index, 1, #tweak_data.weapon.stats.total_ammo_mod)
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%d", {data = {bounded_total}})
	self:row({ h = 15 })
	
	self:row():l_text("Ammo Pickup Range:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%.2f - %.2f", {data = {pickup[1], pickup[2]}})
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%.2f - %.2f", {data = {pickup[1] * ammo_pickup_min_mul, pickup[2] * ammo_pickup_max_mul}})
	
	local damage = self._data.base_stats.damage.value + self._data.mods_stats.damage.value + self._data.skill_stats.damage.value
	local totalammo = self._data.base_stats.totalammo.value + self._data.mods_stats.totalammo.value + self._data.skill_stats.totalammo.value
	local mag = self._data.base_stats.magazine.value + self._data.mods_stats.magazine.value + self._data.skill_stats.magazine.value
	
	self:row({ h = 15 })
	self:row():l_text("Damage Potential:")
	self:row({ s = 0.9 }):l_text("\tPer Pickup (avg):"):r_text("%.1f", {data = {(damage * pickup[1] * ammo_pickup_min_mul + damage * pickup[2] * ammo_pickup_max_mul) / 2}})
	self:row({ s = 0.9 }):l_text("\tPer Magazine:"):r_text("%.1f", {data = {damage * mag}})
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%.1f", {data = {damage * totalammo}})
end



function InventoryStatsPopup:_primaries_fire_rate()
	local akimbo_mul = self._data.category == "akimbo" and 2 or 1
	local rof = 60 / (self._data.base_stats.fire_rate.value + self._data.mods_stats.fire_rate.value + self._data.skill_stats.fire_rate.value) / akimbo_mul
	local dmg = self._data.base_stats.damage.value + self._data.mods_stats.damage.value + self._data.skill_stats.damage.value
	local mag = self._data.base_stats.magazine.value + self._data.mods_stats.magazine.value + self._data.skill_stats.magazine.value
	local reload_not_empty = self._data.tweak.timers.reload_not_empty
	local reload_empty = self._data.tweak.timers.reload_empty
	
	self:row():l_text("DPS:"):r_text("%.1f", {data = {dmg / rof}})
	if reload_not_empty then
		if reload_not_empty < reload_empty then
			self:row():l_text("DPS (factoring reloads):"):r_text("%.1f", {data = {(dmg / rof) * ((mag - akimbo_mul) * rof) / ((mag - akimbo_mul) * rof + reload_not_empty)}})
		else
			self:row():l_text("DPS (factoring reloads):"):r_text("%.1f", {data = {(dmg / rof * (mag * rof)) / (mag * rof + reload_empty)}})
		end
	end
end



function InventoryStatsPopup:_primaries_damage()
	local damage_base = self._data.base_stats.damage.value / 10
	local damage_mod = self._data.mods_stats.damage.value / 10
	local damage_skill = self._data.skill_stats.damage.value / 10
	local damage_total = damage_base + damage_mod + damage_skill
	local ammo_data = self._data.ammo_data
	local pierces_shields = self._data.tweak.can_shoot_through_shield or (ammo_data and ammo_data.can_shoot_through_shield)
	local explosive = ammo_data and ammo_data.bullet_class == "InstantExplosiveBulletBase" or self._data.category == "grenade_launcher"
	
	self:row():l_text("Index Values:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%d", {data = {self._data.base_stats.damage.index}})
	self:row({ s = 0.9 }):l_text("\tMod:"):r_text("%d", {data = {self._data.mods_stats.damage.index}})
	local bounded_total = math.clamp(self._data.base_stats.damage.index + self._data.mods_stats.damage.index, 1, #tweak_data.weapon.stats.damage)
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%d", {data = {bounded_total}})
	--if self._data.tweak.stats_modifiers and self._data.tweak.stats_modifiers.damage then self:row():l_text("Innate Damage Multiplier:"):r_text("%0.2f", {data = {self._data.tweak.stats_modifiers.damage}}) end
	self:row({ h = 15 })
	
	if explosive then
		if self._data.name == "gre_m79" then self:row():l_text("Blast Radius:"):r_text("3.5m") end
		if self._data.name == "rpg7" then self:row():l_text("Blast Radius:"):r_text("5m") end
	else
		local difficulties = {
			{ id = "ok", name = "OK" },
			{ id = "dw", name = "DW", hp = 1.7, hs = 0.75 },
		}
		local enemies = {
			{ id = "fbi_swat", name = "FBI Swat (Green)", difficulty_override = { dw = { hp = tweak_data.character.fbi_swat.HEALTH_INIT, hs = tweak_data.character.fbi_swat.headshot_dmg_mul }}},
			{ id = "fbi_heavy_swat", name = "FBI Heavy Swat (Tan)"},
			{ id = "city_swat", name = "Murky / GenSec Elite (Gray)", difficulty_override = { dw = { hp = 24, hs = tweak_data.character.fbi_swat.HEALTH_INIT / 8 }}},
			{ id = "taser", name = "Taser", is_special = true },
			{ id = "shield", name = pierces_shields and "Shield (Piercing)" or "Shield", is_special = true , damage_mul = pierces_shields and .25 or 1 },
			{ id = "spooc", name = "Cloaker", is_special = true  },
		}

		local hs_mult = managers.player:upgrade_value("weapon", "passive_headshot_damage_multiplier", 1)
		local special_mult = managers.player:upgrade_value("weapon", "special_damage_taken_multiplier", 1)
		
		self:row():l_text("Headshots to kill:"):r_text("(OK / DW)")
		for _, data in ipairs(enemies) do
			local row = self:row({ s = 0.9 }):l_text("\t\t" .. data.name .. ":")
			for i, diff in ipairs(difficulties) do
				local hp = data.difficulty_override and data.difficulty_override[diff.id] and data.difficulty_override[diff.id].hp or (tweak_data.character[data.id].HEALTH_INIT * (diff.hp or 1))
				local hs = data.difficulty_override and data.difficulty_override[diff.id] and data.difficulty_override[diff.id].hs or (tweak_data.character[data.id].headshot_dmg_mul * (diff.hs or 1))
				local raw_damage = damage_total * (data.is_special and special_mult or 1) * (data.damage_mul or 1) * hs * hs_mult
				local adjusted_damage = math.ceil(math.max(raw_damage / (hp/512), 1)) * (hp/512)
				row:r_text("%2d (%.2f)", { no_trim = true, data = { math.ceil(hp / adjusted_damage), hp / adjusted_damage }})
				if i ~= #difficulties then
					row:r_text("/")
				end
			end
		end

		--Dozer special case
		for i, diff in ipairs(difficulties) do
			local hp = tweak_data.character.tank.HEALTH_INIT * (diff.hp or 1)
			local hs = tweak_data.character.tank.headshot_dmg_mul * (diff.hs or 1)
			local adjusted_body_damage = math.ceil(math.max(damage_total * special_mult / (hp/512), 1)) * (hp/512)
			local adjusted_hs_damage = math.ceil(math.max(damage_total * special_mult * hs * hs_mult / (hp/512), 1)) * (hp/512)
			local adjusted_armor_damage = math.ceil(damage_total * special_mult * 16.384) / 16.384
			local total_bullets = 0
			
			local is_dead
			local str = "%2d ("
			local str_data = {}
			for i, armor_hp in ipairs({ 15, 16 }) do
				if not is_dead then
					local tmp_hp = armor_hp
					
					while hp > 0 and tmp_hp > 0 do
						hp = hp - adjusted_body_damage
						tmp_hp = tmp_hp - adjusted_armor_damage
						total_bullets = total_bullets + 1
					end
					
					is_dead = hp <= 0
					str = str .. "%.2f" .. (is_dead and "" or " + ")
					table.insert(str_data, armor_hp / adjusted_armor_damage)
				end
			end
			
			if not is_dead then
				local bullets = hp / adjusted_hs_damage
				total_bullets = total_bullets + math.ceil(bullets)
				str = str .. "%.2f"
				table.insert(str_data, bullets)
			end
			table.insert(str_data, 1, total_bullets)
			
			self:row({ s = 0.9 }):l_text("\t\tBulldozer (" .. diff.name .. "):"):r_text(str .. ")", { no_trim = true, data = str_data })
		end
	end
	
	if self._data.category ~= "shotgun" then
		return
	else
		if not explosive then self:row({ h = 15 }) end
	end
	
	local near = self._data.tweak.damage_near / 100
	local far = self._data.tweak.damage_far / 100
	local near_mul = ammo_data and ammo_data.damage_near_mul or 1
	local far_mul = ammo_data and ammo_data.damage_far_mul or 1

	self:row():l_text("Shotgun Stats:")
	self:row({ s = 0.9 }):l_text("\tPellets:"):r_text("%d", {data = {ammo_data and ammo_data.rays or self._data.tweak.rays}})
	if explosive then
		self:row({ s = 0.9 }):l_text("\tBlast Radius:"):r_text("%dm", {data = {2}})
	end
	self:row({ s = 0.9 }):l_text("\tBase Falloff Range:"):r_text("%.1fm to %.1fm", {data = {near, near + far}})
	if near_mul ~= 1 or far_mul ~= 1 then
		self:row({ s = 0.9 }):l_text("\tTotal Falloff Range:"):r_text("%.1fm to %.1fm", {data = {near * near_mul, near * near_mul + far * far_mul}})
	end
end



function InventoryStatsPopup:_primaries_spread()
	local base_and_mod = (20 - (self._data.base_stats.spread.value + self._data.mods_stats.spread.value)) / 10
	local skill_value = self._data.skill_stats.spread.value
	local global_spread_mul = self._data.tweak.stats_modifiers and self._data.tweak.stats_modifiers.spread or 1
	local spread = self._data.tweak.spread
	
	local function DR(stance)
		local stance_and_skill = stance - skill_value
		if stance_and_skill >= 1 then return (stance_and_skill * global_spread_mul * base_and_mod) end
		return (1 / (2 - stance_and_skill) * global_spread_mul * base_and_mod)
	end
	
	self:row():l_text("Index Values:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%d", {data = {self._data.base_stats.spread.index}})
	self:row({ s = 0.9 }):l_text("\tMod:"):r_text("%d", {data = {self._data.mods_stats.spread.index}})
	local bounded_total = math.clamp(self._data.base_stats.spread.index + self._data.mods_stats.spread.index, 1, #tweak_data.weapon.stats.spread)
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%d", {data = {bounded_total}})
	self:row({ h = 15 })
	
	self:row():l_text("Base & Mod Multiplier:"):r_text("%.2f", {data = {base_and_mod}})
	if skill_value ~= 0 then self:row():l_text("Skill Additive Modifier:"):r_text("%.2f", {data = {skill_value * -1}}) end
	if global_spread_mul ~= 1 then self:row():l_text("Innate Spread Multiplier:"):r_text("%.2f", {data = {global_spread_mul}}) end
	self:row({ h = 15 })
	self:row():l_text("Stance Spread Multipliers (Total Spread):")
	self:row({ s = 0.9 }):l_text("\tADS:"):r_text("%.2f (%.2f)", {data = {spread.steelsight, DR(spread.steelsight)}})
	self:row({ s = 0.9 }):l_text("\tADS-Moving:"):r_text("%.2f (%.2f)", {data = {spread.moving_steelsight, DR(spread.moving_steelsight)}})
	self:row({ s = 0.9 }):l_text("\tStanding:"):r_text("%.2f (%.2f)", {data = {spread.standing, DR(spread.standing)}})
	self:row({ s = 0.9 }):l_text("\tStanding-Moving:"):r_text("%.2f (%.2f)", {data = {spread.moving_standing, DR(spread.moving_standing)}})
	self:row({ s = 0.9 }):l_text("\tCrouching:"):r_text("%.2f (%.2f)", {data = {spread.crouching, DR(spread.crouching)}})
	self:row({ s = 0.9 }):l_text("\tCrouching-Moving:"):r_text("%.2f (%.2f)", {data = {spread.moving_crouching, DR(spread.moving_crouching)}})
	-- self:row({ h = 15 })
	
	-- self:row():l_text("Zoom Index Values:")
	-- self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%d", {data = {self._data.base_stats.zoom.index}})
	-- self:row({ s = 0.9 }):l_text("\tMod:"):r_text("%d", {data = {self._data.mods_stats.zoom.index}})
	-- local bounded_total_zoom = math.clamp(self._data.base_stats.zoom.index + self._data.mods_stats.zoom.index, 1, #tweak_data.weapon.stats.zoom)
	-- self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%d", {data = {bounded_total_zoom}})
end



function InventoryStatsPopup:_primaries_recoil()
	local base_and_mod = (30 - (self._data.base_stats.recoil.value + self._data.mods_stats.recoil.value)) / 10
	local skill = (30 - (self._data.base_stats.recoil.value + self._data.mods_stats.recoil.value + self._data.skill_stats.recoil.value)) / 10 / base_and_mod
	local kick = self._data.tweak.kick
	local recoil_mul = base_and_mod * skill
	
	self:row():l_text("Index Values:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%d", {data = {self._data.base_stats.recoil.index}})
	self:row({ s = 0.9 }):l_text("\tMod:"):r_text("%d", {data = {self._data.mods_stats.recoil.index}})
	local bounded_total = math.clamp(self._data.base_stats.recoil.index + self._data.mods_stats.recoil.index, 1, #tweak_data.weapon.stats.recoil)
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%d", {data = {bounded_total}})
	self:row({ h = 15 })
	
	self:row():l_text("Base & Mod Multiplier:"):r_text("%.2f", {data = {base_and_mod}})
	self:row():l_text("Skill Multiplier:"):r_text("%.2f", {data = {skill}})
	self:row({ h = 15 })
	self:row():l_text("Base Kick Range:")
	self:row({ s = 0.9 }):l_text("\tVertical:"):r_text("%.2f to %.2f", {data = {kick.standing[1], kick.standing[2]}})
	self:row({ s = 0.9 }):l_text("\tHorizontal:"):r_text("%.2f to %.2f", {data = {kick.standing[3], kick.standing[4]}})
	self:row({ h = 15 })
	self:row():l_text("Total Kick Range:")
	self:row({ s = 0.9 }):l_text("\tVertical:"):r_text("%.2f to %.2f", {data = {kick.standing[1] * recoil_mul, kick.standing[2] * recoil_mul}})
	self:row({ s = 0.9 }):l_text("\tHorizontal:"):r_text("%.2f to %.2f", {data = {kick.standing[3] * recoil_mul, kick.standing[4] * recoil_mul}})
end



function InventoryStatsPopup:_primaries_concealment()
	if managers.blackmarket:equipped_weapon_slot(self._data.inventory_category) ~= self._data.inventory_slot then return end
	local conceal_crit_bonus = managers.player:critical_hit_chance() * 100
	local detection_time_multiplier = managers.blackmarket:get_suspicion_of_local_player()
	local detection_distance_multiplier = 1 / math.sqrt(detection_time_multiplier)
	
	self:row():l_text("Critical Hit Chance:"):r_text("%.0f%%", {data = {conceal_crit_bonus}})
	self:row({ h = 15 })
	self:row():l_text("Concealment Detection Stats:")
	self:row({ s = 0.9 }):l_text("\tTime Multiplier:"):r_text("%.2f", {data = {detection_time_multiplier}})
	self:row({ s = 0.9 }):l_text("\tDistance Multiplier:"):r_text("%.2f", {data = {detection_distance_multiplier}})
	
end



function InventoryStatsPopup:_primaries_suppression()
	if self._data.category == "grenade_launcher" then return end

	local panic_chance = self._data.tweak.panic_suppression_chance and self._data.tweak.panic_suppression_chance * 100
	local base_and_mod = (self._data.base_stats.suppression.value + self._data.mods_stats.suppression.value + 2) / 10
	local skill = managers.blackmarket:threat_multiplier(self._data.name, self._data.category, false)
	local global_suppression_mul = self._data.tweak.stats_modifiers and self._data.tweak.stats_modifiers.suppression or 1
	
	self:row():l_text("Index Values:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%d", {data = {self._data.base_stats.suppression.index}})
	self:row({ s = 0.9 }):l_text("\tMod:"):r_text("%d", {data = {self._data.mods_stats.suppression.index}})
	local bounded_total = math.clamp(self._data.base_stats.suppression.index + self._data.mods_stats.suppression.index, 1, #tweak_data.weapon.stats.suppression)
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%d", {data = {bounded_total}})
	self:row({ h = 15 })
	
	if panic_chance then self:row():l_text("Panic Chance (requires Disturbing the Peace):"):r_text("%d%%", {data = {panic_chance}}) end
	self:row():l_text("Base + Mod Suppression:"):r_text("%.2f", {data = {base_and_mod}})
	self:row():l_text("Skill Multiplier:"):r_text("%.2f", {data = {skill}})
	if global_suppression_mul ~= 1 then self:row():l_text("Innate Suppression Multiplier:"):r_text("%.2f", {data = {global_suppression_mul}}) end
	self:row({ h = 15 })
	self:row():l_text("Total Maximum Suppression:"):r_text("%.2f", {data = {base_and_mod * skill * global_suppression_mul}})
end



InventoryStatsPopup._secondaries_magazine = InventoryStatsPopup._primaries_magazine
InventoryStatsPopup._secondaries_totalammo = InventoryStatsPopup._primaries_totalammo
InventoryStatsPopup._secondaries_damage = InventoryStatsPopup._primaries_damage
InventoryStatsPopup._secondaries_fire_rate = InventoryStatsPopup._primaries_fire_rate
InventoryStatsPopup._secondaries_spread = InventoryStatsPopup._primaries_spread
InventoryStatsPopup._secondaries_recoil = InventoryStatsPopup._primaries_recoil
InventoryStatsPopup._secondaries_concealment = InventoryStatsPopup._primaries_concealment
InventoryStatsPopup._secondaries_suppression = InventoryStatsPopup._primaries_suppression



function InventoryStatsPopup:_melee_weapons_damage()
	local melee = managers.blackmarket:get_melee_weapon_data(self._data.name)
	local base_stats, mods_stats, skill_stats = managers.menu_component._blackmarket_gui:_get_melee_weapon_stats(self._data.name)
	local uncharged_damage = base_stats.damage.min_value + mods_stats.damage.min_value + skill_stats.damage.min_value
	local charged_damage = base_stats.damage.max_value + mods_stats.damage.max_value + skill_stats.damage.max_value
	local uncharged_kd = base_stats.damage_effect.min_value + mods_stats.damage_effect.min_value + skill_stats.damage_effect.min_value
	local charged_kd = base_stats.damage_effect.max_value + mods_stats.damage_effect.max_value + skill_stats.damage_effect.max_value
	local charge_time = base_stats.charge_time.value + mods_stats.charge_time.value + skill_stats.charge_time.value
	
	self:row():l_text("Attack Delay:"):r_text("%.2fs", {data = {melee.instant and 0 or melee.melee_damage_delay}})
	self:row():l_text("Cooldown:"):r_text("%.2fs", {data = {melee.repeat_expire_t}})
	if not melee.instant then self:row():l_text("Unequip Delay:"):r_text("%.2fs", {data = {melee.expire_t}}) end
	self:row({ h = 15 })
	if melee.instant then
		self:row():l_text("DPS:"):r_text("%.2fs", {data = {uncharged_damage / melee.repeat_expire_t}})
		self:row():l_text("KdPS:"):r_text("%.2fs", {data = {uncharged_kd / melee.repeat_expire_t}})
	else
		self:row():l_text("Uncharged DPS:"):r_text("%.2fs", {data = {uncharged_damage / melee.repeat_expire_t}})
		self:row():l_text("Charged DPS:"):r_text("%.2fs", {data = {charged_damage / (melee.repeat_expire_t + charge_time)}})
		self:row({ h = 15 })
		self:row():l_text("Uncharged KdPS:"):r_text("%.2fs", {data = {uncharged_kd / melee.repeat_expire_t}})
		self:row():l_text("Charged KdPS:"):r_text("%.2fs", {data = {charged_kd / (melee.repeat_expire_t + charge_time)}})
	end
end

InventoryStatsPopup._melee_weapons_damage_effect = InventoryStatsPopup._melee_weapons_damage
InventoryStatsPopup._melee_weapons_charge_time = InventoryStatsPopup._melee_weapons_damage
InventoryStatsPopup._melee_weapons_range = InventoryStatsPopup._melee_weapons_damage
InventoryStatsPopup._melee_weapons_concealment = InventoryStatsPopup._melee_weapons_damage



function InventoryStatsPopup:_armors_armor()
	local armor_tweak = tweak_data.blackmarket.armors[self._data.name]
	local player_tweak = tweak_data.player
	local health = player_tweak.damage.HEALTH_INIT * 10
	local health_mul = 1 + managers.player:upgrade_value("player", "health_multiplier", 1) + managers.player:upgrade_value("player", "passive_health_multiplier", 1) + managers.player:team_upgrade_value("health", "passive_multiplier", 1) - 3
	local speed = player_tweak.movement_state.standard.movement.speed
	local armor_mul = managers.player:mod_movement_penalty(managers.player:body_armor_value("movement", armor_tweak.upgrade_level, 1))
	local walking_mul = armor_mul + managers.player:upgrade_value("player", "walk_speed_multiplier", 1) + managers.player:upgrade_value("player", "movement_speed_multiplier", 1) - 2
	local running_mul = armor_mul + managers.player:upgrade_value("player", "run_speed_multiplier", 1) + managers.player:upgrade_value("player", "movement_speed_multiplier", 1) - 2
	local steelsight_mul = armor_mul + managers.player:upgrade_value("player", "steelsight_speed_multiplier", 1) + managers.player:upgrade_value("player", "movement_speed_multiplier", 1) - 2
	local crouch_mul = armor_mul + managers.player:upgrade_value("player", "crouch_speed_multiplier", 1) + managers.player:upgrade_value("player", "movement_speed_multiplier", 1) - 2
	
	self:row():l_text("Player Health:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%.1f", {data = {health}})
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%.1f", {data = {health * health_mul}})
	self:row({ h = 15 })
	self:row():l_text("Movement Speed:")
	self:row({ s = 0.9 }):l_text("\tWalking:"):r_text("%.3f m/s", {data = {speed.STANDARD_MAX * walking_mul / 100}})
	self:row({ s = 0.9 }):l_text("\tSprinting:"):r_text("%.3f m/s", {data = {speed.RUNNING_MAX * running_mul / 100}})
	self:row({ s = 0.9 }):l_text("\tCrouching:"):r_text("%.3f m/s", {data = {speed.CROUCHING_MAX * crouch_mul / 100}})
	self:row({ s = 0.9 }):l_text("\tAiming:"):r_text("%.3f m/s", {data = {managers.player:has_category_upgrade("player", "steelsight_normal_movement_speed") and (speed.STANDARD_MAX * walking_mul / 100) or (speed.STEELSIGHT_MAX * steelsight_mul / 100)}})
end

InventoryStatsPopup._armors_concealment = InventoryStatsPopup._armors_armor
InventoryStatsPopup._armors_movement = InventoryStatsPopup._armors_armor
InventoryStatsPopup._armors_dodge = InventoryStatsPopup._armors_armor
InventoryStatsPopup._armors_damage_shake = InventoryStatsPopup._armors_armor
InventoryStatsPopup._armors_stamina = InventoryStatsPopup._armors_armor



function InventoryStatsPopup:_mods_magazine()
	local index_stats = {}
	for _, stat in pairs(self._data.stat_table) do index_stats[stat.name] = self._data.stats and self._data.stats[stat.name] or 0 end
	self:row():l_text("Index Values:")
	
	if self._data.type == "sight" then self:row({ s = 0.9 }):l_text("\tZOOM"):r_text("%d", {data = {self._data.stats.zoom or 0}}) end
	for _, stat in pairs(self._data.stat_table) do
		if stat.name == "fire_rate" or stat.name == "magazine" then
			self:row({ s = 0.9 }):l_text("\t" .. utf8.to_upper(managers.localization:text("bm_menu_" .. stat.name))):r_text("N/A")
		else
			self:row({ s = 0.9 }):l_text("\t" .. utf8.to_upper(managers.localization:text("bm_menu_" .. stat.name))):r_text("%d", {data = {index_stats[stat.name]}})
		end
	end
end

InventoryStatsPopup._mods_totalammo = InventoryStatsPopup._mods_magazine
InventoryStatsPopup._mods_damage = InventoryStatsPopup._mods_magazine
InventoryStatsPopup._mods_fire_rate = InventoryStatsPopup._mods_magazine
InventoryStatsPopup._mods_spread = InventoryStatsPopup._mods_magazine
InventoryStatsPopup._mods_recoil = InventoryStatsPopup._mods_magazine
InventoryStatsPopup._mods_concealment = InventoryStatsPopup._mods_magazine
InventoryStatsPopup._mods_suppression = InventoryStatsPopup._mods_magazine