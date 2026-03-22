-- Wintercraft Reborn
-- Copyright (C) 2026 NovaX_Games
-- SPDX-License-Identifier: LGPL-2.1-or-later

local HOSTING_API_URL_SETTING = "wintercraft_hosting_api_url"
local HOSTING_API_TOKEN_SETTING = "wintercraft_hosting_api_token"
local HOSTING_PUBLIC_HOST_SETTING = "wintercraft_hosting_public_host"
local DEFAULT_HOSTING_TIMEOUT = 10

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

local function parse_host_from_url(url)
	local host = as_trimmed_string(url):match("^https?://([^/%?#]+)")
	if not host then
		return ""
	end
	return host
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

local function build_headers(send_json)
	local headers = {
		"Accept: application/json",
	}

	if send_json then
		headers[#headers + 1] = "Content-Type: application/json"
	end

	local token = as_trimmed_string(core.settings:get(HOSTING_API_TOKEN_SETTING))
	if token ~= "" then
		headers[#headers + 1] = "Authorization: Bearer " .. token
	end

	return headers
end

local function extract_server_payload(payload)
	if type(payload) ~= "table" then
		return nil
	end

	if type(payload.server) == "table" then
		return payload.server
	end
	if type(payload.data) == "table" then
		return payload.data
	end

	return payload
end

local function get_profiles_lookup()
	local by_id = {}
	local by_name = {}

	for _, profile in ipairs(wintercraft_get_server_profiles()) do
		by_id[profile.id] = profile
		if profile.name ~= "" then
			by_name[profile.name:lower()] = profile
		end
	end

	return by_id, by_name
end

local function normalize_remote_server(remote, by_id, by_name, fallback)
	if type(remote) ~= "table" then
		return nil
	end

	local id = as_trimmed_string(remote.id or remote.server_id or remote.uuid or remote.slug)
	local name = as_trimmed_string(remote.name or remote.server_name or remote.title)
	local local_profile = (id ~= "" and by_id[id]) or (name ~= "" and by_name[name:lower()]) or fallback

	if id == "" and local_profile and local_profile.id then
		id = local_profile.id
	end
	if id == "" and name ~= "" then
		id = name
	end
	if id == "" then
		return nil
	end

	local host_address = as_trimmed_string(remote.host_address or remote.public_host or
		remote.public_address or remote.server_address or remote.address or remote.host)
	if host_address == "" and local_profile then
		host_address = as_trimmed_string(local_profile.host_address)
	end
	if host_address == "" then
		host_address = wintercraft_hosting_get_public_host()
	end

	local host_port = tonumber(remote.host_port or remote.public_port or remote.port)
	if not host_port and local_profile then
		host_port = tonumber(local_profile.host_port)
	end
	if not host_port then
		host_port = tonumber(core.settings:get("remote_port")) or 30000
	end

	local description = as_trimmed_string(remote.description or remote.server_description)
	if description == "" and local_profile then
		description = as_trimmed_string(local_profile.description)
	end

	local admin_name = as_trimmed_string(remote.admin_name or remote.owner or remote.admin or remote.username)
	if admin_name == "" and local_profile then
		admin_name = as_trimmed_string(local_profile.admin_name)
	end

	local admin_password = local_profile and as_trimmed_string(local_profile.admin_password) or ""

	return {
		id = id,
		name = name ~= "" and name or (local_profile and local_profile.name or ""),
		description = description,
		admin_name = admin_name,
		admin_password = admin_password,
		host_address = host_address,
		host_port = host_port,
		hosting_managed = true,
	}
end

local function request_json(req)
	local http, err = get_http_api()
	if not http then
		return nil, err
	end

	req.timeout = req.timeout or DEFAULT_HOSTING_TIMEOUT
	req.user_agent = req.user_agent or "Wintercraft Reborn Launcher"

	local response = http.fetch_sync(req)
	if not response or not response.completed or not response.succeeded then
		local code = response and response.code and ("HTTP " .. response.code) or ""
		local details = response and as_trimmed_string(response.data) or ""
		local suffix = details ~= "" and details or code
		if suffix ~= "" then
			return nil, fgettext("Hosting request failed: $1", suffix)
		end
		return nil, fgettext("Hosting request failed.")
	end

	if not response.data or response.data == "" then
		return {}, nil
	end

	local payload = core.parse_json(response.data)
	if type(payload) ~= "table" then
		return nil, fgettext("Hosting API returned invalid JSON.")
	end

	return payload, nil
end

local function request_hosting(method, endpoint, data, fallback_endpoint)
	local api_url = wintercraft_hosting_get_api_url()
	if api_url == "" then
		return nil, fgettext("Set a hosting API URL in Settings first.")
	end

	local request = {
		url = api_url .. endpoint,
		method = method,
		extra_headers = build_headers(data ~= nil),
	}

	if data ~= nil then
		request.data = core.write_json(data)
		if method == "POST" then
			request.post_data = request.data
		end
	end

	local payload, err = request_json(request)
	if payload or not fallback_endpoint then
		return payload, err
	end

	return request_json({
		url = api_url .. fallback_endpoint,
		method = "POST",
		data = core.write_json(data or {}),
		post_data = core.write_json(data or {}),
		extra_headers = build_headers(true),
	})
end

function wintercraft_hosting_get_api_url()
	return normalize_api_url(core.settings:get(HOSTING_API_URL_SETTING))
end

function wintercraft_hosting_is_configured()
	return wintercraft_hosting_get_api_url() ~= ""
end

function wintercraft_hosting_get_public_host()
	local explicit_host = as_trimmed_string(core.settings:get(HOSTING_PUBLIC_HOST_SETTING))
	if explicit_host ~= "" then
		return explicit_host
	end

	local api_host = parse_host_from_url(wintercraft_hosting_get_api_url())
	if api_host ~= "" then
		return api_host
	end

	return as_trimmed_string(core.settings:get("address"))
end

function wintercraft_hosting_get_target_label()
	local host = wintercraft_hosting_get_public_host()
	if host ~= "" then
		return host
	end
	return fgettext("No external host configured")
end

function wintercraft_hosting_sync_server_profiles()
	if not wintercraft_hosting_is_configured() then
		return wintercraft_get_server_profiles(), nil
	end

	local payload, err = request_hosting("GET", "/servers")
	if not payload then
		return wintercraft_get_server_profiles(), err
	end

	local raw_servers = payload.servers or payload.list or payload.data or payload
	if type(raw_servers) ~= "table" then
		return wintercraft_get_server_profiles(), fgettext("Hosting API returned an invalid server list.")
	end

	local by_id, by_name = get_profiles_lookup()
	local profiles = {}
	if #raw_servers > 0 then
		for _, item in ipairs(raw_servers) do
			local normalized = normalize_remote_server(item, by_id, by_name)
			if normalized then
				profiles[#profiles + 1] = normalized
			end
		end
	else
		for _, item in pairs(raw_servers) do
			local normalized = normalize_remote_server(item, by_id, by_name)
			if normalized then
				profiles[#profiles + 1] = normalized
			end
		end
	end

	wintercraft_save_server_profiles(profiles)
	return wintercraft_get_server_profiles(), nil
end

function wintercraft_hosting_create_server(profile)
	local normalized_input = {
		id = profile.id,
		name = as_trimmed_string(profile.name),
		description = as_trimmed_string(profile.description),
		admin_name = as_trimmed_string(profile.admin_name),
		admin_password = as_trimmed_string(profile.admin_password),
		host_address = as_trimmed_string(profile.host_address),
		host_port = tonumber(profile.host_port) or tonumber(core.settings:get("remote_port")) or 30000,
		hosting_managed = true,
	}

	if not wintercraft_hosting_is_configured() then
		local id = wintercraft_upsert_server_profile(normalized_input)
		return wintercraft_find_server_profile(id), nil
	end

	local payload, err = request_hosting("POST", "/servers", {
		name = normalized_input.name,
		description = normalized_input.description,
		admin_name = normalized_input.admin_name,
		admin_password = normalized_input.admin_password,
		gameid = core.settings:get("menu_last_game") or "",
	})
	if not payload then
		return nil, err
	end

	local by_id, by_name = get_profiles_lookup()
	local remote_profile = normalize_remote_server(extract_server_payload(payload), by_id, by_name, normalized_input)
	if not remote_profile then
		remote_profile = normalized_input
	end

	remote_profile.admin_name = normalized_input.admin_name
	remote_profile.admin_password = normalized_input.admin_password
	if remote_profile.name == "" then
		remote_profile.name = normalized_input.name
	end
	if remote_profile.host_address == "" then
		remote_profile.host_address = wintercraft_hosting_get_public_host()
	end

	local id = wintercraft_upsert_server_profile(remote_profile)
	return wintercraft_find_server_profile(id), nil
end

function wintercraft_hosting_update_server(profile)
	if not profile.id or profile.id == "" then
		return wintercraft_hosting_create_server(profile)
	end

	local normalized_input = {
		id = profile.id,
		name = as_trimmed_string(profile.name),
		description = as_trimmed_string(profile.description),
		admin_name = as_trimmed_string(profile.admin_name),
		admin_password = as_trimmed_string(profile.admin_password),
		host_address = as_trimmed_string(profile.host_address),
		host_port = tonumber(profile.host_port) or tonumber(core.settings:get("remote_port")) or 30000,
		hosting_managed = true,
	}

	if not wintercraft_hosting_is_configured() then
		local id = wintercraft_upsert_server_profile(normalized_input)
		return wintercraft_find_server_profile(id), nil
	end

	local encoded_id = core.urlencode(normalized_input.id)
	local payload, err = request_hosting("PUT", "/servers/" .. encoded_id, {
		name = normalized_input.name,
		description = normalized_input.description,
		admin_name = normalized_input.admin_name,
		admin_password = normalized_input.admin_password,
	}, "/servers/" .. encoded_id .. "/update")
	if not payload then
		return nil, err
	end

	local by_id, by_name = get_profiles_lookup()
	local remote_profile = normalize_remote_server(extract_server_payload(payload), by_id, by_name, normalized_input)
	if not remote_profile then
		remote_profile = normalized_input
	end

	remote_profile.admin_name = normalized_input.admin_name
	remote_profile.admin_password = normalized_input.admin_password
	if remote_profile.host_address == "" then
		remote_profile.host_address = wintercraft_hosting_get_public_host()
	end

	local id = wintercraft_upsert_server_profile(remote_profile)
	return wintercraft_find_server_profile(id), nil
end

function wintercraft_hosting_delete_server(profile_id)
	if not profile_id or profile_id == "" then
		return true, nil
	end

	if not wintercraft_hosting_is_configured() then
		wintercraft_delete_server_profile(profile_id)
		return true, nil
	end

	local encoded_id = core.urlencode(profile_id)
	local _, err = request_hosting("DELETE", "/servers/" .. encoded_id, nil, "/servers/" .. encoded_id .. "/delete")
	if err then
		return false, err
	end

	wintercraft_delete_server_profile(profile_id)
	return true, nil
end
