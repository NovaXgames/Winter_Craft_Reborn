-- Wintercraft Reborn
-- Copyright (C) 2026 NovaX_Games
-- SPDX-License-Identifier: LGPL-2.1-or-later

local WINTERCRAFT_SERVER_PROFILES_KEY = "wintercraft_server_profiles"

local function normalize_server_profile(profile)
	if type(profile) ~= "table" then
		return nil
	end

	local address = type(profile.address) == "string" and profile.address:trim() or ""
	if address == "" then
		return nil
	end

	return {
		address = address,
		port = tonumber(profile.port) or 30000,
		name = type(profile.name) == "string" and profile.name or "",
		description = type(profile.description) == "string" and profile.description or "",
		admin_name = type(profile.admin_name) == "string" and profile.admin_name or "",
		admin_password = type(profile.admin_password) == "string" and profile.admin_password or "",
	}
end

function wintercraft_server_profile_key(address, port)
	return ("%s:%d"):format((address or ""):trim(), tonumber(port) or 30000)
end

function wintercraft_get_server_profiles()
	local raw = core.settings:get(WINTERCRAFT_SERVER_PROFILES_KEY)
	if not raw or raw == "" then
		return {}
	end

	local decoded = core.deserialize(raw, true)
	if type(decoded) ~= "table" then
		return {}
	end

	local profiles = {}
	for _, profile in pairs(decoded) do
		local normalized = normalize_server_profile(profile)
		if normalized then
			profiles[wintercraft_server_profile_key(normalized.address, normalized.port)] = normalized
		end
	end

	return profiles
end

function wintercraft_get_server_profile(address, port)
	local profiles = wintercraft_get_server_profiles()
	return profiles[wintercraft_server_profile_key(address, port)]
end

function wintercraft_save_server_profiles(profiles)
	local cleaned = {}
	for _, profile in pairs(profiles or {}) do
		local normalized = normalize_server_profile(profile)
		if normalized then
			table.insert(cleaned, normalized)
		end
	end
	core.settings:set(WINTERCRAFT_SERVER_PROFILES_KEY, core.serialize(cleaned))
end

function wintercraft_upsert_server_profile(profile)
	local normalized = normalize_server_profile(profile)
	if not normalized then
		return
	end

	local profiles = wintercraft_get_server_profiles()
	profiles[wintercraft_server_profile_key(normalized.address, normalized.port)] = normalized
	wintercraft_save_server_profiles(profiles)
end

function wintercraft_delete_server_profile(address, port)
	local profiles = wintercraft_get_server_profiles()
	profiles[wintercraft_server_profile_key(address, port)] = nil
	wintercraft_save_server_profiles(profiles)
end
