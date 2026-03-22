-- Wintercraft Reborn
-- Copyright (C) 2026 NovaX_Games
-- SPDX-License-Identifier: LGPL-2.1-or-later

local API_URL_SETTING = "wintercraft_api_url"
local LEGACY_HOSTING_API_URL_SETTING = "wintercraft_hosting_api_url"
local ACCOUNT_NAME_SETTING = "wintercraft_account_name"
local ACCOUNT_TOKEN_SETTING = "wintercraft_account_token"
local ACCOUNT_ID_SETTING = "wintercraft_account_id"
local ACCOUNT_TIMEOUT = 10

local function as_trimmed_string(value)
	if type(value) == "string" then
		return value:trim()
	end
	if value == nil then
		return ""
	end
	return tostring(value)
end

local function normalize_api_url(url)
	return as_trimmed_string(url):gsub("/+$", "")
end

local function get_http_api()
	if not core.get_http_api then
		return nil, fgettext("HTTP is not available in this build.")
	end

	local http = core.get_http_api()
	if not http then
		return nil, fgettext("HTTP is not available in this build.")
	end

	return http, nil
end

local function build_headers(send_json, include_auth)
	local headers = {
		"Accept: application/json",
	}

	if send_json then
		headers[#headers + 1] = "Content-Type: application/json"
	end

	if include_auth then
		local token = as_trimmed_string(core.settings:get(ACCOUNT_TOKEN_SETTING))
		if token ~= "" then
			headers[#headers + 1] = "Authorization: Bearer " .. token
		end
	end

	return headers
end

local function request_json(req)
	local http, err = get_http_api()
	if not http then
		return nil, err
	end

	req.timeout = req.timeout or ACCOUNT_TIMEOUT
	req.user_agent = req.user_agent or "Wintercraft Reborn Launcher"

	local response = http.fetch_sync(req)
	if not response or not response.completed or not response.succeeded then
		local code = response and response.code and ("HTTP " .. response.code) or ""
		local details = response and as_trimmed_string(response.data) or ""
		local suffix = details ~= "" and details or code
		if suffix ~= "" then
			return nil, fgettext("Account request failed: $1", suffix)
		end
		return nil, fgettext("Account request failed.")
	end

	if not response.data or response.data == "" then
		return {}, nil
	end

	local payload = core.parse_json(response.data)
	if type(payload) ~= "table" then
		return nil, fgettext("Account API returned invalid JSON.")
	end

	return payload, nil
end

local function request_account_api(method, endpoint, data, include_auth)
	local api_url = wintercraft_get_api_url()
	if api_url == "" then
		return nil, fgettext("Set the Wintercraft API URL in Settings first.")
	end

	local request = {
		url = api_url .. endpoint,
		method = method,
		extra_headers = build_headers(data ~= nil, include_auth ~= false),
	}

	if data ~= nil then
		request.data = core.write_json(data)
		if method == "POST" then
			request.post_data = request.data
		end
	end

	return request_json(request)
end

local function extract_account(payload)
	if type(payload) ~= "table" then
		return nil, ""
	end

	local token = as_trimmed_string(payload.token or payload.access_token or payload.session_token)
	local account = payload.account or payload.user or payload.data
	if type(account) ~= "table" then
		account = payload
	end

	local account_id = as_trimmed_string(account.id or account.user_id or account.account_id)
	local account_name = as_trimmed_string(account.username or account.name or account.login)
	if account_name == "" and payload.username then
		account_name = as_trimmed_string(payload.username)
	end

	if account_name == "" then
		return nil, token
	end

	return {
		id = account_id,
		username = account_name,
	}, token
end

local function save_account_session(account, token)
	core.settings:set(ACCOUNT_NAME_SETTING, account.username)
	core.settings:set(ACCOUNT_ID_SETTING, account.id or "")
	core.settings:set(ACCOUNT_TOKEN_SETTING, token or "")
end

function wintercraft_get_api_url()
	local explicit = normalize_api_url(core.settings:get(API_URL_SETTING))
	if explicit ~= "" then
		return explicit
	end

	return normalize_api_url(core.settings:get(LEGACY_HOSTING_API_URL_SETTING))
end

function wintercraft_account_is_configured()
	return wintercraft_get_api_url() ~= ""
end

function wintercraft_account_get_name()
	return as_trimmed_string(core.settings:get(ACCOUNT_NAME_SETTING))
end

function wintercraft_account_get_id()
	return as_trimmed_string(core.settings:get(ACCOUNT_ID_SETTING))
end

function wintercraft_account_get_token()
	return as_trimmed_string(core.settings:get(ACCOUNT_TOKEN_SETTING))
end

function wintercraft_account_is_logged_in()
	return wintercraft_account_get_name() ~= "" and wintercraft_account_get_token() ~= ""
end

function wintercraft_account_get_status_text()
	if wintercraft_account_is_logged_in() then
		return fgettext("Signed in as $1", wintercraft_account_get_name())
	end
	return fgettext("Not signed in")
end

function wintercraft_account_clear_session()
	core.settings:remove(ACCOUNT_NAME_SETTING)
	core.settings:remove(ACCOUNT_ID_SETTING)
	core.settings:remove(ACCOUNT_TOKEN_SETTING)
end

function wintercraft_account_register(username, password)
	local payload, err = request_account_api("POST", "/auth/register", {
		username = as_trimmed_string(username),
		password = password or "",
	}, false)
	if not payload then
		return nil, err
	end

	local account, token = extract_account(payload)
	if not account or token == "" then
		return nil, fgettext("Account API returned an invalid registration response.")
	end

	save_account_session(account, token)
	return account, nil
end

function wintercraft_account_login(username, password)
	local payload, err = request_account_api("POST", "/auth/login", {
		username = as_trimmed_string(username),
		password = password or "",
	}, false)
	if not payload then
		return nil, err
	end

	local account, token = extract_account(payload)
	if not account or token == "" then
		return nil, fgettext("Account API returned an invalid login response.")
	end

	save_account_session(account, token)
	return account, nil
end

function wintercraft_account_sync()
	if not wintercraft_account_is_logged_in() then
		return nil, fgettext("Sign in first.")
	end

	local payload, err = request_account_api("GET", "/auth/me", nil, true)
	if not payload then
		return nil, err
	end

	local account = payload.account or payload.user or payload.data or payload
	if type(account) ~= "table" then
		return nil, fgettext("Account API returned an invalid account response.")
	end

	local normalized = {
		id = as_trimmed_string(account.id or account.user_id or account.account_id),
		username = as_trimmed_string(account.username or account.name or account.login),
	}
	if normalized.username == "" then
		return nil, fgettext("Account API returned an invalid account response.")
	end

	save_account_session(normalized, wintercraft_account_get_token())
	return normalized, nil
end

function wintercraft_account_logout()
	if wintercraft_account_get_token() ~= "" then
		request_account_api("POST", "/auth/logout", {}, true)
	end
	wintercraft_account_clear_session()
	return true
end
