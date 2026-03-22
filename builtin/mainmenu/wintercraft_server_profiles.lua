-- Wintercraft Reborn
-- Copyright (C) 2026 NovaX_Games
-- SPDX-License-Identifier: LGPL-2.1-or-later

local WINTERCRAFT_HOSTED_SERVER_PROFILES_KEY = "wintercraft_hosted_server_profiles"
local WINTERCRAFT_LEGACY_SERVER_PROFILES_KEY = "wintercraft_server_profiles"

local function default_host_address()
	return (core.settings:get("address") or ""):trim()
end

local function default_host_port()
	return tonumber(core.settings:get("remote_port")) or 30000
end

local function new_profile_id()
	return ("%d_%04d"):format(os.time(), math.random(1000, 9999))
end

local function normalize_server_profile(profile)
	if type(profile) ~= "table" then
		return nil
	end

	local id = type(profile.id) == "string" and profile.id or new_profile_id()
	local name = type(profile.name) == "string" and profile.name or ""
	local host_address = type(profile.host_address) == "string" and profile.host_address:trim() or ""
	if host_address == "" then
		host_address = type(profile.address) == "string" and profile.address:trim() or ""
	end
	if host_address == "" then
		host_address = default_host_address()
	end

	return {
		id = id,
		name = name,
		description = type(profile.description) == "string" and profile.description or "",
		admin_name = type(profile.admin_name) == "string" and profile.admin_name or "",
		admin_password = type(profile.admin_password) == "string" and profile.admin_password or "",
		host_address = host_address,
		host_port = tonumber(profile.host_port or profile.port) or default_host_port(),
		hosting_managed = profile.hosting_managed == true or profile.hosting_managed == "true",
	}
end

local function is_hosted_server_profile(profile)
	return profile and (
		profile.hosting_managed == true or
		(profile.name:trim() ~= "" and profile.admin_name:trim() ~= "" and profile.admin_password:trim() ~= "")
	)
end

local function decode_server_profiles(raw)
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
			table.insert(profiles, normalized)
		end
	end
	return profiles
end

local function sort_server_profiles(profiles)
	table.sort(profiles, function(a, b)
		local left = a.name ~= "" and a.name:lower() or a.id
		local right = b.name ~= "" and b.name:lower() or b.id
		return left < right
	end)
	return profiles
end

function wintercraft_get_server_profiles()
	local profiles = decode_server_profiles(core.settings:get(WINTERCRAFT_HOSTED_SERVER_PROFILES_KEY))
	if #profiles > 0 then
		return sort_server_profiles(profiles)
	end

	local legacy_profiles = decode_server_profiles(core.settings:get(WINTERCRAFT_LEGACY_SERVER_PROFILES_KEY))
	local migrated_profiles = {}
	for _, profile in ipairs(legacy_profiles) do
		if is_hosted_server_profile(profile) then
			table.insert(migrated_profiles, profile)
		end
	end

	if #migrated_profiles > 0 then
		wintercraft_save_server_profiles(migrated_profiles)
	end

	return sort_server_profiles(migrated_profiles)
end

function wintercraft_find_server_profile(profile_id)
	local profiles = wintercraft_get_server_profiles()
	for index, profile in ipairs(profiles) do
		if profile.id == profile_id then
			return profile, index
		end
	end
	return nil, nil
end

function wintercraft_save_server_profiles(profiles)
	local cleaned = {}
	for _, profile in ipairs(profiles or {}) do
		local normalized = normalize_server_profile(profile)
		if normalized and is_hosted_server_profile(normalized) then
			table.insert(cleaned, normalized)
		end
	end
	core.settings:set(WINTERCRAFT_HOSTED_SERVER_PROFILES_KEY, core.serialize(cleaned))
end

function wintercraft_upsert_server_profile(profile)
	local normalized = normalize_server_profile(profile)
	if not normalized then
		return nil
	end

	local profiles = wintercraft_get_server_profiles()
	local replaced = false
	for index, existing in ipairs(profiles) do
		if existing.id == normalized.id then
			profiles[index] = normalized
			replaced = true
			break
		end
	end

	if not replaced then
		table.insert(profiles, normalized)
	end

	wintercraft_save_server_profiles(profiles)
	return normalized.id
end

function wintercraft_delete_server_profile(profile_id)
	local profiles = wintercraft_get_server_profiles()
	for index, profile in ipairs(profiles) do
		if profile.id == profile_id then
			table.remove(profiles, index)
			break
		end
	end
	wintercraft_save_server_profiles(profiles)
end
