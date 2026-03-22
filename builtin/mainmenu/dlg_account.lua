-- Wintercraft Reborn
-- Copyright (C) 2026 NovaX_Games
-- SPDX-License-Identifier: LGPL-2.1-or-later

local WC_ACTION_ASPECTS = {
	login = 170 / 44,
	register = 195 / 44,
	logout = 185 / 44,
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

local function account_formspec(dialogdata)
	local api_url = wintercraft_get_api_url()
	local status_text = dialogdata.error_text or ""
	local username = dialogdata.username or wintercraft_account_get_name()
	local signed_in = wintercraft_account_is_logged_in()
	local api_hint = api_url ~= "" and api_url or fgettext("Set the Wintercraft API URL in Settings first.")

	local formspec = {
		"formspec_version[8]",
		"size[12.9,8.6]",
		"bgcolor[#ffffff00;false]",
		"image[2.95,0.86;7.0,7.25;", wc_texture("wintercraft_panel_tall.png"), "]",
		"label[3.35,1.14;", fgettext("Wintercraft Account"), "]",
		"label[3.35,1.52;", fgettext("API"), "]",
		"box[3.35,1.82;6.2,0.5;#151515aa]",
		"label[3.58,1.95;", core.formspec_escape(api_hint), "]",
	}

	if signed_in then
		formspec[#formspec + 1] = "label[3.35,2.72;" .. fgettext("Signed In As") .. "]"
		formspec[#formspec + 1] = "box[3.35,3.02;6.2,0.74;#15151555]"
		formspec[#formspec + 1] = "label[3.62,3.22;" .. core.formspec_escape(username ~= "" and username or wintercraft_account_get_name()) .. "]"
		formspec[#formspec + 1] = "style[acct_hint;textcolor=#bdb7b0;border=false]"
		formspec[#formspec + 1] = "button[3.35,4.05;6.2,0.58;acct_hint;" ..
			core.formspec_escape(fgettext("This account owns the hosted servers listed in My Servers.")) .. "]"
		formspec[#formspec + 1] = wc_action_button("logout", "acct_logout", 4.0, 6.92, nil, 0.68)
		formspec[#formspec + 1] = wc_action_button("close", "quit", 6.55, 6.92, nil, 0.68)
	else
		formspec[#formspec + 1] = "label[3.35,2.7;" .. fgettext("Username") .. "]"
		formspec[#formspec + 1] = "field[3.35,3.02;6.2,0.8;acct_username;;" .. core.formspec_escape(username or "") .. "]"
		formspec[#formspec + 1] = "label[3.35,3.95;" .. fgettext("Password") .. "]"
		formspec[#formspec + 1] = "pwdfield[3.35,4.27;6.2,0.8;acct_password;]"
		formspec[#formspec + 1] = "style[acct_hint;textcolor=#bdb7b0;border=false]"
		formspec[#formspec + 1] = "button[3.35,5.05;6.2,0.58;acct_hint;" ..
			core.formspec_escape(fgettext("Use the same Wintercraft account for hosted servers on every device.")) .. "]"
		formspec[#formspec + 1] = wc_action_button("login", "acct_login", 3.55, 6.92, nil, 0.68)
		formspec[#formspec + 1] = wc_action_button("register", "acct_register", 5.85, 6.92, nil, 0.68)
		formspec[#formspec + 1] = wc_action_button("close", "quit", 8.55, 6.92, nil, 0.68)
	end

	formspec[#formspec + 1] = "style[acct_error;textcolor=#ff8d8d;border=false]"
	formspec[#formspec + 1] = "button[3.35,6.15;6.2,0.58;acct_error;" .. core.formspec_escape(status_text) .. "]"

	return table.concat(formspec)
end

local function account_button_handler(this, fields)
	this.data.username = fields.acct_username or this.data.username or wintercraft_account_get_name()

	if fields.acct_login or fields.acct_register then
		local username = (fields.acct_username or ""):trim()
		local password = fields.acct_password or ""

		if username == "" then
			this.data.error_text = fgettext("Set a username.")
			return true
		end
		if password == "" then
			this.data.error_text = fgettext("Set a password.")
			return true
		end

		local account, err
		if fields.acct_register then
			account, err = wintercraft_account_register(username, password)
		else
			account, err = wintercraft_account_login(username, password)
		end

		if not account then
			this.data.error_text = err or fgettext("Unable to sign in.")
			return true
		end

		this.data.username = account.username
		this.data.error_text = fgettext("Account ready.")
		return true
	end

	if fields.acct_logout then
		wintercraft_account_logout()
		this.data.username = ""
		this.data.error_text = fgettext("Signed out.")
		return true
	end

	if fields.quit then
		this:delete()
		return true
	end

	return false
end

function create_account_dialog()
	local retval = dialog_create("dlg_account", account_formspec, account_button_handler, nil)
	retval.data.username = wintercraft_account_get_name()
	retval.data.error_text = ""
	return retval
end
