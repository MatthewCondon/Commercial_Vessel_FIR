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
--   Y Axis  = MAX (or AVG, MIN, SUM)
--   Y Field = nmea2000ig.heading   (or any field listed below)
--
-- AVAILABLE Y FIELDS (units after conversion):
--   nmea2000ig.heading       Vessel Heading (deg)
--   nmea2000ig.rudder_angle  Rudder Angle (deg)
--   nmea2000ig.cog           Course Over Ground (deg)
--   nmea2000ig.sog           Speed Over Ground (knots)
--   nmea2000ig.stw           Speed Through Water (knots)
--   nmea2000ig.wind_speed    Wind Speed (knots)
--   nmea2000ig.wind_angle    Wind Angle (deg)
--   nmea2000ig.set           Current Set (deg)
--   nmea2000ig.drift         Current Drift (knots)
--   nmea2000ig.pitch         Pitch (deg)
--   nmea2000ig.roll          Roll (deg)
--   nmea2000ig.yaw_rate      Rate of Turn (deg/s)
--   nmea2000ig.lat           Latitude (deg)
--   nmea2000ig.lon           Longitude (deg)
--   nmea2000ig.altitude      GNSS Altitude (m)
--   nmea2000ig.hdop          HDOP
--   nmea2000ig.pdop          PDOP
--   nmea2000ig.xte           Cross-Track Error (m)
--   nmea2000ig.depth         Water Depth (m)
--   nmea2000ig.water_temp    Water Temperature (K)
--   nmea2000ig.air_temp      Air Temperature (K)
--   nmea2000ig.rpm           Engine RPM
--   nmea2000ig.oil_pressure  Engine Oil Pressure (Pa)
--   nmea2000ig.coolant_temp  Engine Coolant Temp (K)
--   nmea2000ig.fuel_flow     Engine Fuel Rate (L/h)
--   nmea2000ig.trim_tab      Trim Tab Position (%)
--   nmea2000ig.boost_press   Boost Pressure (Pa)
--   nmea2000ig.trans_temp    Transmission Oil Temp (K)
--   nmea2000ig.bat_voltage   Battery Voltage (V)
--   nmea2000ig.bat_current   Battery Current (A)
--   nmea2000ig.raw_value     First numeric field found (fallback, no conversion)
--
-- DEBUGGING CONVERSIONS:
--   Expand any NMEA 2000 packet in Packet Details and look for the
--   "NMEA 2000 I/O Graph Values" subtree.  Key fields show both their raw
--   source value AND the converted output so you can verify the math, e.g.:
--
--     nmea2000ig.heading      = 45.0   <- what I/O Graph plots (degrees)
--     nmea2000ig.heading_raw  = 0.785  <- raw value from dissector (radians)
--
--   If heading_raw already shows degrees (e.g. 45.0, not 0.785) then your
--   dissector pre-converts -- set HEADING_IN_RAD = false below and reload.
--
-- TUNING FLAGS:
--   Set false if your dissector already delivers the value in the final unit.
--   HEADING_IN_RAD      true = raw is radians -> output degrees
--   RUDDER_IN_RAD       true = raw is radians -> output degrees
--   COG_IN_RAD          true = raw is radians -> output degrees
--   WIND_ANGLE_IN_RAD   true = raw is radians -> output degrees
--   SET_IN_RAD          true = raw is radians -> output degrees
--   PITCH_IN_RAD        true = raw is radians -> output degrees
--   ROLL_IN_RAD         true = raw is radians -> output degrees
--   YAW_RATE_IN_RAD     true = raw is rad/s   -> output deg/s
--   SOG_IN_MS           true = raw is m/s     -> output knots
--   STW_IN_MS           true = raw is m/s     -> output knots
--   WIND_SPEED_IN_MS    true = raw is m/s     -> output knots
--   DRIFT_IN_MS         true = raw is m/s     -> output knots
-- =============================================================================

local proto = Proto("nmea2000ig", "NMEA 2000 I/O Graph Helper")

-- ── Conversion flags ──────────────────────────────────────────────────────────

local HEADING_IN_RAD    = true
local RUDDER_IN_RAD     = true
local COG_IN_RAD        = true
local WIND_ANGLE_IN_RAD = true
local SET_IN_RAD        = true
local PITCH_IN_RAD      = true
local ROLL_IN_RAD       = true
local YAW_RATE_IN_RAD   = true

local SOG_IN_MS         = true
local STW_IN_MS         = true
local WIND_SPEED_IN_MS  = true
local DRIFT_IN_MS       = true

-- ── Conversion constants ──────────────────────────────────────────────────────

local RAD_TO_DEG = 180.0 / math.pi
local MS_TO_KT   = 1.94384

-- ── Output ProtoFields ────────────────────────────────────────────────────────

local pf = {
    -- Angular (degrees out)
    heading          = ProtoField.double("nmea2000ig.heading",          "Vessel Heading (deg)"),
    heading_raw      = ProtoField.double("nmea2000ig.heading_raw",      "Heading raw pre-conversion"),
    rudder_angle     = ProtoField.double("nmea2000ig.rudder_angle",     "Rudder Angle (deg)"),
    rudder_angle_raw = ProtoField.double("nmea2000ig.rudder_angle_raw", "Rudder raw pre-conversion"),
    cog              = ProtoField.double("nmea2000ig.cog",              "Course Over Ground (deg)"),
    cog_raw          = ProtoField.double("nmea2000ig.cog_raw",          "COG raw pre-conversion"),
    wind_angle       = ProtoField.double("nmea2000ig.wind_angle",       "Wind Angle (deg)"),
    wind_angle_raw   = ProtoField.double("nmea2000ig.wind_angle_raw",   "Wind angle raw pre-conversion"),
    set              = ProtoField.double("nmea2000ig.set",              "Current Set (deg)"),
    pitch            = ProtoField.double("nmea2000ig.pitch",            "Pitch (deg)"),
    roll             = ProtoField.double("nmea2000ig.roll",             "Roll (deg)"),
    yaw_rate         = ProtoField.double("nmea2000ig.yaw_rate",         "Rate of Turn (deg/s)"),

    -- Speed (knots out)
    sog              = ProtoField.double("nmea2000ig.sog",              "Speed Over Ground (knots)"),
    sog_raw          = ProtoField.double("nmea2000ig.sog_raw",          "SOG raw pre-conversion"),
    stw              = ProtoField.double("nmea2000ig.stw",              "Speed Through Water (knots)"),
    stw_raw          = ProtoField.double("nmea2000ig.stw_raw",          "STW raw pre-conversion"),
    wind_speed       = ProtoField.double("nmea2000ig.wind_speed",       "Wind Speed (knots)"),
    wind_speed_raw   = ProtoField.double("nmea2000ig.wind_speed_raw",   "Wind speed raw pre-conversion"),
    drift            = ProtoField.double("nmea2000ig.drift",            "Current Drift (knots)"),

    -- Passthrough
    lat          = ProtoField.double("nmea2000ig.lat",          "Latitude (deg)"),
    lon          = ProtoField.double("nmea2000ig.lon",          "Longitude (deg)"),
    altitude     = ProtoField.double("nmea2000ig.altitude",     "GNSS Altitude (m)"),
    hdop         = ProtoField.double("nmea2000ig.hdop",         "HDOP"),
    pdop         = ProtoField.double("nmea2000ig.pdop",         "PDOP"),
    xte          = ProtoField.double("nmea2000ig.xte",          "Cross-Track Error (m)"),
    depth        = ProtoField.double("nmea2000ig.depth",        "Water Depth (m)"),
    water_temp   = ProtoField.double("nmea2000ig.water_temp",   "Water Temperature (K)"),
    air_temp     = ProtoField.double("nmea2000ig.air_temp",     "Air Temperature (K)"),
    rpm          = ProtoField.double("nmea2000ig.rpm",          "Engine RPM"),
    oil_pressure = ProtoField.double("nmea2000ig.oil_pressure", "Engine Oil Pressure (Pa)"),
    coolant_temp = ProtoField.double("nmea2000ig.coolant_temp", "Engine Coolant Temp (K)"),
    fuel_flow    = ProtoField.double("nmea2000ig.fuel_flow",    "Engine Fuel Rate (L/h)"),
    trim_tab     = ProtoField.double("nmea2000ig.trim_tab",     "Trim Tab Position (%)"),
    boost_press  = ProtoField.double("nmea2000ig.boost_press",  "Boost Pressure (Pa)"),
    trans_temp   = ProtoField.double("nmea2000ig.trans_temp",   "Transmission Oil Temp (K)"),
    bat_voltage  = ProtoField.double("nmea2000ig.bat_voltage",  "Battery Voltage (V)"),
    bat_current  = ProtoField.double("nmea2000ig.bat_current",  "Battery Current (A)"),
    raw_value    = ProtoField.double("nmea2000ig.raw_value",    "Raw Numeric Value (fallback)"),
}
proto.fields = pf

-- ── Source field name candidates ──────────────────────────────────────────────
-- Lists tried in order; first match wins.
-- Right-click any field in Packet Details -> Copy -> As Field Name to find yours.

local candidates = {
    heading      = { "nmea2000.heading", "nmea2000.vessel_heading", "n2k.heading" },
    rudder_angle = { "nmea2000.rudder_angle_order", "nmea2000.rudder_angle", "n2k.rudder_angle" },
    cog          = { "nmea2000.cog", "n2k.cog", "nmea2000.course_over_ground" },
    sog          = { "nmea2000.sog", "n2k.sog", "nmea2000.speed_over_ground" },
    stw          = { "nmea2000.stw", "nmea2000.speed_through_water" },
    wind_speed   = { "nmea2000.wind_speed", "n2k.wind_speed" },
    wind_angle   = { "nmea2000.wind_angle", "n2k.wind_angle" },
    set          = { "nmea2000.set", "nmea2000.current_set" },
    drift        = { "nmea2000.drift", "nmea2000.current_drift" },
    pitch        = { "nmea2000.pitch", "n2k.pitch" },
    roll         = { "nmea2000.roll",  "n2k.roll"  },
    yaw_rate     = { "nmea2000.rate_of_turn", "nmea2000.yaw_rate" },
    lat          = { "nmea2000.lat", "nmea2000.latitude",  "n2k.lat" },
    lon          = { "nmea2000.lon", "nmea2000.longitude", "n2k.lon" },
    altitude     = { "nmea2000.altitude", "nmea2000.gnss_altitude", "n2k.altitude" },
    hdop         = { "nmea2000.hdop", "nmea2000.horizontal_dilution_of_precision" },
    pdop         = { "nmea2000.pdop", "nmea2000.position_dilution_of_precision" },
    xte          = { "nmea2000.xte", "nmea2000.cross_track_error" },
    depth        = { "nmea2000.depth", "nmea2000.water_depth", "n2k.depth" },
    water_temp   = { "nmea2000.water_temperature", "nmea2000.water_temp", "n2k.water_temperature" },
    air_temp     = { "nmea2000.outside_ambient_air_temperature", "nmea2000.air_temperature", "nmea2000.air_temp" },
    rpm          = { "nmea2000.engine_speed", "nmea2000.rpm", "n2k.engine_speed" },
    oil_pressure = { "nmea2000.oil_pressure", "nmea2000.engine_oil_pressure" },
    coolant_temp = { "nmea2000.coolant_temperature", "nmea2000.engine_coolant_temperature" },
    fuel_flow    = { "nmea2000.engine_fuel_rate", "nmea2000.fuel_rate", "nmea2000.fuel_flow" },
    trim_tab     = { "nmea2000.trim_tab_position", "nmea2000.trim_tab" },
    boost_press  = { "nmea2000.boost_pressure" },
    trans_temp   = { "nmea2000.transmission_oil_temperature", "nmea2000.trans_oil_temp" },
    bat_voltage  = { "nmea2000.voltage", "nmea2000.battery_voltage", "n2k.voltage" },
    bat_current  = { "nmea2000.current", "nmea2000.battery_current", "n2k.current" },
}

-- ── Lazy extractor cache ──────────────────────────────────────────────────────

local extractor_cache = {}
local initialized     = false

local function build_extractors()
    for key, names in pairs(candidates) do
        extractor_cache[key] = nil
        for _, name in ipairs(names) do
            local ok, result = pcall(Field.new, name)
            if ok and result then
                extractor_cache[key] = result
                break
            end
        end
    end
    initialized = true
end

local function raw(key)
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
    if not initialized then build_extractors() end

    -- Only act on NMEA 2000 packets
    local all_fi = { all_field_infos() }
    local is_n2k = false
    for _, fi in ipairs(all_fi) do
        local n = fi.name or ""
        if n:sub(1, 9) == "nmea2000." or n:sub(1, 4) == "n2k." then
            is_n2k = true; break
        end
    end
    if not is_n2k then return end

    local subtree = tree:add(proto, tvb(), "NMEA 2000 I/O Graph Values")
    local wrote   = false

    -- Heading (deg) -----------------------------------------------------------
    do
        local v = raw("heading")
        if v then
            subtree:add(pf.heading_raw, v)
            subtree:add(pf.heading, HEADING_IN_RAD and (v * RAD_TO_DEG) or v)
            wrote = true
        end
    end

    -- Rudder angle (deg) ------------------------------------------------------
    do
        local v = raw("rudder_angle")
        if v then
            subtree:add(pf.rudder_angle_raw, v)
            subtree:add(pf.rudder_angle, RUDDER_IN_RAD and (v * RAD_TO_DEG) or v)
            wrote = true
        end
    end

    -- COG (deg) ---------------------------------------------------------------
    do
        local v = raw("cog")
        if v then
            subtree:add(pf.cog_raw, v)
            subtree:add(pf.cog, COG_IN_RAD and (v * RAD_TO_DEG) or v)
            wrote = true
        end
    end

    -- SOG (knots) -------------------------------------------------------------
    do
        local v = raw("sog")
        if v then
            subtree:add(pf.sog_raw, v)
            subtree:add(pf.sog, SOG_IN_MS and (v * MS_TO_KT) or v)
            wrote = true
        end
    end

    -- STW (knots) -------------------------------------------------------------
    do
        local v = raw("stw")
        if v then
            subtree:add(pf.stw_raw, v)
            subtree:add(pf.stw, STW_IN_MS and (v * MS_TO_KT) or v)
            wrote = true
        end
    end

    -- Wind speed (knots) ------------------------------------------------------
    do
        local v = raw("wind_speed")
        if v then
            subtree:add(pf.wind_speed_raw, v)
            subtree:add(pf.wind_speed, WIND_SPEED_IN_MS and (v * MS_TO_KT) or v)
            wrote = true
        end
    end

    -- Wind angle (deg) --------------------------------------------------------
    do
        local v = raw("wind_angle")
        if v then
            subtree:add(pf.wind_angle_raw, v)
            subtree:add(pf.wind_angle, WIND_ANGLE_IN_RAD and (v * RAD_TO_DEG) or v)
            wrote = true
        end
    end

    -- Current set (deg) -------------------------------------------------------
    do
        local v = raw("set")
        if v then
            subtree:add(pf.set, SET_IN_RAD and (v * RAD_TO_DEG) or v)
            wrote = true
        end
    end

    -- Current drift (knots) ---------------------------------------------------
    do
        local v = raw("drift")
        if v then
            subtree:add(pf.drift, DRIFT_IN_MS and (v * MS_TO_KT) or v)
            wrote = true
        end
    end

    -- Pitch (deg) -------------------------------------------------------------
    do
        local v = raw("pitch")
        if v then
            subtree:add(pf.pitch, PITCH_IN_RAD and (v * RAD_TO_DEG) or v)
            wrote = true
        end
    end

    -- Roll (deg) --------------------------------------------------------------
    do
        local v = raw("roll")
        if v then
            subtree:add(pf.roll, ROLL_IN_RAD and (v * RAD_TO_DEG) or v)
            wrote = true
        end
    end

    -- Rate of turn (deg/s) ----------------------------------------------------
    do
        local v = raw("yaw_rate")
        if v then
            subtree:add(pf.yaw_rate, YAW_RATE_IN_RAD and (v * RAD_TO_DEG) or v)
            wrote = true
        end
    end

    -- Passthrough fields (no unit conversion) ---------------------------------
    local passthrough = {
        "lat","lon","altitude","hdop","pdop","xte","depth",
        "water_temp","air_temp","rpm","oil_pressure","coolant_temp",
        "fuel_flow","trim_tab","boost_press","trans_temp","bat_voltage","bat_current",
    }
    for _, key in ipairs(passthrough) do
        local v = raw(key)
        if v then subtree:add(pf[key], v); wrote = true end
    end

    -- Fallback: first numeric nmea2000 field for unrecognised PGNs ------------
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
-- 1. Add ProtoField.double entries to pf{} (output + optional _raw debug field)
-- 2. Add candidate source names to candidates{}
-- 3. Add a do...end block in proto.dissector with the conversion you need
-- 4. Reload: Ctrl+Shift+L
--
-- TO DISCOVER YOUR EXACT FIELD NAMES:
--   Packet Details pane -> expand any NMEA 2000 packet ->
--   right-click a field -> Copy -> As Field Name
-- =============================================================================