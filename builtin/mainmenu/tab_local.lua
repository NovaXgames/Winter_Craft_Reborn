-- Wintercraft Reborn
-- Copyright (C) 2014 sapier
-- SPDX-License-Identifier: LGPL-2.1-or-later


local current_game, singleplayer_refresh_gamebar
local valid_disabled_settings = {
	["enable_damage"]=true,
	["creative_mode"]=true,
	["enable_server"]=true,
}

-- Name and port stored to persist when updating the formspec
local current_name = core.settings:get("name")
local current_port = core.settings:get("port")
local world_selector_open = false
local selected_mode = core.settings:get("wintercraft_last_mode") or "survival"

local MENU_MODE_SETTINGS = {
	story = {
		creative_mode = false,
		enable_damage = false,
	},
	survival = {
		creative_mode = false,
		enable_damage = true,
	},
	creative = {
		creative_mode = true,
		enable_damage = false,
	},
}

local MODE_LABELS = {
	story = fgettext("Story"),
	survival = fgettext("Survival"),
	creative = fgettext("Creative"),
}

if not MENU_MODE_SETTINGS[selected_mode] then
	selected_mode = "survival"
end

local function wc_texture(name)
	return core.formspec_escape(defaulttexturedir .. name)
end

local MODE_CARD_TEXTURES = {
	story = "wintercraft_story_button1.png",
	survival = "wintercraft_survival_button1.png",
	creative = "wintercraft_creative_button1.png",
}

local WC_ACTION_ASPECTS = {
	main_menu = 205 / 44,
	delete = 180 / 44,
	select_mods = 230 / 44,
	new = 165 / 44,
	new_world = 210 / 44,
	play_game = 220 / 44,
}

local function wc_mode_card(mode)
	return wc_texture(MODE_CARD_TEXTURES[mode] or MODE_CARD_TEXTURES.survival)
end

local function wc_action_button(id, name, x, y, w, h)
	if w == nil then
		w = (WC_ACTION_ASPECTS[id] or (175 / 44)) * h
	end
	return "image_button[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";" ..
		wc_texture("wintercraft_btn_" .. id .. "_1.png") .. ";" .. name ..
		";;true;false;" .. wc_texture("wintercraft_btn_" .. id .. "_2.png") .. "]"
end

local function set_menu_mode(mode)
	local settings = MENU_MODE_SETTINGS[mode]
	if not settings then
		return
	end

	selected_mode = mode
	core.settings:set("wintercraft_last_mode", mode)
	core.settings:set_bool("creative_mode", settings.creative_mode)
	core.settings:set_bool("enable_damage", settings.enable_damage)
	core.settings:set_bool("enable_server", false)
end

local function get_mode_label()
	return MODE_LABELS[selected_mode] or MODE_LABELS.survival
end

-- Currently chosen game in gamebar for theming and filtering
function current_game()
	local gameid = core.settings:get("menu_last_game")
	local game = gameid and pkgmgr.find_by_gameid(gameid)
	-- Fall back to first game installed if one exists.
	if not game and #pkgmgr.games > 0 then

		-- If devtest is the first game in the list and there is another
		-- game available, pick the other game instead.
		local picked_game
		if pkgmgr.games[1].id == "devtest" and #pkgmgr.games > 1 then
			picked_game = 2
		else
			picked_game = 1
		end

		game = pkgmgr.games[picked_game]
		gameid = game.id
		core.settings:set("menu_last_game", gameid)
	end

	return game
end

-- Apply menu changes from given game
function apply_game(game)
	core.settings:set("menu_last_game", game.id)
	menudata.worldlist:set_filtercriteria(game.id)

	mm_game_theme.set_engine(true)

	local index = filterlist.get_current_index(menudata.worldlist,
		tonumber(core.settings:get("mainmenu_last_selected_world")))
	if not index or index < 1 then
		local selected = core.get_textlist_index("sp_worlds")
		if selected ~= nil and selected < #menudata.worldlist:get_list() then
			index = selected
		else
			index = #menudata.worldlist:get_list()
		end
	end
	menu_worldmt_legacy(index)
end

function singleplayer_refresh_gamebar()

	local old_bar = ui.find_by_name("game_button_bar")
	if old_bar ~= nil then
		old_bar:delete()
	end

	-- Hide gamebar if no games are installed
	if #pkgmgr.games == 0 then
		return false
	end

	local function game_buttonbar_button_handler(fields)
		for _, game in ipairs(pkgmgr.games) do
			if fields["game_btnbar_" .. game.id] then
				apply_game(game)
				return true
			end
		end
	end

	local TOUCH_GUI = core.settings:get_bool("touch_gui")

	local gamebar_pos_y = MAIN_TAB_H
		+ TABHEADER_H -- tabheader included in formspec size
		+ (TOUCH_GUI and GAMEBAR_OFFSET_TOUCH or GAMEBAR_OFFSET_DESKTOP)

	local btnbar = buttonbar_create(
			"game_button_bar",
			{x = 0, y = gamebar_pos_y},
			{x = MAIN_TAB_W, y = GAMEBAR_H},
			"#000000",
			game_buttonbar_button_handler)

	for _, game in ipairs(pkgmgr.games) do
		local btn_name = "game_btnbar_" .. game.id

		local image = nil
		local text = nil
		local tooltip = core.formspec_escape(game.title)

		if (game.menuicon_path or "") ~= "" then
			image = core.formspec_escape(game.menuicon_path)
		else
			local part1 = game.id:sub(1,5)
			local part2 = game.id:sub(6,10)
			local part3 = game.id:sub(11)

			text = part1 .. "\n" .. part2
			if part3 ~= "" then
				text = text .. "\n" .. part3
			end
		end
		btnbar:add_button(btn_name, text, image, tooltip)
	end

	local plus_image = core.formspec_escape(defaulttexturedir .. "plus.png")
	btnbar:add_button("game_open_cdb", "", plus_image, fgettext("Install games from ContentDB"))
	return true
end

local function get_disabled_settings(game)
	if not game then
		return {}
	end

	local gameconfig = Settings(game.path .. "/game.conf")
	local disabled_settings = {}
	if gameconfig then
		local disabled_settings_str = (gameconfig:get("disabled_settings") or ""):split()
		for _, value in pairs(disabled_settings_str) do
			local state = false
			value = value:trim()
			if string.sub(value, 1, 1) == "!" then
				state = true
				value = string.sub(value, 2)
			end
			if valid_disabled_settings[value] then
				disabled_settings[value] = state
			else
				core.log("error", "Invalid disabled setting in game.conf: "..tostring(value))
			end
		end
	end
	return disabled_settings
end

local function get_home_formspec()
	local status_text = wintercraft_account_get_status_text and wintercraft_account_get_status_text() or ""
	return table.concat({
		"bgcolor[#ffffff00;false]",
		"image[3.2,0.65;12.8,2.02;" .. wc_texture("wintercraft_logo_menu.png") .. "]",
		"image_button[1.82,3.85;3.48,3.432;" .. wc_texture("wintercraft_story_button1.png") ..
			";mode_story;;true;false;" .. wc_texture("wintercraft_story_button2.png") .. "]",
		"image_button[5.85,3.85;3.48,3.432;" .. wc_texture("wintercraft_survival_button1.png") ..
			";mode_survival;;true;false;" .. wc_texture("wintercraft_survival_button2.png") .. "]",
		"image_button[9.88,3.85;3.48,3.432;" .. wc_texture("wintercraft_creative_button1.png") ..
			";mode_creative;;true;false;" .. wc_texture("wintercraft_creative_button2.png") .. "]",
		"image_button[13.91,3.85;3.48,3.432;" .. wc_texture("wintercraft_servers_button1.png") ..
			";mode_servers;;true;false;" .. wc_texture("wintercraft_servers_button2.png") .. "]",
		"image_button[5.22,9.25;4.2,1.056;" .. wc_texture("wintercraft_account_button1.png") ..
			";open_account;;true;false;" .. wc_texture("wintercraft_account_button2.png") .. "]",
		"image_button[9.78,9.25;4.2,1.056;" .. wc_texture("wintercraft_settings_button1.png") ..
			";open_settings;;true;false;" .. wc_texture("wintercraft_settings_button2.png") .. "]",
		"label[7.04,8.78;" .. core.formspec_escape(status_text) .. "]",
	})
end

local function get_formspec(tabview, name, tabdata)

	-- Point the player to ContentDB when no games are found
	if #pkgmgr.games == 0 then
		local W = tabview.width
		local H = tabview.height

		local hypertext = "<global valign=middle halign=center size=18>" ..
				fgettext_ne("Wintercraft Reborn is a game-creation platform that allows you to play many different games.") .. "\n" ..
				fgettext_ne("Wintercraft Reborn doesn't come with a game by default.") .. " " ..
				fgettext_ne("You need to install a game before you can create a world.")

		local button_y = H * 2/3 - 0.6
		return table.concat({
			"hypertext[0.375,0;", W - 2*0.375, ",", button_y, ";ht;", core.formspec_escape(hypertext), "]",
			"button[5.25,", button_y, ";5,1.2;game_open_cdb;", fgettext("Install a game"), "]"})
	end

	if not world_selector_open then
		return get_home_formspec()
	end

	local retval = ""

	local index = core.get_textlist_index("sp_worlds") or filterlist.get_current_index(menudata.worldlist,
				tonumber(core.settings:get("mainmenu_last_selected_world"))) or 0

	local list = menudata.worldlist:get_list()
	-- When changing tabs to a world list with fewer entries, the last index is selected (visually).
	-- However, the formspec fields lag behind, thus 'index > #list' can be a valid choice.
	local world = list and list[math.min(index, #list)]

	retval = retval ..
			"bgcolor[#ffffff00;false]" ..
			"image[1.14,1.9;3.16,3.11;" .. wc_mode_card(selected_mode) .. "]" ..
			wc_action_button("main_menu", "world_home", 1.4, 5.42, nil, 0.62) ..
			"image[4.08,1.64;11.15,6.22;" .. wc_texture("wintercraft_panel_wide.png") .. "]" ..
			"label[4.78,2.0;" .. fgettext("Mode: $1", get_mode_label()) .. "]" ..
			"label[4.78,2.35;" .. fgettext("Select World:") .. "]" ..
			"textlist[4.78,2.72;9.82,3.64;sp_worlds;" ..
			menu_render_worldlist() ..
			";" .. index .. "]"

	if world then
		retval = retval ..
				wc_action_button("delete", "world_delete", 5.2, 6.48, nil, 0.66) ..
				wc_action_button("select_mods", "world_configure", 8.0, 6.48, nil, 0.66) ..
				wc_action_button("new", "world_create", 11.4, 6.48, nil, 0.66) ..
				wc_action_button("play_game", "play", 7.9, 7.18, nil, 0.7)
	else
		retval = retval ..
				wc_action_button("new_world", "world_create", 7.86, 6.88, nil, 0.7)
	end

	return retval
end

local function main_button_handler(this, fields, name, tabdata)

	assert(name == "local")

	if fields.game_open_cdb then
		local maintab = ui.find_by_name("maintab")
		local dlg = create_contentdb_dlg("game")
		dlg:set_parent(maintab)
		maintab:hide()
		dlg:show()
		return true
	end

	if not world_selector_open then
		if fields.open_settings then
			local dlg = create_settings_dlg()
			dlg:set_parent(this)
			this:hide()
			dlg:show()
			return true
		end

		if fields.open_account then
			local dlg = create_account_dialog()
			dlg:set_parent(this)
			this:hide()
			dlg:show()
			return true
		end

		if fields.mode_story then
			set_menu_mode("story")
			world_selector_open = true
			return true
		end

		if fields.mode_survival then
			set_menu_mode("survival")
			world_selector_open = true
			return true
		end

		if fields.mode_creative then
			set_menu_mode("creative")
			world_selector_open = true
			return true
		end

		if fields.mode_servers then
			this:set_tab("online")
			return true
		end

		return true
	end

	if fields.world_home then
		world_selector_open = false
		local gamebar = ui.find_by_name("game_button_bar")
		if gamebar then
			gamebar:hide()
		end
		return true
	end

	if this.dlg_create_world_closed_at == nil then
		this.dlg_create_world_closed_at = 0
	end

	local world_doubleclick = false

	if fields["te_playername"] then
		current_name = fields["te_playername"]
	end

	if fields["te_serverport"] then
		current_port = fields["te_serverport"]
	end

	if fields["sp_worlds"] ~= nil then
		local event = core.explode_textlist_event(fields["sp_worlds"])
		local selected = core.get_textlist_index("sp_worlds")

		menu_worldmt_legacy(selected)

		if event.type == "DCL" then
			world_doubleclick = true
		end

		if event.type == "CHG" and selected ~= nil then
			core.settings:set("mainmenu_last_selected_world",
				menudata.worldlist:get_raw_index(selected))
			return true
		end
	end

	if menu_handle_key_up_down(fields,"sp_worlds","mainmenu_last_selected_world") then
		return true
	end

	if fields["cb_creative_mode"] then
		core.settings:set("creative_mode", fields["cb_creative_mode"])
		local selected = core.get_textlist_index("sp_worlds")
		menu_worldmt(selected, "creative_mode", fields["cb_creative_mode"])

		return true
	end

	if fields["cb_enable_damage"] then
		core.settings:set("enable_damage", fields["cb_enable_damage"])
		local selected = core.get_textlist_index("sp_worlds")
		menu_worldmt(selected, "enable_damage", fields["cb_enable_damage"])

		return true
	end

	if fields["cb_server"] then
		core.settings:set("enable_server", fields["cb_server"])

		return true
	end

	if fields["cb_server_announce"] then
		core.settings:set("server_announce", fields["cb_server_announce"])
		local selected = core.get_textlist_index("srv_worlds")
		menu_worldmt(selected, "server_announce", fields["cb_server_announce"])

		return true
	end

	if fields["play"] ~= nil or world_doubleclick or fields["key_enter"] then
		local enter_key_duration = core.get_us_time() - this.dlg_create_world_closed_at
		if world_doubleclick and enter_key_duration <= 200000 then -- 200 ms
			this.dlg_create_world_closed_at = 0
			return true
		end

		local selected = core.get_textlist_index("sp_worlds")
		gamedata.selected_world = menudata.worldlist:get_raw_index(selected)

		if selected == nil or gamedata.selected_world == 0 then
			return true
		end

		-- Update last game
		local world = menudata.worldlist:get_raw_element(gamedata.selected_world)
		local game_obj
		if world then
			game_obj = pkgmgr.find_by_gameid(world.gameid)
			core.settings:set("menu_last_game", game_obj.id)
		end

		local disabled_settings = get_disabled_settings(game_obj)
		for k, _ in pairs(valid_disabled_settings) do
			local v = disabled_settings[k]
			if v ~= nil then
				if k == "enable_server" and v == true then
					error("Setting 'enable_server' cannot be force-enabled! The game.conf needs to be fixed.")
				end
				core.settings:set_bool(k, disabled_settings[k])
			end
		end

		if core.settings:get_bool("enable_server") then
			gamedata.playername = fields["te_playername"]
			gamedata.password   = fields["te_passwd"]
			gamedata.port       = fields["te_serverport"]
			gamedata.address    = ""

			core.settings:set("port",gamedata.port)
			if fields["te_serveraddr"] ~= nil then
				core.settings:set("bind_address",fields["te_serveraddr"])
			end
		else
			gamedata.singleplayer = true
		end

		core.start()
		return true
	end

	if fields["world_create"] ~= nil then
		this.dlg_create_world_closed_at = 0
		local create_world_dlg = create_create_world_dlg()
		create_world_dlg:set_parent(this)
		this:hide()
		create_world_dlg:show()
		return true
	end

	if fields["world_delete"] ~= nil then
		local selected = core.get_textlist_index("sp_worlds")
		if selected ~= nil and
			selected <= menudata.worldlist:size() then
			local world = menudata.worldlist:get_list()[selected]
			if world ~= nil and
				world.name ~= nil and
				world.name ~= "" then
				local index = menudata.worldlist:get_raw_index(selected)
				local delete_world_dlg = create_delete_world_dlg(world.name,index)
				delete_world_dlg:set_parent(this)
				this:hide()
				delete_world_dlg:show()
			end
		end

		return true
	end

	if fields["world_configure"] ~= nil then
		local selected = core.get_textlist_index("sp_worlds")
		if selected ~= nil then
			local configdialog =
				create_configure_world_dlg(
						menudata.worldlist:get_raw_index(selected))

			if (configdialog ~= nil) then
				configdialog:set_parent(this)
				this:hide()
				configdialog:show()
			end
		end

		return true
	end
end

local function on_change(type)
	if type == "ENTER" then
		world_selector_open = false

		local game = current_game()
		if game then
			apply_game(game)
		else
			mm_game_theme.set_engine(true)
		end

		if singleplayer_refresh_gamebar() then
			ui.find_by_name("game_button_bar"):hide()
		end
	elseif type == "LEAVE" then
		world_selector_open = false
		menudata.worldlist:set_filtercriteria(nil)
		local gamebar = ui.find_by_name("game_button_bar")
		if gamebar then
			gamebar:hide()
		end
	end
end

--------------------------------------------------------------------------------
return {
	name = "local",
	caption = fgettext("Start Game"),
	cbf_formspec = get_formspec,
	cbf_button_handler = main_button_handler,
	on_change = on_change
}
