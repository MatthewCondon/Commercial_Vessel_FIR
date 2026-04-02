-- =============================================================================
-- nmea2000_iograph.lua
-- Wireshark Lua plugin: expose NMEA 2000 field values for I/O Graph plotting
--
-- INSTALL:
--   Copy to your Wireshark plugins folder:
--     Windows : %APPDATA%\Wireshark\plugins\
--     macOS   : ~/.local/lib/wireshark/plugins/
--     Linux   : ~/.local/lib/wireshark/plugins/
--   Reload with Ctrl+Shift+L or restart Wireshark.
--
-- USAGE:
--   Statistics > I/O Graph > Add graph
--   Y Axis  = MAX  (or AVG, MIN, SUM)
--   Y Field = nmea2000ig.sog   (or any field listed below)
--   Display Filter = nmea2000.pgn == 129026   (optional, isolates one PGN)
--
-- AVAILABLE Y FIELDS:
--   nmea2000ig.sog           Speed Over Ground (m/s)
--   nmea2000ig.cog           Course Over Ground (rad)
--   nmea2000ig.lat           Latitude (deg)
--   nmea2000ig.lon           Longitude (deg)
--   nmea2000ig.altitude      GNSS Altitude (m)
--   nmea2000ig.hdop          HDOP
--   nmea2000ig.pdop          PDOP
--   nmea2000ig.heading       Vessel Heading (rad)
--   nmea2000ig.xte           Cross-Track Error (m)
--   nmea2000ig.stw           Speed Through Water (m/s)
--   nmea2000ig.depth         Water Depth (m)
--   nmea2000ig.water_temp    Water Temperature (K)
--   nmea2000ig.air_temp      Air Temperature (K)
--   nmea2000ig.wind_speed    Wind Speed (m/s)
--   nmea2000ig.wind_angle    Wind Angle (rad)
--   nmea2000ig.set           Current Set (rad)
--   nmea2000ig.drift         Current Drift (m/s)
--   nmea2000ig.rpm           Engine RPM
--   nmea2000ig.oil_pressure  Engine Oil Pressure (Pa)
--   nmea2000ig.coolant_temp  Engine Coolant Temperature (K)
--   nmea2000ig.fuel_flow     Engine Fuel Rate (L/h)
--   nmea2000ig.trim_tab      Trim Tab Position (%)
--   nmea2000ig.boost_press   Boost Pressure (Pa)
--   nmea2000ig.trans_temp    Transmission Oil Temperature (K)
--   nmea2000ig.bat_voltage   Battery Voltage (V)
--   nmea2000ig.bat_current   Battery Current (A)
--   nmea2000ig.pitch         Pitch (rad)
--   nmea2000ig.roll          Roll (rad)
--   nmea2000ig.yaw_rate      Rate of Turn (rad/s)
--   nmea2000ig.rudder_angle  Rudder Angle (rad)
--   nmea2000ig.raw_value     First numeric field found (fallback for any PGN)
-- =============================================================================

local proto = Proto("nmea2000ig", "NMEA 2000 I/O Graph Helper")

-- ── Output ProtoFields (these are what I/O Graph sees) ───────────────────────

local pf = {
    sog          = ProtoField.double("nmea2000ig.sog",          "Speed Over Ground (m/s)"),
    cog          = ProtoField.double("nmea2000ig.cog",          "Course Over Ground (rad)"),
    lat          = ProtoField.double("nmea2000ig.lat",          "Latitude (deg)"),
    lon          = ProtoField.double("nmea2000ig.lon",          "Longitude (deg)"),
    altitude     = ProtoField.double("nmea2000ig.altitude",     "GNSS Altitude (m)"),
    hdop         = ProtoField.double("nmea2000ig.hdop",         "HDOP"),
    pdop         = ProtoField.double("nmea2000ig.pdop",         "PDOP"),
    heading      = ProtoField.double("nmea2000ig.heading",      "Vessel Heading (rad)"),
    xte          = ProtoField.double("nmea2000ig.xte",          "Cross-Track Error (m)"),
    stw          = ProtoField.double("nmea2000ig.stw",          "Speed Through Water (m/s)"),
    depth        = ProtoField.double("nmea2000ig.depth",        "Water Depth (m)"),
    water_temp   = ProtoField.double("nmea2000ig.water_temp",   "Water Temperature (K)"),
    air_temp     = ProtoField.double("nmea2000ig.air_temp",     "Air Temperature (K)"),
    wind_speed   = ProtoField.double("nmea2000ig.wind_speed",   "Wind Speed (m/s)"),
    wind_angle   = ProtoField.double("nmea2000ig.wind_angle",   "Wind Angle (rad)"),
    set          = ProtoField.double("nmea2000ig.set",          "Current Set (rad)"),
    drift        = ProtoField.double("nmea2000ig.drift",        "Current Drift (m/s)"),
    rpm          = ProtoField.double("nmea2000ig.rpm",          "Engine RPM"),
    oil_pressure = ProtoField.double("nmea2000ig.oil_pressure", "Engine Oil Pressure (Pa)"),
    coolant_temp = ProtoField.double("nmea2000ig.coolant_temp", "Engine Coolant Temp (K)"),
    fuel_flow    = ProtoField.double("nmea2000ig.fuel_flow",    "Engine Fuel Rate (L/h)"),
    trim_tab     = ProtoField.double("nmea2000ig.trim_tab",     "Trim Tab Position (%)"),
    boost_press  = ProtoField.double("nmea2000ig.boost_press",  "Boost Pressure (Pa)"),
    trans_temp   = ProtoField.double("nmea2000ig.trans_temp",   "Transmission Oil Temp (K)"),
    bat_voltage  = ProtoField.double("nmea2000ig.bat_voltage",  "Battery Voltage (V)"),
    bat_current  = ProtoField.double("nmea2000ig.bat_current",  "Battery Current (A)"),
    pitch        = ProtoField.double("nmea2000ig.pitch",        "Pitch (rad)"),
    roll         = ProtoField.double("nmea2000ig.roll",         "Roll (rad)"),
    yaw_rate     = ProtoField.double("nmea2000ig.yaw_rate",     "Rate of Turn (rad/s)"),
    rudder_angle = ProtoField.double("nmea2000ig.rudder_angle", "Rudder Angle (rad)"),
    raw_value    = ProtoField.double("nmea2000ig.raw_value",    "Raw Numeric Value (fallback)"),
}
proto.fields = pf

-- ── Candidate source field names per output field ─────────────────────────────
-- Each entry is a list of field names to try in order.
-- Field.new() is called lazily inside pcall, so unknown names never crash us.
-- To find YOUR exact names: expand a packet, right-click any field ->
-- Copy -> As Field Name, then add it to the relevant list below.

local candidates = {
    sog          = { "nmea2000.sog", "n2k.sog", "nmea2000.speed_over_ground" },
    cog          = { "nmea2000.cog", "n2k.cog", "nmea2000.course_over_ground" },
    lat          = { "nmea2000.lat", "nmea2000.latitude",  "n2k.lat" },
    lon          = { "nmea2000.lon", "nmea2000.longitude", "n2k.lon" },
    altitude     = { "nmea2000.altitude", "nmea2000.gnss_altitude", "n2k.altitude" },
    hdop         = { "nmea2000.hdop", "nmea2000.horizontal_dilution_of_precision" },
    pdop         = { "nmea2000.pdop", "nmea2000.position_dilution_of_precision" },
    heading      = { "nmea2000.heading", "nmea2000.vessel_heading", "n2k.heading" },
    xte          = { "nmea2000.xte", "nmea2000.cross_track_error" },
    stw          = { "nmea2000.stw", "nmea2000.speed_through_water" },
    depth        = { "nmea2000.depth", "nmea2000.water_depth", "n2k.depth" },
    water_temp   = { "nmea2000.water_temperature", "nmea2000.water_temp", "n2k.water_temperature" },
    air_temp     = { "nmea2000.outside_ambient_air_temperature", "nmea2000.air_temperature", "nmea2000.air_temp" },
    wind_speed   = { "nmea2000.wind_speed", "n2k.wind_speed" },
    wind_angle   = { "nmea2000.wind_angle", "n2k.wind_angle" },
    set          = { "nmea2000.set", "nmea2000.current_set" },
    drift        = { "nmea2000.drift", "nmea2000.current_drift" },
    rpm          = { "nmea2000.engine_speed", "nmea2000.rpm", "n2k.engine_speed" },
    oil_pressure = { "nmea2000.oil_pressure", "nmea2000.engine_oil_pressure" },
    coolant_temp = { "nmea2000.coolant_temperature", "nmea2000.engine_coolant_temperature" },
    fuel_flow    = { "nmea2000.engine_fuel_rate", "nmea2000.fuel_rate", "nmea2000.fuel_flow" },
    trim_tab     = { "nmea2000.trim_tab_position", "nmea2000.trim_tab" },
    boost_press  = { "nmea2000.boost_pressure" },
    trans_temp   = { "nmea2000.transmission_oil_temperature", "nmea2000.trans_oil_temp" },
    bat_voltage  = { "nmea2000.voltage", "nmea2000.battery_voltage", "n2k.voltage" },
    bat_current  = { "nmea2000.current", "nmea2000.battery_current", "n2k.current" },
    pitch        = { "nmea2000.pitch", "n2k.pitch" },
    roll         = { "nmea2000.roll",  "n2k.roll"  },
    yaw_rate     = { "nmea2000.rate_of_turn", "nmea2000.yaw_rate" },
    rudder_angle = { "nmea2000.rudder_angle_order", "nmea2000.rudder_angle", "n2k.rudder_angle" },
}

-- Processing order for the dissector loop
local field_order = {
    "sog","cog","lat","lon","altitude","hdop","pdop","heading","xte","stw",
    "depth","water_temp","air_temp","wind_speed","wind_angle","set","drift",
    "rpm","oil_pressure","coolant_temp","fuel_flow","trim_tab","boost_press",
    "trans_temp","bat_voltage","bat_current","pitch","roll","yaw_rate","rudder_angle",
}

-- ── Lazy extractor cache ──────────────────────────────────────────────────────
-- Built on the first packet, AFTER all dissectors are loaded.
-- Uses pcall so a missing field name never raises an error.

local extractor_cache = {}
local initialized     = false

local function build_extractors()
    for key, names in pairs(candidates) do
        extractor_cache[key] = nil          -- default: not found
        for _, name in ipairs(names) do
            local ok, result = pcall(Field.new, name)
            if ok and result then
                extractor_cache[key] = result
                break                       -- stop at first working name
            end
        end
    end
    initialized = true
end

-- ── Safely call an extractor and return a number or nil ──────────────────────

local function read_field(key)
    local ext = extractor_cache[key]
    if not ext then return nil end
    local ok, fi = pcall(ext)
    if not ok or not fi then return nil end
    local v = tonumber(fi.value)
    if v and v == v then return v end   -- v==v rejects NaN
    return nil
end

-- ── Post-dissector ────────────────────────────────────────────────────────────

function proto.dissector(tvb, pinfo, tree)
    -- Build extractor cache on first packet (all dissectors are loaded by now)
    if not initialized then build_extractors() end

    -- Only act on NMEA 2000 packets
    local all_fi = { all_field_infos() }
    local is_n2k = false
    for _, fi in ipairs(all_fi) do
        local n = fi.name or ""
        if n:sub(1, 9) == "nmea2000." or n:sub(1, 4) == "n2k." then
            is_n2k = true
            break
        end
    end
    if not is_n2k then return end

    local subtree = tree:add(proto, tvb(), "NMEA 2000 I/O Graph Values")
    local wrote   = false

    for _, key in ipairs(field_order) do
        local v = read_field(key)
        if v then
            subtree:add(pf[key], v)
            wrote = true
        end
    end

    -- Fallback: expose the first numeric nmea2000 field for unknown PGNs
    if not wrote then
        for _, fi in ipairs(all_fi) do
            local n = fi.name or ""
            if (n:sub(1, 9) == "nmea2000." or n:sub(1, 4) == "n2k.")
               and n ~= "nmea2000.pgn" and n ~= "n2k.pgn"
            then
                local v = tonumber(fi.value)
                if v and v == v then
                    subtree:add(pf.raw_value, v)
                    break
                end
            end
        end
    end
end

register_postdissector(proto)

-- =============================================================================
-- ADDING A FIELD FOR A NEW PGN
-- =============================================================================
-- 1. Add a ProtoField.double entry to the pf{} table
-- 2. Add the field name(s) to try in the candidates{} table
-- 3. Add the key string to the field_order list
-- 4. Reload: Ctrl+Shift+L
--
-- TO DISCOVER YOUR EXACT FIELD NAMES:
--   Packet Details pane -> expand any NMEA 2000 packet ->
--   right-click a field -> Copy -> As Field Name
-- =============================================================================
