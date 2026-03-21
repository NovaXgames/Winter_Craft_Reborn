-- Wintercraft Reborn
-- Copyright (C) 2026 NovaX_Games
-- SPDX-License-Identifier: LGPL-2.1-or-later

local WC_ACTION_ASPECTS = {
	create = 180 / 44,
	close = 175 / 44,
}

local function wc_texture(name)
	return core.formspec_escape(defaulttexturedir .. name)
end

local function wc_action_button(id, name, x, y, w, h)
	if w == nil then
		w = (WC_ACTION_ASPECTS[id] or (175 / 44)) * h
	end
	return "image_button[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";" ..
		wc_texture("wintercraft_btn_" .. id .. "_1.png") .. ";" .. name ..
		";;true;false;" .. wc_texture("wintercraft_btn_" .. id .. "_2.png") .. "]"
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

local function create_server_formspec(dialogdata)
	local error_text = dialogdata.error_text or ""
	local has_saved_password = dialogdata.admin_password and dialogdata.admin_password ~= ""

	return table.concat({
		"formspec_version[8]",
		"size[13.6,8.95]",
		"bgcolor[#ffffff00;false]",
		"image[0.45,1.95;3.0,2.95;", wc_texture("wintercraft_servers_button1.png"), "]",
		"image[3.85,0.55;9.25,7.95;", wc_texture("wintercraft_panel_tall.png"), "]",
		"label[4.35,0.95;", fgettext("Create Server"), "]",
		"label[4.35,1.48;", fgettext("Server Name"), "]",
		"field[4.35,1.78;5.95,0.8;cs_name;;", core.formspec_escape(dialogdata.server_name or ""), "]",
		"label[4.35,2.75;", fgettext("Address"), "]",
		"field[4.35,3.05;4.55,0.8;cs_address;;", core.formspec_escape(dialogdata.address or ""), "]",
		"label[9.15,2.75;", fgettext("Port"), "]",
		"field[9.15,3.05;1.15,0.8;cs_port;;", core.formspec_escape(tostring(dialogdata.port or 30000)), "]",
		"label[4.35,4.05;", fgettext("Admin Name"), "]",
		"field[4.35,4.35;5.95,0.8;cs_admin_name;;", core.formspec_escape(dialogdata.admin_name or ""), "]",
		"label[4.35,5.3;", fgettext("Admin Password"), "]",
		"field[4.35,5.6;5.95,0.8;cs_admin_password;;", core.formspec_escape(dialogdata.admin_password or ""), "]",
		"style[cs_hint;textcolor=#bdb7b0;border=false]",
		"button[4.35,6.42;5.95,0.6;cs_hint;",
			core.formspec_escape(has_saved_password and
				fgettext("Leave password empty to keep the saved one.") or
				fgettext("Set the admin password for this server profile.")),
		"]",
		"style[cs_error;textcolor=#ff8d8d;border=false]",
		"button[4.35,7.08;5.95,0.6;cs_error;", core.formspec_escape(error_text), "]",
		wc_action_button("create", "cs_create", 5.0, 7.92, nil, 0.62),
		wc_action_button("close", "quit", 8.0, 7.92, nil, 0.62),
	})
end

local function create_server_button_handler(this, fields)
	this.data.server_name = fields.cs_name or this.data.server_name
	this.data.address = fields.cs_address or this.data.address
	this.data.port = fields.cs_port or this.data.port
	this.data.admin_name = fields.cs_admin_name or this.data.admin_name
	this.data.error_text = ""

	if fields.cs_create then
		local server_name = (fields.cs_name or ""):trim()
		local address = (fields.cs_address or ""):trim()
		local port = parse_port(fields.cs_port)
		local admin_name = (fields.cs_admin_name or ""):trim()
		local admin_password = fields.cs_admin_password ~= "" and fields.cs_admin_password or (this.data.admin_password or "")

		if server_name == "" then
			this.data.error_text = fgettext("Set a server name.")
			return true
		end
		if address == "" or not port then
			this.data.error_text = fgettext("Set a valid address and port.")
			return true
		end
		if admin_name == "" then
			this.data.error_text = fgettext("Set the admin name.")
			return true
		end
		if admin_password == "" then
			this.data.error_text = fgettext("Set the admin password.")
			return true
		end

		serverlistmgr.add_favorite({
			name = server_name,
			address = address,
			port = port,
			description = "",
		})

		wintercraft_upsert_server_profile({
			name = server_name,
			address = address,
			port = port,
			description = "",
			admin_name = admin_name,
			admin_password = admin_password,
		})

		core.settings:set("address", address)
		core.settings:set("remote_port", port)
		core.settings:set("name", admin_name)

		this:delete()
		return true
	end

	if fields.quit then
		this:delete()
		return true
	end

	return false
end

function create_server_setup_dialog(prefill)
	local data = prefill or {}
	local retval = dialog_create("dlg_create_server", create_server_formspec, create_server_button_handler, nil)
	retval.data.server_name = data.server_name or data.name or ""
	retval.data.address = data.address or ""
	retval.data.port = tostring(data.port or 30000)
	retval.data.admin_name = data.admin_name or ""
	retval.data.admin_password = data.admin_password or ""
	retval.data.error_text = ""
	return retval
end
