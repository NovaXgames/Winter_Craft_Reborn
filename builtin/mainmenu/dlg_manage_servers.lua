-- Wintercraft Reborn
-- Copyright (C) 2026 NovaX_Games
-- SPDX-License-Identifier: LGPL-2.1-or-later

local function copy_profiles()
	local copy = {}
	for _, profile in ipairs(wintercraft_get_server_profiles()) do
		copy[#copy + 1] = {
			id = profile.id,
			name = profile.name or "",
			description = profile.description or "",
			admin_name = profile.admin_name or "",
			admin_password = profile.admin_password or "",
			host_address = profile.host_address or "",
			host_port = tonumber(profile.host_port) or 30000,
		}
	end
	return copy
end

local function current_host_address()
	return (core.settings:get("address") or ""):trim()
end

local function current_host_port()
	return tonumber(core.settings:get("remote_port")) or 30000
end

local function ensure_server_list(dialogdata)
	if not dialogdata.favorites then
		dialogdata.favorites = copy_profiles()
	end
	if #dialogdata.favorites == 0 then
		dialogdata.favorites = {{
			id = nil,
			name = "",
			description = "",
			admin_name = "",
			admin_password = "",
			host_address = current_host_address(),
			host_port = current_host_port(),
		}}
	end
	dialogdata.selected = math.max(1, math.min(dialogdata.selected or 1, #dialogdata.favorites))
end

local function get_selected_server(dialogdata)
	ensure_server_list(dialogdata)
	return dialogdata.favorites[dialogdata.selected]
end

local function find_server_index(servers, profile_id)
	for i, server in ipairs(servers) do
		if server.id == profile_id then
			return i
		end
	end
	return 1
end

local function render_servers_list(dialogdata)
	local rows = {}
	for _, server in ipairs(dialogdata.favorites) do
		local name = server.name ~= "" and server.name or fgettext("Unnamed server")
		rows[#rows + 1] = core.formspec_escape(name)
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
	local description = selected.description or ""
	local admin_name = selected.admin_name or ""
	local admin_password = selected.admin_password or ""
	local error_text = dialogdata.error_text or ""
	local host_address = selected.host_address ~= "" and selected.host_address or fgettext("No host selected")

	return table.concat({
		"formspec_version[8]",
		"size[13.3,8.8]",
		"bgcolor[#ffffff00;false]",
		"image[0.55,0.68;4.35,7.6;", wc_texture("wintercraft_panel_tall.png"), "]",
		"image[5.12,0.68;7.65,7.6;", wc_texture("wintercraft_panel_tall.png"), "]",
		"label[0.95,1.02;", fgettext("Hosted Servers"), "]",
		"textlist[0.95,1.52;3.55,5.92;my_servers;", render_servers_list(dialogdata), ";", dialogdata.selected, "]",
		wc_action_button("new", "sv_new", 0.96, 7.56, nil, 0.64),
		wc_action_button("delete", "sv_delete", 2.88, 7.56, nil, 0.64),
		"label[5.55,1.02;", fgettext("Hosted On"), "]",
		"style[sv_host;textcolor=#d4d0cb;border=false]",
		"button[5.55,1.28;6.0,0.58;sv_host;", core.formspec_escape(host_address), "]",
		"label[5.55,2.05;", fgettext("Server Name"), "]",
		"field[5.55,2.35;6.0,0.8;sv_name;;", core.formspec_escape(name), "]",
		"label[5.55,3.15;", fgettext("Description"), "]",
		"textarea[5.55,3.45;6.0,1.62;sv_description;;", core.formspec_escape(description), "]",
		"label[5.55,5.24;", fgettext("Admin Name"), "]",
		"field[5.55,5.54;2.7,0.8;sv_admin_name;;", core.formspec_escape(admin_name), "]",
		"label[8.55,5.24;", fgettext("Admin Password"), "]",
		"field[8.55,5.54;3.0,0.8;sv_admin_password;;", core.formspec_escape(admin_password), "]",
		"style[sv_hint;textcolor=#bdb7b0;border=false]",
		"button[5.55,6.28;6.0,0.58;sv_hint;", core.formspec_escape(fgettext("These servers are hosted on the Wintercraft host.")), "]",
		"style[sv_error;textcolor=#ff8d8d;border=false]",
		"button[5.55,6.9;6.0,0.58;sv_error;", core.formspec_escape(error_text), "]",
		wc_action_button("save", "sv_save", 5.55, 7.56, nil, 0.64),
		wc_action_button("use", "sv_use", 7.95, 7.56, nil, 0.64),
		wc_action_button("close", "quit", 10.3, 7.56, nil, 0.64),
	})
end

local function apply_fields_to_server(server, fields)
	local name = (fields.sv_name or ""):trim()
	local admin_name = (fields.sv_admin_name or ""):trim()
	local admin_password = (fields.sv_admin_password or ""):trim()
	local host_address = server.host_address ~= "" and server.host_address or current_host_address()

	if name == "" then
		return nil, fgettext("Set a server name.")
	end
	if host_address == "" then
		return nil, fgettext("Set the host address in Servers first.")
	end
	if admin_name == "" then
		return nil, fgettext("Set the admin name.")
	end
	if admin_password == "" then
		return nil, fgettext("Set the admin password.")
	end

	return {
		id = server.id,
		name = name,
		description = (fields.sv_description or ""):trim(),
		admin_name = admin_name,
		admin_password = admin_password,
		host_address = host_address,
		host_port = server.host_port or current_host_port(),
	}, nil
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
			id = nil,
			name = "",
			description = "",
			admin_name = core.settings:get("name") or "",
			admin_password = "",
			host_address = current_host_address(),
			host_port = current_host_port(),
		})
		dialogdata.selected = 1
		dialogdata.error_text = ""
		return true
	end

	if fields.sv_delete then
		local selected = get_selected_server(dialogdata)
		if selected.id then
			wintercraft_delete_server_profile(selected.id)
		end
		table.remove(dialogdata.favorites, dialogdata.selected)
		ensure_server_list(dialogdata)
		dialogdata.error_text = fgettext("Hosted server deleted.")
		return true
	end

	if fields.sv_save then
		local selected = get_selected_server(dialogdata)
		local entry, err = apply_fields_to_server(selected, fields)
		if not entry then
			dialogdata.error_text = err
			return true
		end

		local profile_id = wintercraft_upsert_server_profile(entry)
		dialogdata.favorites = copy_profiles()
		dialogdata.selected = find_server_index(dialogdata.favorites, profile_id)
		dialogdata.error_text = fgettext("Hosted server saved.")
		return true
	end

	if fields.sv_use then
		local selected = get_selected_server(dialogdata)
		local entry, err = apply_fields_to_server(selected, fields)
		if not entry then
			dialogdata.error_text = err
			return true
		end

		local profile_id = wintercraft_upsert_server_profile(entry)
		local profile = wintercraft_find_server_profile(profile_id)
		core.settings:set("address", profile and profile.host_address or entry.host_address)
		core.settings:set("remote_port", profile and profile.host_port or entry.host_port)
		core.settings:set("name", entry.admin_name)
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
	retval.data.favorites = copy_profiles()
	retval.data.selected = 1
	retval.data.error_text = ""
	return retval
end
