-- Wintercraft Reborn
-- Copyright (C) 2026 NovaX_Games
-- SPDX-License-Identifier: LGPL-2.1-or-later

local function copy_favorites()
	local copy = {}
	local profiles = wintercraft_get_server_profiles()
	for _, server in ipairs(serverlistmgr.get_favorites()) do
		local profile = profiles[wintercraft_server_profile_key(server.address or "", server.port)]
		copy[#copy + 1] = {
			name = (profile and profile.name) or server.name or "",
			address = server.address or "",
			port = server.port,
			description = (profile and profile.description) or server.description or "",
			admin_name = profile and profile.admin_name or "",
			admin_password = profile and profile.admin_password or "",
		}
	end
	return copy
end

local function ensure_server_list(dialogdata)
	if not dialogdata.favorites then
		dialogdata.favorites = copy_favorites()
	end
	if #dialogdata.favorites == 0 then
		dialogdata.favorites = {{
			name = "",
			address = "",
			port = 30000,
			description = "",
			admin_name = "",
			admin_password = "",
		}}
	end
	dialogdata.selected = math.max(1, math.min(dialogdata.selected or 1, #dialogdata.favorites))
end

local function get_selected_server(dialogdata)
	ensure_server_list(dialogdata)
	return dialogdata.favorites[dialogdata.selected]
end

local function find_server_index(servers, address, port)
	for i, server in ipairs(servers) do
		if server.address == address and server.port == port then
			return i
		end
	end
	return 1
end

local function render_servers_list(dialogdata)
	local rows = {}
	for _, server in ipairs(dialogdata.favorites) do
		local name = server.name ~= "" and server.name or fgettext("Unnamed server")
		local address = server.address ~= "" and server.address or fgettext("No address")
		local port = server.port or 30000
		rows[#rows + 1] = core.formspec_escape(("%s (%s:%d)"):format(name, address, port))
	end
	return table.concat(rows, ",")
end

local function wc_texture(name)
	return core.formspec_escape(defaulttexturedir .. name)
end

local WC_ACTION_ASPECTS = {
	new = 165 / 44,
	delete = 180 / 44,
	save = 165 / 44,
	use = 165 / 44,
	close = 175 / 44,
}

local function wc_action_button(id, name, x, y, w, h)
	if w == nil then
		w = (WC_ACTION_ASPECTS[id] or (175 / 44)) * h
	end
	return "image_button[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";" ..
		wc_texture("wintercraft_btn_" .. id .. "_1.png") .. ";" .. name ..
		";;true;false;" .. wc_texture("wintercraft_btn_" .. id .. "_2.png") .. "]"
end

local function server_formspec(dialogdata)
	ensure_server_list(dialogdata)
	local selected = get_selected_server(dialogdata)

	local name = selected.name or ""
	local address = selected.address or ""
	local port = tostring(selected.port or 30000)
	local description = selected.description or ""
	local admin_name = selected.admin_name or ""
	local has_saved_password = selected.admin_password and selected.admin_password ~= ""
	local error_text = dialogdata.error_text or ""

	return table.concat({
		"formspec_version[8]",
		"size[13.9,9.65]",
		"bgcolor[#ffffff00;false]",
		"image[0.35,0.45;5.3,8.55;", wc_texture("wintercraft_panel_tall.png"), "]",
		"image[5.95,0.45;7.55,8.55;", wc_texture("wintercraft_panel_tall.png"), "]",
		"label[0.65,0.88;", fgettext("My Servers"), "]",
		"textlist[0.65,1.35;4.65,6.55;my_servers;", render_servers_list(dialogdata), ";", dialogdata.selected, "]",
		wc_action_button("new", "sv_new", 0.65, 8.25, nil, 0.62),
		wc_action_button("delete", "sv_delete", 2.75, 8.25, nil, 0.62),
		"label[6.35,0.88;", fgettext("Server Name"), "]",
		"field[6.35,1.18;6.45,0.8;sv_name;;", core.formspec_escape(name), "]",
		"label[6.35,2.2;", fgettext("Address"), "]",
		"field[6.35,2.5;4.95,0.8;sv_address;;", core.formspec_escape(address), "]",
		"label[11.55,2.2;", fgettext("Port"), "]",
		"field[11.55,2.5;1.25,0.8;sv_port;;", core.formspec_escape(port), "]",
		"label[6.35,3.38;", fgettext("Description"), "]",
		"textarea[6.35,3.68;6.25,1.85;sv_description;;", core.formspec_escape(description), "]",
		"label[6.35,5.85;", fgettext("Admin Name"), "]",
		"field[6.35,6.15;2.95,0.8;sv_admin_name;;", core.formspec_escape(admin_name), "]",
		"label[9.65,5.85;", fgettext("Admin Password"), "]",
		"field[9.65,6.15;2.95,0.8;sv_admin_password;;", core.formspec_escape(selected.admin_password or ""), "]",
		"style[sv_hint;textcolor=#bdb7b0;border=false]",
		"button[6.35,6.98;6.25,0.6;sv_hint;",
			core.formspec_escape(has_saved_password and
				fgettext("Leave password empty to keep the saved one.") or
				fgettext("Set an admin password for this server.")),
		"]",
		"style[sv_error;textcolor=#ff5a5a;border=false]",
		"button[6.35,7.62;6.25,0.6;sv_error;", core.formspec_escape(error_text), "]",
		wc_action_button("save", "sv_save", 6.35, 8.25, nil, 0.62),
		wc_action_button("use", "sv_use", 8.8, 8.25, nil, 0.62),
		wc_action_button("close", "quit", 11.25, 8.25, nil, 0.62),
	})
end

local function parse_port(raw_port)
	if not raw_port then
		return nil
	end
	local value = tonumber(raw_port:match("^%s*(%d+)%s*$"))
	if not value or value < 1 or value > 65535 then
		return nil
	end
	return value
end

local function apply_fields_to_server(server, fields)
	local port = parse_port(fields.sv_port)
	if not port then
		return nil
	end

	local address = (fields.sv_address or ""):trim()
	if address == "" then
		return nil
	end

	local name = (fields.sv_name or ""):trim()
	local description = (fields.sv_description or ""):trim()
	local admin_name = (fields.sv_admin_name or ""):trim()
	local admin_password = fields.sv_admin_password ~= "" and fields.sv_admin_password or (server.admin_password or "")

	return {
		name = name ~= "" and name or nil,
		address = address,
		port = port,
		description = description ~= "" and description or nil,
		admin_name = admin_name,
		admin_password = admin_password,
	}
end

local function manage_servers_button_handler(this, fields)
	local dialogdata = this.data
	ensure_server_list(dialogdata)

	if fields.my_servers then
		local selected = core.get_textlist_index("my_servers")
		if selected then
			dialogdata.selected = math.max(1, math.min(selected, #dialogdata.favorites))
		end
		dialogdata.error_text = ""
		return true
	end

	if fields.sv_new then
		table.insert(dialogdata.favorites, 1, {
			name = "",
			address = "",
			port = 30000,
			description = "",
			admin_name = "",
			admin_password = "",
		})
		dialogdata.selected = 1
		dialogdata.error_text = ""
		return true
	end

	if fields.sv_delete then
		local selected = get_selected_server(dialogdata)
		if selected.address ~= "" and selected.port then
			serverlistmgr.delete_favorite(selected)
			wintercraft_delete_server_profile(selected.address, selected.port)
		end

		table.remove(dialogdata.favorites, dialogdata.selected)
		ensure_server_list(dialogdata)
		dialogdata.error_text = fgettext("Server deleted.")
		return true
	end

	if fields.sv_save then
		local selected = get_selected_server(dialogdata)
		local entry = apply_fields_to_server(selected, fields)
		if not entry then
			dialogdata.error_text = fgettext("Set a valid address and port.")
			return true
		end

		if selected.address and selected.address ~= "" and selected.port and
				(selected.address ~= entry.address or selected.port ~= entry.port) then
			serverlistmgr.delete_favorite(selected)
			wintercraft_delete_server_profile(selected.address, selected.port)
		end

		serverlistmgr.add_favorite(entry)
		wintercraft_upsert_server_profile(entry)
		dialogdata.favorites = copy_favorites()
		dialogdata.selected = find_server_index(dialogdata.favorites, entry.address, entry.port)
		dialogdata.error_text = fgettext("Server saved.")
		return true
	end

	if fields.sv_use then
		local selected = get_selected_server(dialogdata)
		local entry = apply_fields_to_server(selected, fields)
		if not entry then
			dialogdata.error_text = fgettext("Set a valid address and port.")
			return true
		end

		serverlistmgr.add_favorite(entry)
		wintercraft_upsert_server_profile(entry)
		core.settings:set("address", entry.address)
		core.settings:set("remote_port", entry.port)
		if entry.admin_name and entry.admin_name ~= "" then
			core.settings:set("name", entry.admin_name)
		end
		this:delete()
		return true
	end

	if fields.quit then
		this:delete()
		return true
	end

	return false
end

function create_manage_servers_dialog()
	local retval = dialog_create("dlg_manage_servers", server_formspec, manage_servers_button_handler, nil)
	retval.data.favorites = copy_favorites()
	retval.data.selected = 1
	retval.data.error_text = ""
	return retval
end
