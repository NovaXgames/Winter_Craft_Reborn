-- Wintercraft Reborn
-- Copyright (C) 2026 NovaX_Games
-- SPDX-License-Identifier: LGPL-2.1-or-later

local function copy_favorites()
	local copy = {}
	for _, server in ipairs(serverlistmgr.get_favorites()) do
		copy[#copy + 1] = {
			name = server.name or "",
			address = server.address or "",
			port = server.port,
			description = server.description or "",
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

local function server_formspec(dialogdata)
	ensure_server_list(dialogdata)
	local selected = get_selected_server(dialogdata)

	local name = selected.name or ""
	local address = selected.address or ""
	local port = tostring(selected.port or 30000)
	local description = selected.description or ""
	local error_text = dialogdata.error_text or ""

	return table.concat({
		"formspec_version[8]",
		"size[12,8.2]",
		"label[0.35,0.35;", fgettext("My Servers"), "]",
		"textlist[0.35,0.8;5.3,6.35;my_servers;", render_servers_list(dialogdata), ";", dialogdata.selected, "]",
		"button[0.35,7.3;1.65,0.8;sv_new;", fgettext("New"), "]",
		"button[2.1,7.3;1.65,0.8;sv_delete;", fgettext("Delete"), "]",
		"label[6,0.7;", fgettext("Name"), "]",
		"field[6,0.95;5.7,0.8;sv_name;;", core.formspec_escape(name), "]",
		"label[6,2.0;", fgettext("Address"), "]",
		"field[6,2.25;4.3,0.8;sv_address;;", core.formspec_escape(address), "]",
		"label[10.45,2.0;", fgettext("Port"), "]",
		"field[10.45,2.25;1.25,0.8;sv_port;;", core.formspec_escape(port), "]",
		"label[6,3.3;", fgettext("Description"), "]",
		"textarea[6,3.55;5.7,2.1;sv_description;;", core.formspec_escape(description), "]",
		"style[sv_error;textcolor=#ff5a5a;border=false]",
		"button[6,5.85;5.7,0.7;sv_error;", core.formspec_escape(error_text), "]",
		"button[6,6.65;1.8,0.8;sv_save;", fgettext("Save"), "]",
		"button[7.95,6.65;1.8,0.8;sv_use;", fgettext("Use"), "]",
		"button[9.9,6.65;1.8,0.8;quit;", fgettext("Close"), "]",
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

	return {
		name = name ~= "" and name or nil,
		address = address,
		port = port,
		description = description ~= "" and description or nil,
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
		})
		dialogdata.selected = 1
		dialogdata.error_text = ""
		return true
	end

	if fields.sv_delete then
		local selected = get_selected_server(dialogdata)
		if selected.address ~= "" and selected.port then
			serverlistmgr.delete_favorite(selected)
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
		end

		serverlistmgr.add_favorite(entry)
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
		core.settings:set("address", entry.address)
		core.settings:set("remote_port", entry.port)
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
