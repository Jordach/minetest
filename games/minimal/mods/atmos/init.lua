--[[
	Atmos, by Jordach

	This fork of atmos is designed to 
	be bundled with Minetest and
	thusly is licensed LGPL 2.1.
--]]

local atmos_enabled = true
local atmos_clear_weather = {}
local storage = minetest.get_modpath("atmos").."/skybox/"
local val = 0

for line in io.lines(storage.."skybox_clear_gradient.atm") do
	-- Index the skybox colours starting at 0,
	-- since minetest.get_timeofday() can return 0.
	atmos_clear_weather[val] = minetest.deserialize(line) 
	val = val + 1
end

local function atmos_ratio(current_data, next_data, time_percent)
	return current_data + (next_data - current_data) * time_percent
end

local function convert_hex(input_hex)
	-- Convert ColorSpec strings into individual intergers
	-- compatible with minetest.rgba().
	local r, g, b = input_hex:match("^#(%x%x)(%x%x)(%x%x)")
	return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

local function atmos_set_skybox(player)
	local current_time = minetest.get_timeofday() * 100
	-- Figure out our multiplier since get_timeofday returns 0 to 1,
	-- we can use the two decimal places as a 0-100 percentage multiplier.

	-- Contributed by @rubenwardy.
	local time_percent = math.floor(
		(current_time - math.floor(current_time)) * 100) / 100

	-- Fix for skyboxes randomly flickering when
	-- changing from one color to another.
	if time_percent == 0 then 
		time_percent = 0.01
	end

	local fade_factor =  math.floor(255 * time_percent)
	current_time = math.floor(current_time)

	-- Create the skybox textures that will be overlaid with each other.
	local side_string = "(atmos_sky.png^[multiply:"..
		atmos_clear_weather[current_time].bottom .. ")^" ..
		"(atmos_sky_top.png^[multiply:" ..
		atmos_clear_weather[current_time].top .. ")"

	local side_string_new = "(atmos_sky.png^[multiply:"..
		atmos_clear_weather[current_time+1].bottom .. ")^" ..
		"(atmos_sky_top.png^[multiply:" ..
		atmos_clear_weather[current_time+1].top .. ")"

	local sky_top = "(atmos_sky.png^[multiply:"..
		atmos_clear_weather[current_time].bottom ..
		")^(atmos_sky_top_radial.png^[multiply:" ..
		atmos_clear_weather[current_time].top .. ")"

	local sky_top_new = "(atmos_sky.png^[multiply:"..
		atmos_clear_weather[current_time+1].bottom ..
		")^(atmos_sky_top_radial.png^[multiply:" ..
		atmos_clear_weather[current_time+1].top .. ")"

	local sky_bottom = "(atmos_sky.png^[multiply:" ..
		atmos_clear_weather[current_time].bottom .. ")"

	local sky_bottom_new = "(atmos_sky.png^[multiply:" ..
		atmos_clear_weather[current_time+1].bottom .. ")"

	--[[
		Let's convert the base colour to convert it 
		into our transitioning fog colour:

		We need two tables for comparing, 
		as any matching pairs of hex will be skipped.
	]]--

	local fog = {}
	fog.current = {}
	fog.next = {}
	fog.result = {}
	
	-- Convert our hexidecial into compatible minetest.rgba() components:
	-- we need these to make our lives easier when it 
	-- comes to updating the sky.
	fog.current.r, fog.current.g, fog.current.b = convert_hex(
		atmos_clear_weather[current_time].base)
	fog.next.r, fog.next.g, fog.next.b = convert_hex(
		atmos_clear_weather[current_time+1].base)
	fog.result.r, fog.result.g, fog.result.b = 0


	if atmos_clear_weather[current_time].base ~= 
			atmos_clear_weather[current_time+1].base then
		-- We compare colours the same way we do it for the light level.
		fog.result.r = atmos_ratio(fog.current.r, fog.next.r, time_percent)
		fog.result.g = atmos_ratio(fog.current.g, fog.next.g, time_percent)
		fog.result.b = atmos_ratio(fog.current.b, fog.next.b, time_percent)
	else
		fog.result.r = fog.current.r
		fog.result.g = fog.current.g
		fog.result.b = fog.current.b
	end
	if atmos_clear_weather[current_time].bottom == 
				atmos_clear_weather[current_time+1].bottom then
		-- Prevent memory leakage from Irrlicht by
		-- using the same texture if the current skybox data
		-- is the same as the next skybox data.
		if atmos_clear_weather[current_time].top ==
				atmos_clear_weather[current_time+1].top then
			fade_factor = 0
		end
	end
	
	local tex_table = {
			sky_top .. "^(" .. sky_top_new ..
				"^[opacity:" .. fade_factor .. ")",
			sky_bottom .. "^(" .. sky_bottom_new ..
				"^[opacity:" .. fade_factor .. ")",
			side_string .. "^(" .. side_string_new .. "^[opacity:"
				.. fade_factor .. ")",
			side_string .. "^(" .. side_string_new .. "^[opacity:"
				.. fade_factor .. ")",
			side_string .. "^(" .. side_string_new .. "^[opacity:"
				.. fade_factor .. ")",
			side_string .. "^(" .. side_string_new .. "^[opacity:"
				.. fade_factor .. ")"
	}

	local ovl_table = {
			"atmos_nebula_top.png^[opacity:90",
			"atmos_nebula_bottom.png^[opacity:90",
			"atmos_nebula_east.png^[opacity:90",
			"atmos_nebula_west.png^[opacity:90",
			"atmos_nebula_south.png^[opacity:90",
			"atmos_nebula_north.png^[opacity:90"
	}
	
	local rgba = minetest.rgba(fog.result.r, fog.result.g, fog.result.b)

	player:set_sky({
		sky_color = rgba,
		type = "custom",
		textures = tex_table,
		clouds = true,
		default_fog = false,
		overlay_visible = true,
		sun = {
			visible = true,
			yaw = 105,
			tilt = -12,
			texture = "atmos_sun.png",
			sunrise_glow = true,
		},
		moon = {
			visible = true,
			yaw = -105,
			tilt = -12,
			texture = "atmos_moon.png",	
		},
		stars = {
			visible = true,
			yaw = 0,
			tilt = 0,
			count = 2400,	
		},
		overlay_textures = ovl_table,
	})

	local light_level = 0
	if atmos_clear_weather[current_time].light ==
			atmos_clear_weather[current_time+1].light then
		-- We do nothing, because there's nothing worth doing.
		light_level = atmos_clear_weather[current_time].light
	else
		-- Otherwise, we fade to the next light level. 
		light_level = atmos_ratio(atmos_clear_weather[current_time].light,
				atmos_clear_weather[current_time+1].light, time_percent)
	end
	-- Sanity checks, going over 1 makes it dark again
	-- as going under 0 makes it bright again.
	if light_level > 1 then light_level = 1 end
	if light_level < 0 then light_level = 0 end
	player:override_day_night_ratio(light_level)
end

local function atmos_sync_skybox()
	for _, player in ipairs(minetest.get_connected_players()) do
		-- Do not sync the current weather to players under -32 depth.
		if player:get_pos().y <= -32 then
			player:set_sky({
				sky_color = "#000000",
				type = "plain",
				textures = nil,
				clouds = false,
			})
			player:override_day_night_ratio(0)
		else
			atmos_set_skybox(player)
		end
	end
	minetest.after(0.1, atmos_sync_skybox)
end

if atmos_enabled then
	minetest.after(2, atmos_sync_skybox)
end

minetest.register_chatcommand("get_sky", {
	func = function(name, param)
		-- Dump all data asscociated with the set_sky command.
		local data = minetest.get_player_by_name(name):get_sky()
		print(dump(data))
	end
})