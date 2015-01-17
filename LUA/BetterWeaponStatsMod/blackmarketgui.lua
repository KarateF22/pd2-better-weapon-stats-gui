toggle_greater_precision = true --change true to false to make the mod off by default
toggle_index_stats = false --don't change this

BlackMarketGui.BASE_MARGIN = 10
BlackMarketGui.ELEMENT_MARGIN = 0
BlackMarketGui.FONT_SCALE = 1.0

local _blackmarketgui_function_ptr1 = BlackMarketGui.mouse_moved
local _blackmarketgui_function_ptr2 = BlackMarketGui._get_base_stats
local _blackmarketgui_function_ptr3 = BlackMarketGui._get_skill_stats
local _blackmarketgui_function_ptr4 = BlackMarketGui._get_mods_stats
local _blackmarketgui_function_ptr5 = BlackMarketGui.show_stats
local _blackmarketgui_function_ptr6 = BlackMarketGui._get_stats
local _blackmarketgui_function_ptr7 = BlackMarketGui._get_weapon_mod_stats



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
	if not toggle_greater_precision and not toggle_index_stats then return _blackmarketgui_function_ptr5(self) end

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
				if toggle_index_stats and not (stat.name == "magazine" or stat.name == "fire_rate") then
					based = base_stats[stat.name].index
					mod = mods_stats[stat.name].index
					value2 = based + mod
					skill = 0
				else
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
				end
				
				local decimals = (stat.name == "magazine" or stat.name == "totalammo" or stat.name == "concealment" or stat.name == "fire_rate" or toggle_index_stats) and "%0.0f" or "%0.2f"
				
				self._stats_texts[stat.name].equip:set_text(string.format(decimals, value2) or "")
				self._stats_texts[stat.name].base:set_text(string.format(decimals, based) or "")
				self._stats_texts[stat.name].mods:set_text((mods_stats[stat.name].value == 0 and "") or (mods_stats[stat.name].value > 0 and "+" or "") .. string.format(decimals, mod) or "")
				if toggle_index_stats then self._stats_texts[stat.name].skill:set_text("")
				elseif stat.name == "spread" then self._stats_texts[stat.name].skill:set_text("")
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
				local decimals = (stat.name == "magazine" or stat.name == "totalammo" or stat.name == "concealment" or toggle_index_stats) and "%0.0f" or "%0.2f"
				local equip2
				if toggle_index_stats then
					equip2 = equip - equip_skill_stats[stat.name].value
				else
					equip2 = equip
				end
				self._stats_texts[stat.name].equip:set_text(string.format(decimals, equip2))
				self._stats_texts[stat.name].base:set_text("")
				self._stats_texts[stat.name].mods:set_text("")
				self._stats_texts[stat.name].skill:set_text("")
				local value2
				if toggle_index_stats then
					value2 = value - skill_stats[stat.name].value
				else
					value2 = value
				end
				self._stats_texts[stat.name].total:set_text(string.format(decimals, value2))
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
			
			local decimals = (stat.name == "magazine" or stat.name == "totalammo" or stat.name == "concealment" or toggle_index_stats) and "%0.0f" or "%0.2f"
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
				break
			end
		end
	end
	local curr_stats = base_stats
	local index
	for _, mod in pairs( mod_stats ) do
		for _, stat in pairs( self._stats_shown ) do
			if mod.name then
				if stat.name == "magazine" then
					local ammo = tweak_factory[mod.name].stats.extra_ammo
					ammo = ammo and ammo + (tweak_data.weapon[weapon_name].stats.extra_ammo or 0)
					mod[stat.name] = ammo and tweak_data.weapon.stats.extra_ammo[ammo] or 0
				elseif stat.name == "totalammo" then
					local chosen_index = tweak_factory[mod.name].stats.total_ammo_mod or 0
					chosen_index = math.clamp(base_stats[stat.name].index + chosen_index, 1, #tweak_stats.total_ammo_mod)
					mod[stat.name] = base_stats[stat.name].value * tweak_stats.total_ammo_mod[chosen_index]
				else
					local chosen_index = tweak_factory[mod.name].stats[stat.name] or 0
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
						if modifier_stats and modifier_stats[stat.name] and not stat.offset and stat.name == "damage" then
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



function BlackMarketGui:_check_popup(x, y)
	local show_popup
	if self._rweapon_stats_panel:visible() and self._rweapon_stats_panel:inside(x, y) then
		for i, stat_row in ipairs(self._rweapon_stats_panel:children()) do
			if stat_row:visible() and stat_row:inside(x, y) then
				if self._stats_shown[i] then
					show_popup = true
					self:_update_wpn_stats_popup(i)
					break
				end
			end
		end
	end
	
	if self._mweapon_stats_panel:visible() and self._mweapon_stats_panel:inside(x, y) then
		for i, stat_row in ipairs(self._mweapon_stats_panel:children()) do
			if stat_row:visible() and stat_row:inside(x, y) then
				if self._mweapon_stats_shown[i] then
					show_popup = true
					self:_update_mwpn_stats_popup(i)
					break
				end
			end
		end
	end
	
	if self._armor_stats_panel:visible() and self._armor_stats_panel:inside(x, y) then
		for i, stat_row in ipairs(self._armor_stats_panel:children()) do
			if stat_row:visible() and stat_row:inside(x, y) then
				if self._armor_stats_shown[i] then
					show_popup = true
					self:_update_armor_stats_popup(i)
					break
				end
			end
		end
	end
	
	if not show_popup then
		self:_remove_stats_popup()
	end
end



function BlackMarketGui:_remove_stats_popup()
	if self._stats_popup then
		if alive(self._stats_popup) then
			for _, child in pairs(self._stats_popup:children()) do
				self._stats_popup:remove(child)
			end
		end
		
		self._panel:remove(self._stats_popup)
		self._stats_popup = nil
		self._stats_popup_current_stat = nil
	end
end



function BlackMarketGui:_create_stats_popup()
	local popup = self._panel:panel({
		name = "stats_popup",
		alpha = 1,
		w = 0,
		h = 0,
		layer = 10,
	})
	
	popup:rect({
		name = "bg",
		blend_mode = "normal",
		alpha = 1,
		color = Color(1, 0, 0, 0),
		layer = 50,
	})
	popup:rect({
		name = "left_border",
		blend_mode = "normal",
		w = 2,
		h = 0,
		x = 0,
		y = 0,
		color = Color.white,
		layer = 100,
	})
	popup:rect({
		name = "right_border",
		blend_mode = "normal",
		w = 2,
		h = 0,
		x = 0,
		y = 0,
		color = Color.white,
		layer = 100,
	})
	popup:rect({
		name = "top_border",
		blend_mode = "normal",
		w = 0,
		h = 2,
		x = 0,
		y = 0,
		color = Color.white,
		layer = 100,
	})
	popup:rect({
		name = "bottom_border",
		blend_mode = "normal",
		w = 0,
		h = 2,
		x = 0,
		y = 0,
		color = Color.white,
		layer = 100,
	})
	
	return popup
end



function BlackMarketGui:_setup_popup_panel(elements)
	local function format_text(text)
		for k, _ in text:gmatch("([0-9]+%.[0-9]+)") do
			text = text:gsub(k, string.format("%f", k):gsub('%.?0+$', ""))
		end
		return text
	end
	
	local max_label_width = 0
	local max_text_width = 0
	local components = {}

	for _, e in ipairs(elements or {}) do
		if e.label or e.format then
			local label, text
			
			if e.label then
				label = self._stats_popup:text({
					name = (e.name or "text") .. "_label",
					text = tostring(e.label):gsub("\t", "   "),
					align = "left",
					vertical = "center",
					w = 500,
					h = e.h or tweak_data.menu.pd2_small_font_size * self.FONT_SCALE,
					color = e.label_color or Color.white,
					font = tweak_data.menu.pd2_small_font,
					font_size = e.h or tweak_data.menu.pd2_small_font_size * self.FONT_SCALE,
					layer = 100,
				})
				local _, _, w, _ = label:text_rect()
				label:set_w(w)
				max_label_width = math.max(max_label_width, w)
			end
			
			if e.format then
				text = self._stats_popup:text({
					name = e.name or "text",
					text = format_text(string.format(e.format, unpack(e.args or {}))),
					align = "left",
					vertical = "center",
					horizontal = "right",
					w = 500,
					h = e.h or tweak_data.menu.pd2_small_font_size * self.FONT_SCALE,
					color = e.format_color or Color.white,
					font = tweak_data.menu.pd2_small_font,
					font_size = e.h or tweak_data.menu.pd2_small_font_size * self.FONT_SCALE,
					layer = 100,
				})
				local _, _, w, _ = text:text_rect()
				text:set_w(w)
				max_text_width = math.max(max_text_width, w)
			end
			
			table.insert(components, { type = "text", label = label, text = text })
		elseif e.type == "space" then
			table.insert(components, { type = "space", h = e.h or tweak_data.menu.pd2_small_font_size * self.FONT_SCALE })
		elseif e.type == "border" then
			local border = self._stats_popup:rect({
				name = e.name or "border",
				blend_mode = "normal",
				h = e.h or 1,
				color = e.color or Color.white,
				layer = 100,
			})
			
			table.insert(components, { type = "border", border = border, margin = e.margin or 0 })
		end
	end
	
	local offset = self.BASE_MARGIN
	local total_width = max_label_width + max_text_width + self.BASE_MARGIN * 3
	for _, comp in ipairs(components) do
		if comp.type == "text" then
			if comp.label then
				comp.label:set_top(offset)
				comp.label:set_left(self.BASE_MARGIN)
			end
			if comp.text then
				comp.text:set_top(offset)
				comp.text:set_right(total_width - self.BASE_MARGIN)
			end
			offset = offset + (comp.text and comp.text:h() or comp.label and comp.label:h() or 0) + self.ELEMENT_MARGIN
		elseif comp.type == "space" then
			offset = offset + comp.h
		elseif comp.type == "border" then
			offset = offset + comp.margin
			comp.border:set_top(offset - comp.border:h()/2)
			comp.border:set_w(total_width)
			offset = offset + comp.border:h() + comp.margin
		end
	end
	offset = offset + math.max(0, self.BASE_MARGIN - self.ELEMENT_MARGIN)
	
	self._stats_popup:set_visible(elements and #elements > 0)
	self._stats_popup:set_size(total_width, offset)
	self._stats_popup:set_right(self._stats_panel:x() - 10)
	self._stats_popup:set_y(self._panel:h()/2 - self._stats_popup:h()/2)
	
	self._stats_popup:child("bg"):set_size(total_width, offset)
	self._stats_popup:child("left_border"):set_h(offset)
	local right_border = self._stats_popup:child("right_border")
	right_border:set_h(offset)
	right_border:set_right(self._stats_popup:w())
	self._stats_popup:child("top_border"):set_w(total_width)
	local bottom_border = self._stats_popup:child("bottom_border")
	bottom_border:set_w(total_width)
	bottom_border:set_bottom(offset)
end



function BlackMarketGui:_update_wpn_stats_popup(stat_index, force_update)
	if self._stats_popup_current_stat ~= stat_index or not alive(self._stats_popup) or force_update then
		self:_remove_stats_popup()
		self._stats_popup = self:_create_stats_popup()
		self._stats_popup_current_stat = stat_index
		
		local weapon = managers.blackmarket:get_crafted_category_slot(self._slot_data.category, self._slot_data.slot)
		local blueprint = managers.blackmarket:get_weapon_blueprint(self._slot_data.category, self._slot_data.slot)
		local name = weapon and weapon.weapon_id or self._slot_data.name
		local tweak = tweak_data.weapon[name]
		local category = tweak.category
		
		
		if name == "saw" or name == "saw_secondary" then
			self:_setup_popup_panel()
		elseif self._stats_shown[stat_index].name == "magazine" then
			self:_setup_weapon_stat_magazine(weapon, tweak, name, category, blueprint)
		elseif self._stats_shown[stat_index].name == "totalammo" then
			self:_setup_weapon_stat_totalammo(weapon, tweak, name, category, blueprint)
		elseif self._stats_shown[stat_index].name == "fire_rate" then
			self:_setup_weapon_stat_fire_rate(weapon, tweak, name, category, blueprint)
		elseif self._stats_shown[stat_index].name == "damage" then
			self:_setup_weapon_stat_damage(weapon, tweak, name, category, blueprint)
		elseif self._stats_shown[stat_index].name == "spread" then
			self:_setup_weapon_stat_spread(weapon, tweak, name, category, blueprint)
		elseif self._stats_shown[stat_index].name == "recoil" then
			self:_setup_weapon_stat_recoil(weapon, tweak, name, category, blueprint)
		elseif self._stats_shown[stat_index].name == "concealment" then
			self:_setup_weapon_stat_concealment(weapon, tweak, name, category, blueprint)
		elseif self._stats_shown[stat_index].name == "suppression" then
			self:_setup_weapon_stat_suppression(weapon, tweak, name, category, blueprint)
		end 
	end
end



function BlackMarketGui:_setup_weapon_stat_magazine(weapon, tweak, name, category, blueprint)
	local elements = {}
	
	local base_stats, mods_stats, skill_stats = self:_get_stats(name, self._slot_data.category, self._slot_data.slot)
	local reload_mul = managers.blackmarket:_convert_add_to_mul(1 + (1 - managers.player:upgrade_value(category, "reload_speed_multiplier", 1)) + (1 - managers.player:upgrade_value("weapon", "passive_reload_speed_multiplier", 1)) + (1 - managers.player:upgrade_value(name, "reload_speed_multiplier", 1)))
	local mag = base_stats["magazine"].value + mods_stats["magazine"].value + skill_stats["magazine"].value
	local reload_not_empty = tweak.timers and tweak.timers.reload_not_empty
	local reload_empty = tweak.timers and tweak.timers.reload_empty
	local rof = 60 / (base_stats["fire_rate"].value + mods_stats["fire_rate"].value + skill_stats["fire_rate"].value)
	
	if reload_not_empty and reload_empty then
		if reload_not_empty ~= reload_empty then
			table.insert(elements, {label = "Tactical Reload:", format = "%0.2fs", args = {reload_not_empty / reload_mul}})
			table.insert(elements, {label = "Empty Reload:", format = "%0.2fs", args = {reload_empty / reload_mul}})
		else
			table.insert(elements, {label = "Reload:", format = "%0.2fs", args = {reload_not_empty / reload_mul}})
		end
	else
		if name == "striker" then
			table.insert(elements, {label = "Single Shell Reload:", format = "%0.2fs", args = {1 / reload_mul}})
			table.insert(elements, {label = "Each Additional Shell:", format = "%0.2fs", args = {18 / 30 / reload_mul}})
			table.insert(elements, {label = "Full Reload:", format = "%0.2fs", args = {(12 / 30 + mag * 18 / 30) / reload_mul}})
			table.insert(elements, {label = "End delay (Cancelable):", format = "%0.2fs", args = {0.4 / reload_mul}})
		else
			table.insert(elements, {label = "Single Shell Reload:", format = "%0.2fs", args = {(17 / 30 - 0.03) / reload_mul}})
			table.insert(elements, {label = "Each Additional Shell:", format = "%0.2fs", args = {17 / 30 / reload_mul}})
			table.insert(elements, {label = "Full Reload:", format = "%0.2fs", args = {(-0.03 + mag * 17 / 30) / reload_mul}})
			table.insert(elements, {label = "End delay (Cancelable):"})
			table.insert(elements, {label = "    Partial Reload:", format = "%0.2fs", args = {0.3 / reload_mul}})
			table.insert(elements, {label = "    Full Reload:", format = "%0.2fs", args = {0.7 / reload_mul}})
		end
	end
	table.insert(elements, {label = "Time To Empty:", format = "%0.2fs", args = {mag * rof - rof}})
	
	self:_setup_popup_panel(elements)
end



function BlackMarketGui:_setup_weapon_stat_totalammo(weapon, tweak, name, category, blueprint)
	local elements = {}
	local pickup = tweak.AMMO_PICKUP
	local factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(name)
	local ammo_data = factory_id and blueprint and managers.weapon_factory:get_ammo_data_from_weapon(factory_id, blueprint)
	local skill_pickup = 1 + managers.player:upgrade_value("player", "pick_up_ammo_multiplier", 1) + managers.player:upgrade_value("player", "pick_up_ammo_multiplier_2", 1) - 2
	local ammo_pickup_min_mul = ammo_data and ammo_data.ammo_pickup_min_mul or skill_pickup
	local ammo_pickup_max_mul = ammo_data and ammo_data.ammo_pickup_max_mul or skill_pickup
	
	table.insert(elements, {label = "Base Ammo Pickup Range:", format = "%0.2f to %0.2f", args = {pickup[1], pickup[2]}})
	table.insert(elements, {label = "Modified Ammo Pickup Range:", format = "%0.2f to %0.2f", args = {pickup[1] * ammo_pickup_min_mul, pickup[2] * ammo_pickup_max_mul}})
	
	self:_setup_popup_panel(elements)
end



function BlackMarketGui:_setup_weapon_stat_fire_rate(weapon, tweak, name, category, blueprint)
	local elements = {}
	local base_stats, mods_stats, skill_stats = self:_get_stats(name, self._slot_data.category, self._slot_data.slot)
	local akimbo_mul = category == "akimbo" and 2 or 1
	local rof = 60 / (base_stats["fire_rate"].value + mods_stats["fire_rate"].value + skill_stats["fire_rate"].value) / akimbo_mul
	local dmg = base_stats["damage"].value + mods_stats["damage"].value + skill_stats["damage"].value
	local mag = base_stats["magazine"].value + mods_stats["magazine"].value + skill_stats["magazine"].value
	local reload_not_empty = tweak.timers.reload_not_empty
	local reload_empty = tweak.timers.reload_empty
	
	table.insert(elements, {label = "DPS:", format = "%0.1f", args = {dmg / rof}})
	if reload_not_empty then
		if reload_not_empty < reload_empty then
			table.insert(elements, {label = "DPS (factoring reloads):", format = "%0.1f", args = {(dmg / rof) * ((mag - akimbo_mul) * rof) / ((mag - akimbo_mul) * rof + reload_not_empty)}})
		else
			table.insert(elements, {label = "DPS (factoring reloads):", format = "%0.1f", args = {(dmg / rof * (mag * rof)) / (mag * rof + reload_empty)}})
		end
	end
	
	self:_setup_popup_panel(elements)
end



function BlackMarketGui:_setup_weapon_stat_damage(weapon, tweak, name, category, blueprint)
	local elements = {}
	local base_stats, mods_stats, skill_stats = self:_get_stats(name, self._slot_data.category, self._slot_data.slot)
	local damage_no_hs = base_stats["damage"].value + mods_stats["damage"].value + skill_stats["damage"].value
	local damage = damage_no_hs * managers.player:upgrade_value("weapon", "passive_headshot_damage_multiplier", 1)
	local character = tweak_data.character
	local dozer_outer = math.ceil(150 / (math.ceil(damage_no_hs * 16.384) / 16.384))
	local dozer_inner = math.ceil(160 / (math.ceil(damage_no_hs * 16.384) / 16.384))
	local damage_to_remove_faceplates = (dozer_outer + dozer_inner) * damage_no_hs
	local dozer_ok = math.ceil(512 / math.ceil(512 / ((character["tank"].HEALTH_INIT * 10 - damage_to_remove_faceplates) / (damage * character["tank"].headshot_dmg_mul))))
	local dozer_dw = math.ceil(512 / math.ceil(512 / ((character["tank"].HEALTH_INIT * 10 * 1.7 - damage_to_remove_faceplates) / (damage * character["tank"].headshot_dmg_mul * .75))))
	local enemies = {
		{id = "fbi_swat", name = "FBI Swat (Green)"},
		--{id = "city_swat", name = "GenSec Elite (Gray)"}, --this is broken
		{id = "fbi_heavy_swat", name = "FBI Heavy Swat (Tan)"},
		{id = "shield", name = "Shield"},
		{id = "taser", name = "Taser"},
		{id = "spooc", name = "Cloaker"},
		--{id = "tank", name = "Bulldozer"}, --manually overriden for faceplate calcs
	}
	
	table.insert(elements, {label = "Headshots to kill on Overkill:"})
	for _, data in ipairs(enemies) do
		table.insert(elements, {label = "    " .. data.name .. ":", format = "%d", args = {math.ceil(512 / math.ceil(512 / (character[data.id].HEALTH_INIT * 10 / (damage * character[data.id].headshot_dmg_mul))))}})
	end
	table.insert(elements, {label = "    Bulldozer :", format = "(%d+%d+%d) %d", args = {dozer_outer, dozer_inner, dozer_ok, dozer_outer + dozer_inner + dozer_ok}})
	table.insert(elements, {label = "Headshots to kill on Death Wish:"})
	table.insert(elements, {label = "    GenSec Elite (Gray):", format = "%d", args = {math.ceil(512 / math.ceil(512 / (240 / (damage * 1.625))))}})
	for _, data in ipairs(enemies) do
		if data.id ~= "fbi_swat" then
			table.insert(elements, {label = "    " .. data.name .. ":", format = "%d", args = {math.ceil(512 / math.ceil(512 / (character[data.id].HEALTH_INIT * 10 * 1.7 / (damage * character[data.id].headshot_dmg_mul * .75))))}})
		end
	end
	table.insert(elements, {label = "    Bulldozer:", format = "(%d+%d+%d) %d", args = {dozer_outer, dozer_inner, dozer_dw, dozer_outer + dozer_inner + dozer_dw}})
	self:_setup_popup_panel(elements)
end



function BlackMarketGui:_setup_weapon_stat_spread(weapon, tweak, name, category, mods)
	local elements = {}
	local base_stats, mods_stats, skill_stats = self:_get_stats(name, self._slot_data.category, self._slot_data.slot)
	local base_and_mod = (20 - (base_stats["spread"].value + mods_stats["spread"].value)) / 10
	local skill_value = skill_stats["spread"].value
	local global_spread_mul = tweak.stats_modifiers and tweak.stats_modifiers["spread"] or 1
	local spread = tweak.spread
	
	local function DR(stance)
		local stance_and_skill = stance - skill_value
		if stance_and_skill >= 1 then return (stance_and_skill * global_spread_mul * base_and_mod) end
		return (1 / (2 - stance_and_skill) * global_spread_mul * base_and_mod)
	end
	
	table.insert(elements, {label = "Base + Mod Multiplier:", format = "%0.2f", args = {base_and_mod}})
	if skill_value ~= 0 then table.insert(elements, {label = "Skill Additive Modifier:", format = "%0.2f", args = {skill_value * -1}}) end
	if global_spread_mul ~= 1 then table.insert(elements, {label = "Innate Spread Multiplier:", format = "%0.2f", args = {global_spread_mul}}) end
	table.insert(elements, {label = "Stance Spread Multipliers (Total Spread):"})
	table.insert(elements, {label = "    ADS:", format = "%0.2f (%0.2f)", args = {spread.steelsight, DR(spread.steelsight)}})
	table.insert(elements, {label = "    ADS-Moving:", format = "%0.2f (%0.2f)", args = {spread.moving_steelsight, DR(spread.moving_steelsight)}})
	table.insert(elements, {label = "    Standing:", format = "%0.2f (%0.2f)", args = {spread.standing, DR(spread.standing)}})
	table.insert(elements, {label = "    Standing-Moving:", format = "%0.2f (%0.2f)", args = {spread.moving_standing, DR(spread.moving_standing)}})
	table.insert(elements, {label = "    Crouching:", format = "%0.2f (%0.2f)", args = {spread.crouching, DR(spread.crouching)}})
	table.insert(elements, {label = "    Crouching-Moving:", format = "%0.2f (%0.2f)", args = {spread.moving_crouching, DR(spread.moving_crouching)}})
	
	self:_setup_popup_panel(elements)
end



function BlackMarketGui:_setup_weapon_stat_recoil(weapon, tweak, name, category, blueprint)
	local elements = {}
	local base_stats, mods_stats, skill_stats = self:_get_stats(name, self._slot_data.category, self._slot_data.slot)
	local base_and_mod = (30 - (base_stats["recoil"].value + mods_stats["recoil"].value)) / 10
	local skill = (30 - (base_stats["recoil"].value + mods_stats["recoil"].value + skill_stats["recoil"].value)) / 10 / base_and_mod
	local kick = tweak.kick
	local recoil_mul = base_and_mod * skill
	
	table.insert(elements, {label = "Base + Mod Multiplier:", format = "%0.2f", args = {base_and_mod}})
	table.insert(elements, {label = "Skill Multiplier:", format = "%0.2f", args = {skill}})
	table.insert(elements, {label = "Base Vertical Kick Range:", format = "%0.2f to %0.2f", args = {kick.standing[1], kick.standing[2]}})
	table.insert(elements, {label = "Base Horizontal Kick Range:", format = "%0.2f to %0.2f", args = {kick.standing[3], kick.standing[4]}})
	table.insert(elements, {label = "Total Vertical Kick Range:", format = "%0.2f to %0.2f", args = {kick.standing[1] * recoil_mul, kick.standing[2] * recoil_mul}})
	table.insert(elements, {label = "Total Horizontal Kick Range:", format = "%0.2f to %0.2f", args = {kick.standing[3] * recoil_mul, kick.standing[4] * recoil_mul}})

	self:_setup_popup_panel(elements)
end


function BlackMarketGui:_setup_weapon_stat_concealment(weapon, tweak, name, category, blueprint)
	local elements = {}
	if name == "gre_m79" then table.insert(elements, {label = "Blast Radius:", format = "%0.1fm", args = {3.5}}) end
	if category ~= "shotgun" then return self:_setup_popup_panel(elements) end
	
	local factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(name)
	local ammo_data = factory_id and blueprint and managers.weapon_factory:get_ammo_data_from_weapon(factory_id, blueprint)
	local near = tweak.damage_near / 100
	local far = tweak.damage_far / 100
	local near_mul = ammo_data and ammo_data.damage_near_mul or 1
	local far_mul = ammo_data and ammo_data.damage_far_mul or 1

	if ammo_data and ammo_data.bullet_class == "InstantExplosiveBulletBase" then
		table.insert(elements, {label = "Blast Radius:", format = "%dm", args = {2}})
	else
		table.insert(elements, {label = "Shotgun Pellets:", format = "%d", args = {ammo_data and ammo_data.rays or tweak.rays}})
	end
	table.insert(elements, {label = "Base Falloff Starts:", format = "%0.2fm", args = {near}})
	table.insert(elements, {label = "Base Falloff Ends:", format = "%0.2fm", args = {near + far}})
	if near_mul ~= 1 or far_mul ~= 1 then
		table.insert(elements, {label = "Modified Falloff Starts:", format = "%0.2fm", args = {near * near_mul}})
		table.insert(elements, {label = "Modified Falloff Ends:", format = "%0.2fm", args = {near * near_mul + far * far_mul}})
	end
	
	self:_setup_popup_panel(elements)
end



function BlackMarketGui:_setup_weapon_stat_suppression(weapon, tweak, name, category, blueprint)
	if name == "gre_m79" then return end
	local elements = {}
	local panic_chance = tweak.panic_suppression_chance and tweak.panic_suppression_chance * 100
	local base_stats, mods_stats, skill_stats = self:_get_stats(name, self._slot_data.category, self._slot_data.slot)
	local base_and_mod = (base_stats["suppression"].value + mods_stats["suppression"].value + 2) / 10
	local skill = managers.blackmarket:threat_multiplier(name, category, false)
	local global_suppression_mul = tweak.stats_modifiers and tweak.stats_modifiers["suppression"] or 1
	
	if panic_chance then table.insert(elements, {label = "Panic Chance (requires Disturbing the Peace):", format = "%d%%", args = {panic_chance}}) end
	table.insert(elements, {label = "Base + Mod Suppression:", format = "%0.2f", args = {base_and_mod}})
	table.insert(elements, {label = "Skill Multiplier:", format = "%0.2f", args = {skill}})
	if global_suppression_mul ~= 1 then table.insert(elements, {label = "Innate Suppression Multiplier:", format = "%0.2f", args = {global_suppression_mul}}) end
	table.insert(elements, {label = "Total Maximum Suppression:", format = "%0.2f", args = {base_and_mod * skill * global_suppression_mul}})
	self:_setup_popup_panel(elements)
end



function BlackMarketGui:_update_mwpn_stats_popup(stat_index, force_update)
	if self._stats_popup_current_stat ~= stat_index or not alive(self._stats_popup) or force_update then
		self:_remove_stats_popup()
		self._stats_popup = self:_create_stats_popup()
		self._stats_popup_current_stat = stat_index
		
		local melee = managers.blackmarket:get_melee_weapon_data(self._slot_data.name)
		
		if self._mweapon_stats_shown[stat_index].name == "damage" then
			self:_setup_melee_weapon_stat_damage(melee)
		elseif self._mweapon_stats_shown[stat_index].name == "damage_effect" then
			self:_setup_melee_weapon_stat_damage_effect(melee)
		elseif self._mweapon_stats_shown[stat_index].name == "charge_time" then
			self:_setup_melee_weapon_stat_charge_time(melee)
		elseif self._mweapon_stats_shown[stat_index].name == "range" then
			self:_setup_melee_weapon_stat_range(melee)
		elseif self._mweapon_stats_shown[stat_index].name == "concealment" then
			self:_setup_melee_weapon_stat_concealment(melee)
		end 
	end
end



function BlackMarketGui:_setup_melee_weapon_stat_damage(melee)
	local elements = {}
	
	table.insert(elements, {label = "Attack Delay:", format = "%0.2fs", args = {melee.instant and 0 or melee.melee_damage_delay}})
	table.insert(elements, {label = "Cooldown:", format = "%0.2fs", args = {melee.repeat_expire_t}})
	if not melee.instant then table.insert(elements, {label = "Unequip Delay:", format = "%0.2fs", args = {melee.expire_t}}) end
	--table.insert(elements, {type = "space"})
	
	self:_setup_popup_panel(elements)
end



function BlackMarketGui:_setup_melee_weapon_stat_damage_effect(melee)
	self:_setup_melee_weapon_stat_damage(melee)
end



function BlackMarketGui:_setup_melee_weapon_stat_charge_time(melee)
	self:_setup_melee_weapon_stat_damage(melee)
end



function BlackMarketGui:_setup_melee_weapon_stat_range(melee)
	self:_setup_melee_weapon_stat_damage(melee)
end



function BlackMarketGui:_setup_melee_weapon_stat_concealment(melee)
	self:_setup_melee_weapon_stat_damage(melee)
end



function BlackMarketGui:_update_armor_stats_popup(stat_index, force_update)
	if self._stats_popup_current_stat ~= stat_index or not alive(self._stats_popup) or force_update then
		self:_remove_stats_popup()
		self._stats_popup = self:_create_stats_popup()
		self._stats_popup_current_stat = stat_index
		
		local armor_tweak = tweak_data.blackmarket.armors[self._slot_data.name]
		local player_tweak = tweak_data.player
		
		if self._armor_stats_shown[stat_index].name == "armor" then
			self:_setup_armor_stat_armor(armor_tweak, player_tweak)
		elseif self._armor_stats_shown[stat_index].name == "concealment" then
			self:_setup_armor_stat_concealment(armor_tweak, player_tweak)
		elseif self._armor_stats_shown[stat_index].name == "movement" then
			self:_setup_armor_stat_movement(armor_tweak, player_tweak)
		elseif self._armor_stats_shown[stat_index].name == "dodge" then
			self:_setup_armor_stat_dodge(armor_tweak, player_tweak)
		elseif self._armor_stats_shown[stat_index].name == "damage_shake" then
			self:_setup_armor_stat_damage_shake(armor_tweak, player_tweak)
		elseif self._armor_stats_shown[stat_index].name == "stamina" then
			self:_setup_armor_stat_stamina(armor_tweak, player_tweak)
		end 
	end
end



function BlackMarketGui:_setup_armor_stat_armor(armor_tweak, player_tweak)
	local elements = {}
	local health = player_tweak.damage.HEALTH_INIT * 10
	local health_mul = 1 + managers.player:upgrade_value("player", "health_multiplier", 1) + managers.player:upgrade_value("player", "passive_health_multiplier", 1) + managers.player:team_upgrade_value("health", "passive_multiplier", 1) - 3
	local speed = player_tweak.movement_state.standard.movement.speed
	local armor_mul = managers.player:mod_movement_penalty(managers.player:body_armor_value("movement", armor_tweak.upgrade_level, 1))
	local walking_mul = armor_mul + managers.player:upgrade_value("player", "walk_speed_multiplier", 1) + managers.player:upgrade_value("player", "movement_speed_multiplier", 1) - 2
	local running_mul = armor_mul + managers.player:upgrade_value("player", "run_speed_multiplier", 1) + managers.player:upgrade_value("player", "movement_speed_multiplier", 1) - 2
	local steelsight_mul = armor_mul + managers.player:upgrade_value("player", "steelsight_speed_multiplier", 1) + managers.player:upgrade_value("player", "movement_speed_multiplier", 1) - 2
	local crouch_mul = armor_mul + managers.player:upgrade_value("player", "crouch_speed_multiplier", 1) + managers.player:upgrade_value("player", "movement_speed_multiplier", 1) - 2
	
	table.insert(elements, {label = "Base Player Health:", format = "%0.1f", args = {health}})
	table.insert(elements, {label = "Total Player Health:", format = "%0.1f", args = {health * health_mul}})
	table.insert(elements, {label = "Walk Speed:", format = "%0.3f m/s", args = {speed.STANDARD_MAX * walking_mul / 100}})
	table.insert(elements, {label = "Sprint Speed:", format = "%0.3f m/s", args = {speed.RUNNING_MAX * running_mul / 100}})
	table.insert(elements, {label = "Crouch Speed:", format = "%0.3f m/s", args = {speed.CROUCHING_MAX * crouch_mul / 100}})
	table.insert(elements, {label = "ADS Speed:", format = "%0.3f m/s", args = {managers.player:has_category_upgrade("player", "steelsight_normal_movement_speed") and (speed.STANDARD_MAX * walking_mul / 100) or (speed.STEELSIGHT_MAX * steelsight_mul / 100)}})
	
	self:_setup_popup_panel(elements)
end



function BlackMarketGui:_setup_armor_stat_concealment(armor_tweak, player_tweak)
	self:_setup_armor_stat_armor(armor_tweak, player_tweak)
end



function BlackMarketGui:_setup_armor_stat_movement(armor_tweak, player_tweak)
	self:_setup_armor_stat_armor(armor_tweak, player_tweak)
end



function BlackMarketGui:_setup_armor_stat_dodge(armor_tweak, player_tweak)
	self:_setup_armor_stat_armor(armor_tweak, player_tweak)
end



function BlackMarketGui:_setup_armor_stat_damage_shake(armor_tweak, player_tweak)
	self:_setup_armor_stat_armor(armor_tweak, player_tweak)
end



function BlackMarketGui:_setup_armor_stat_stamina(armor_tweak, player_tweak)
	self:_setup_armor_stat_armor(armor_tweak, player_tweak)
end