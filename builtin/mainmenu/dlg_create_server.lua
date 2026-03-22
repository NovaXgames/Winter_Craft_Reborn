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

local function create_server_formspec(dialogdata)
	local error_text = dialogdata.error_text or ""
	local has_saved_password = dialogdata.admin_password and dialogdata.admin_password ~= ""
	local host_address = dialogdata.host_address ~= "" and dialogdata.host_address or wintercraft_hosting_get_target_label()
	local hint_text
	if wintercraft_hosting_is_configured() then
		hint_text = fgettext("This server will be created on the Wintercraft host.")
	else
		hint_text = fgettext("Set the Wintercraft API URL in Settings first.")
	end

	return table.concat({
		"formspec_version[8]",
		"size[13.2,8.55]",
		"bgcolor[#ffffff00;false]",
		"image[1.0,2.05;2.24,2.2;", wc_texture("wintercraft_servers_button1.png"), "]",
		"image[3.45,0.82;8.95,7.32;", wc_texture("wintercraft_panel_tall.png"), "]",
		"label[3.85,1.12;", fgettext("Create Hosted Server"), "]",
		"label[3.85,1.5;", fgettext("Hosted On"), "]",
		"box[3.85,1.82;6.1,0.5;#151515aa]",
		"label[5.38,1.95;", core.formspec_escape(host_address), "]",
		"label[3.85,2.62;", fgettext("Server Name"), "]",
		"field[3.85,2.92;6.1,0.8;cs_name;;", core.formspec_escape(dialogdata.server_name or ""), "]",
		"label[3.85,3.78;", fgettext("Admin Name"), "]",
		"field[3.85,4.08;6.1,0.8;cs_admin_name;;", core.formspec_escape(dialogdata.admin_name or ""), "]",
		"label[3.85,4.94;", fgettext("Admin Password"), "]",
		"field[3.85,5.24;6.1,0.8;cs_admin_password;;", core.formspec_escape(dialogdata.admin_password or ""), "]",
		"style[cs_hint;textcolor=#bdb7b0;border=false]",
		"button[3.85,6.02;6.1,0.58;cs_hint;",
			core.formspec_escape(has_saved_password and
				fgettext("Leave password empty to keep the saved one.") or hint_text),
		"]",
		"style[cs_error;textcolor=#ff8d8d;border=false]",
		"button[3.85,6.66;6.1,0.58;cs_error;", core.formspec_escape(error_text), "]",
		wc_action_button("create", "cs_create", 4.28, 7.42, nil, 0.68),
		wc_action_button("close", "quit", 7.25, 7.42, nil, 0.68),
	})
end

local function create_server_button_handler(this, fields)
	this.data.server_name = fields.cs_name or this.data.server_name
	this.data.admin_name = fields.cs_admin_name or this.data.admin_name
	this.data.admin_password = fields.cs_admin_password or this.data.admin_password
	this.data.error_text = ""

	if fields.cs_create then
		local server_name = (fields.cs_name or ""):trim()
		local admin_name = (fields.cs_admin_name or ""):trim()
		local admin_password = fields.cs_admin_password ~= "" and fields.cs_admin_password or (this.data.admin_password or "")

		if server_name == "" then
			this.data.error_text = fgettext("Set a server name.")
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
		if (this.data.host_address or ""):trim() == "" then
			this.data.error_text = fgettext("Set the host address in Servers first.")
			return true
		end

		local profile, err = wintercraft_hosting_create_server({
			id = this.data.id,
			name = server_name,
			description = "",
			admin_name = admin_name,
			admin_password = admin_password,
			host_address = this.data.host_address,
			host_port = this.data.host_port,
		})
		if not profile then
			this.data.error_text = err or fgettext("Unable to create the hosted server.")
			return true
		end

		core.settings:set("address", profile and profile.host_address or this.data.host_address)
		core.settings:set("remote_port", profile and profile.host_port or this.data.host_port)
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
	retval.data.id = data.id
	retval.data.server_name = data.server_name or data.name or ""
	retval.data.admin_name = data.admin_name or ""
	retval.data.admin_password = data.admin_password or ""
	retval.data.host_address = (data.host_address or data.address or wintercraft_hosting_get_public_host() or core.settings:get("address") or ""):trim()
	retval.data.host_port = tonumber(data.host_port or data.port or core.settings:get("remote_port")) or 30000
	retval.data.error_text = ""
	return retval
end
