local S = minetest.get_translator("skygazer")

local hud_position = {
	x= tonumber(minetest.settings:get("skygazer_hud_x")) or 0.9,
	y= tonumber(minetest.settings:get("skygazer_hud_y")) or 0.3,
}
local hud_color = tonumber("0x" .. (minetest.settings:get("skygazer_hud_color") or "FFFF00")) or 0xFFFF00
local hud_timeout = tonumber(minetest.settings:get("skygazer_hud_timeout")) or 60

-- 72 = 20min, 360 = 4min, 1 = 24hour, 0 = day/night/whatever stays unchanged.
local time_speed = tonumber(minetest.settings:get("time_speed")) or 72

local seconds_per_day
if time_speed ~= 0 then
	seconds_per_day = 86400 / time_speed
end

local default_day_night_ratio = 0.6

-- If round is true the return string will only have the two largest-scale values
local function clock_string(seconds, round)
	seconds = math.floor(seconds)
	local days = math.floor(seconds/86400)
	seconds = seconds - days*86400
	local hours = math.floor(seconds/3600)
	seconds = seconds - hours*3600
	local minutes = math.floor(seconds/60)
	seconds = seconds - minutes*60

	local ret = {}
	if days == 1 then
		table.insert(ret, S("1 day"))
	elseif days > 1 then
		table.insert(ret, S("@1 days", days))
	end
	if hours == 1 then
		table.insert(ret, S("1 hour"))
	elseif hours > 1 then
		table.insert(ret, S("@1 hours", hours))
	end
	if minutes == 1 then
		table.insert(ret, S("1 minute"))
	elseif minutes > 1 then
		table.insert(ret, S("@1 minutes", minutes))
	end
	if seconds == 1 then
		table.insert(ret, S("1 second"))
	elseif seconds > 1 then
		table.insert(ret, S("@1 seconds", seconds))
	end
	
	if #ret == 0 then
		return S("@1 seconds", 0)
	else
		return ret[1]
	end
--	if round or #ret == 2 then
--		return S("@1 and @2", ret[1], ret[2])
--	end
	
--	return table.concat(ret, S(", "))
end

local function get_time(timeofday, day_night_ratio)
	day_night_ratio = day_night_ratio or default_day_night_ratio
	local day_length = seconds_per_day * day_night_ratio
	local night_length = seconds_per_day - day_length
	local current_time = timeofday * seconds_per_day
	local half_night_length = night_length/2
	
	if current_time <  half_night_length then
		-- second half of the night
		local night_progress = half_night_length + current_time
		return S("@1 until dawn", clock_string(night_length-night_progress, true))
	elseif current_time < seconds_per_day - half_night_length then
		-- daytime
		local day_progress = current_time - half_night_length
		return S("@1 until sunset", clock_string(day_length-day_progress, true))
	else
		-- first half of the night
		local night_progress = current_time - half_night_length - day_length
		return S("@1 until dawn", clock_string(night_length-night_progress, true))
	end
end

local directions = {
	[0] = S("North"),
	S("North-northwest"),
	S("Northwest"),
	S("West-northwest"),
	S("West"),
	S("West-southwest"),
	S("Southwest"),
	S("South-southwest"),
	S("South"),
	S("South-southeast"),
	S("Southeast"),
	S("East-southeast"),
	S("East"),
	S("East-northeast"),
	S("Northeast"),
	S("North-northeast"),
}
local function get_heading(player)
	local dir = player:get_look_horizontal()
	local angle_dir = math.deg(dir)
	local index = math.floor((angle_dir/22.5) + 0.5)%16
	return S("Facing @1", directions[index])
end

local player_huds = {}
local function hide_hud(player)
	local player_name = player:get_player_name()
	local id = player_huds[player_name]
	if id then
		player:hud_remove(id)
		player_huds[player_name] = nil
	end
end
local function update_hud(player, timeofday, player_name, can_see_sky)
	local day_night_ratio = player:get_day_night_ratio()
	local description = get_time(timeofday, day_night_ratio) .. "\n" .. get_heading(player)
	if not can_see_sky then
		description = description .. "\n" .. S("The sky is out of view.")
	end
	local id = player_huds[player_name]
	if not id then
		id = player:hud_add({
			hud_elem_type = "text",
			position = hud_position,
			text = description,
			number = hud_color,
			scale = 20,
		})
		player_huds[player_name] = id
	else
		player:hud_change(id, "text", description)
	end
end

minetest.register_on_leaveplayer(function(player, timed_out)
	hide_hud(player)
end)

local player_last_saw_sky = {}
-- update inventory and hud
minetest.register_globalstep(function(dtime)
	local timeofday = minetest.get_timeofday()
	for i, player in ipairs(minetest.get_connected_players()) do
		local player_name = player:get_player_name()
		local pos = player:get_pos()
		local day_light = minetest.get_node_light(pos, 0.5)
		local night_light = minetest.get_node_light(pos, 0)
		if day_light ~= night_light then
			player_last_saw_sky[player_name] = 0
			update_hud(player, timeofday, player_name, true)
		else
			local last_saw = (player_last_saw_sky[player_name] or 0) + dtime
			player_last_saw_sky[player_name] = last_saw
			if last_saw > hud_timeout then
				hide_hud(player)
			else
				update_hud(player, timeofday, player_name, false)
			end
		end	
	end
end)