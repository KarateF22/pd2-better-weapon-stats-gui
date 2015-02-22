if toggle_greater_precision then
	toggle_greater_precision = false
	toggle_index_stats = true
elseif toggle_index_stats then
	toggle_greater_precision = false
	toggle_index_stats = false
else
	toggle_greater_precision = true
	toggle_index_stats = false
end
managers.menu_component._blackmarket_gui:reload()