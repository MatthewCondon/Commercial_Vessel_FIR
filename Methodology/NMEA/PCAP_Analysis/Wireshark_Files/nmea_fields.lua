-- nmea_fields.lua  v12
-- NMEA 0183 decoded fields + graphable numeric fields + AIS payload decoding
--
-- INSTALL:
--   %APPDATA%\Roaming\Wireshark\plugins\nmea_fields.lua
-- Reload with:
--   Ctrl+Shift+L

print("[nmea_fields v12] Loading...")

local fi_talker = Field.new("nmea-0183.talkerid")
local fi_sid    = Field.new("nmea-0183.sentenceid")
local fi_data   = Field.new("nmea-0183.data")

local p = Proto("nmea_decoded", "NMEA 0183 Decoded Fields")

local PS   = ProtoField.string
local PF   = ProtoField.float
local PU8  = ProtoField.uint8
local PU16 = ProtoField.uint16
local PU32 = ProtoField.uint32
local PI32 = ProtoField.int32
local PBOOL= ProtoField.bool

local pf = {
    sentence  = PS("nmea_decoded.sentence", "Sentence"),

    -- ── HDT ──
    hdt_hdg   = PF("nmea_decoded.hdt.heading", "Heading (° True)"),

    -- ── ROT ──
    rot_rate  = PF("nmea_decoded.rot.rate",   "Rate of Turn (°/min)"),
    rot_dir   = PS("nmea_decoded.rot.dir",    "Turn Direction"),
    rot_sta   = PS("nmea_decoded.rot.status", "Status"),

    -- ── VTG ──
    vtg_cogt  = PF("nmea_decoded.vtg.cogt",   "Course Over Ground (°True)"),
    vtg_cogm  = PF("nmea_decoded.vtg.cogm",   "Course Over Ground (°Mag)"),
    vtg_kn    = PF("nmea_decoded.vtg.kn",     "Speed Over Ground (kn)"),
    vtg_kmh   = PF("nmea_decoded.vtg.kmh",    "Speed Over Ground (km/h)"),

    -- ── GGA ──
    gga_utc   = PS("nmea_decoded.gga.utc",    "UTC Time"),
    gga_lat   = PS("nmea_decoded.gga.lat",    "Latitude"),
    gga_lon   = PS("nmea_decoded.gga.lon",    "Longitude"),
    gga_lat_dd= PF("nmea_decoded.gga.lat_dd", "Latitude (Decimal Degrees)"),
    gga_lon_dd= PF("nmea_decoded.gga.lon_dd", "Longitude (Decimal Degrees)"),
    gga_fix   = PS("nmea_decoded.gga.fix",    "Fix Quality"),
    gga_sat   = PF("nmea_decoded.gga.sat",    "Satellites in Use"),
    gga_hdop  = PF("nmea_decoded.gga.hdop",   "HDOP"),
    gga_alt   = PF("nmea_decoded.gga.alt",    "Altitude (m MSL)"),

    -- ── RMC ──
    rmc_utc   = PS("nmea_decoded.rmc.utc",    "UTC Time"),
    rmc_sta   = PS("nmea_decoded.rmc.stat",   "Status"),
    rmc_lat   = PS("nmea_decoded.rmc.lat",    "Latitude"),
    rmc_lon   = PS("nmea_decoded.rmc.lon",    "Longitude"),
    rmc_lat_dd= PF("nmea_decoded.rmc.lat_dd", "Latitude (Decimal Degrees)"),
    rmc_lon_dd= PF("nmea_decoded.rmc.lon_dd", "Longitude (Decimal Degrees)"),
    rmc_sog   = PF("nmea_decoded.rmc.sog",    "Speed Over Ground (kn)"),
    rmc_cog   = PF("nmea_decoded.rmc.cog",    "Course Over Ground (°T)"),
    rmc_dat   = PS("nmea_decoded.rmc.date",   "Date"),
    rmc_var   = PF("nmea_decoded.rmc.var",    "Magnetic Variation (°)"),

    -- ── GLL ──
    gll_lat   = PS("nmea_decoded.gll.lat",    "Latitude"),
    gll_lon   = PS("nmea_decoded.gll.lon",    "Longitude"),
    gll_lat_dd= PF("nmea_decoded.gll.lat_dd", "Latitude (Decimal Degrees)"),
    gll_lon_dd= PF("nmea_decoded.gll.lon_dd", "Longitude (Decimal Degrees)"),
    gll_utc   = PS("nmea_decoded.gll.utc",    "UTC Time"),
    gll_sta   = PS("nmea_decoded.gll.stat",   "Status"),

    -- ── VHW ──
    vhw_hdgt  = PF("nmea_decoded.vhw.hdgt",   "Heading True (°)"),
    vhw_hdgm  = PF("nmea_decoded.vhw.hdgm",   "Heading Magnetic (°)"),
    vhw_kn    = PF("nmea_decoded.vhw.kn",     "Speed Through Water (kn)"),
    vhw_kmh   = PF("nmea_decoded.vhw.kmh",    "Speed Through Water (km/h)"),

    -- ── VDR ──
    vdr_sett  = PF("nmea_decoded.vdr.sett",   "Current Set Direction (°T)"),
    vdr_setm  = PF("nmea_decoded.vdr.setm",   "Current Set Direction (°M)"),
    vdr_drft  = PF("nmea_decoded.vdr.drift",  "Current Drift Speed (kn)"),

    -- ── VLW ──
    vlw_tot   = PF("nmea_decoded.vlw.total",  "Total Cumulative Distance (nm)"),
    vlw_trp   = PF("nmea_decoded.vlw.trip",   "Trip Distance (nm)"),

    -- ── VBW ──
    vbw_lsw   = PF("nmea_decoded.vbw.lsw",    "Long. Water Speed (kn)"),
    vbw_tsw   = PF("nmea_decoded.vbw.tsw",    "Trans. Water Speed (kn)"),
    vbw_svw   = PS("nmea_decoded.vbw.svw",    "Water Speed Status"),
    vbw_lsg   = PF("nmea_decoded.vbw.lsg",    "Long. Ground Speed (kn)"),
    vbw_tsg   = PF("nmea_decoded.vbw.tsg",    "Trans. Ground Speed (kn)"),
    vbw_ssg   = PS("nmea_decoded.vbw.ssg",    "Ground Speed Status"),

    -- ── MWV ──
    mwv_ang   = PF("nmea_decoded.mwv.angle",  "Wind Angle (°)"),
    mwv_ref   = PS("nmea_decoded.mwv.ref",    "Reference"),
    mwv_spd   = PF("nmea_decoded.mwv.spd",    "Wind Speed"),
    mwv_sta   = PS("nmea_decoded.mwv.stat",   "Status"),

    -- ── ZDA ──
    zda_utc   = PS("nmea_decoded.zda.utc",    "UTC Time"),
    zda_day   = PS("nmea_decoded.zda.day",    "Day"),
    zda_mon   = PS("nmea_decoded.zda.mon",    "Month"),
    zda_yr    = PS("nmea_decoded.zda.year",   "Year"),

    -- ── RMB ──
    rmb_sta   = PS("nmea_decoded.rmb.stat",   "Status"),
    rmb_xte   = PF("nmea_decoded.rmb.xte",    "Cross-Track Error (nm)"),
    rmb_dir   = PS("nmea_decoded.rmb.dir",    "Steer Direction"),
    rmb_org   = PS("nmea_decoded.rmb.orig",   "From Waypoint"),
    rmb_dst   = PS("nmea_decoded.rmb.dest",   "To Waypoint"),
    rmb_lat   = PS("nmea_decoded.rmb.lat",    "Dest Latitude"),
    rmb_lon   = PS("nmea_decoded.rmb.lon",    "Dest Longitude"),
    rmb_rng   = PF("nmea_decoded.rmb.rng",    "Range to Dest (nm)"),
    rmb_brg   = PF("nmea_decoded.rmb.brg",    "Bearing to Dest (°T)"),
    rmb_vel   = PF("nmea_decoded.rmb.vel",    "Closing Velocity (kn)"),
    rmb_arr   = PS("nmea_decoded.rmb.arr",    "Arrival Status"),

    -- ── APB ──
    apb_sta   = PS("nmea_decoded.apb.stat",   "Status"),
    apb_xte   = PF("nmea_decoded.apb.xte",    "Cross-Track Error (nm)"),
    apb_dir   = PS("nmea_decoded.apb.dir",    "Steer Direction"),
    apb_arr   = PS("nmea_decoded.apb.arr",    "Arrival Circle"),
    apb_per   = PS("nmea_decoded.apb.perp",   "Passed Perpendicular"),
    apb_wpt   = PS("nmea_decoded.apb.wpt",    "Destination Waypoint"),
    apb_brd   = PF("nmea_decoded.apb.brd",    "Bearing to Dest (°T)"),
    apb_hdg   = PF("nmea_decoded.apb.hdg",    "Heading to Steer (°M)"),

    -- ── XDR ──
    xdr_rdg   = PS("nmea_decoded.xdr.rdg",    "Transducer Reading"),

    -- ── DTM ──
    dtm_loc   = PS("nmea_decoded.dtm.local",  "Local Datum"),
    dtm_lat   = PS("nmea_decoded.dtm.lat",    "Lat Offset"),
    dtm_lon   = PS("nmea_decoded.dtm.lon",    "Lon Offset"),
    dtm_alt   = PF("nmea_decoded.dtm.alt",    "Alt Offset (m)"),
    dtm_ref   = PS("nmea_decoded.dtm.ref",    "Reference Datum"),

    -- ── ZTG ──
    ztg_utc   = PS("nmea_decoded.ztg.utc",    "UTC Time"),
    ztg_ttg   = PS("nmea_decoded.ztg.ttg",    "Time-to-Go"),
    ztg_wpt   = PS("nmea_decoded.ztg.wpt",    "Destination Waypoint"),

    -- ── ALR ──
    alr_tim   = PS("nmea_decoded.alr.time",   "Alarm Time"),
    alr_num   = PS("nmea_decoded.alr.num",    "Alarm ID"),
    alr_cnd   = PS("nmea_decoded.alr.cond",   "Alarm Condition"),
    alr_ack   = PS("nmea_decoded.alr.ack",    "Acknowledge State"),
    alr_txt   = PS("nmea_decoded.alr.text",   "Alarm Text"),

    -- ── AIS base/raw ──
    ais_tot     = PS("nmea_decoded.ais.total",      "Total Sentences"),
    ais_num     = PS("nmea_decoded.ais.num",        "Sentence Number"),
    ais_mid     = PS("nmea_decoded.ais.msgid",      "Seq Message ID"),
    ais_ch      = PS("nmea_decoded.ais.chan",       "Radio Channel"),
    ais_pay_raw = PS("nmea_decoded.ais.payload_raw","Payload (Armored Raw)"),
    ais_bits    = PS("nmea_decoded.ais.bits",       "Payload Bits"),
    ais_fil     = PS("nmea_decoded.ais.fill",       "Fill Bits"),

    -- AIS common decoded
    ais_msgtype = PU8("nmea_decoded.ais.msgtype",    "AIS Message Type"),
    ais_repeat  = PU8("nmea_decoded.ais.repeat",     "AIS Repeat Indicator"),
    ais_mmsi    = PU32("nmea_decoded.ais.mmsi",      "AIS MMSI"),
    ais_partno  = PU8("nmea_decoded.ais.partno",     "AIS Part Number"),

    -- AIS text/static
    ais_text_dec= PS("nmea_decoded.ais.text",        "AIS Decoded Text"),
    ais_imo     = PU32("nmea_decoded.ais.imo",       "IMO Number"),
    ais_callsign= PS("nmea_decoded.ais.callsign",    "Call Sign"),
    ais_name    = PS("nmea_decoded.ais.name",        "Vessel Name"),
    ais_shiptype= PU8("nmea_decoded.ais.shiptype",   "Ship Type"),
    ais_vendor  = PS("nmea_decoded.ais.vendor",      "Vendor ID"),
    ais_model   = PU8("nmea_decoded.ais.model",      "Unit Model Code"),
    ais_serial  = PU32("nmea_decoded.ais.serial",    "Unit Serial Number"),
    ais_mother  = PU32("nmea_decoded.ais.mothership","Mothership MMSI"),

    -- AIS dimensions
    ais_to_bow   = PU16("nmea_decoded.ais.to_bow",   "Dimension to Bow (m)"),
    ais_to_stern = PU16("nmea_decoded.ais.to_stern", "Dimension to Stern (m)"),
    ais_to_port  = PU8("nmea_decoded.ais.to_port",   "Dimension to Port (m)"),
    ais_to_star  = PU8("nmea_decoded.ais.to_star",   "Dimension to Starboard (m)"),

    -- AIS dynamic/position
    ais_navstat  = PU8("nmea_decoded.ais.navstat",   "Navigation Status"),
    ais_rot_raw  = PI32("nmea_decoded.ais.rot_raw",  "Rate of Turn Raw"),
    ais_sog      = PF("nmea_decoded.ais.sog",        "Speed Over Ground (kn)"),
    ais_posacc   = PBOOL("nmea_decoded.ais.posacc",  "Position Accuracy"),
    ais_lon      = PF("nmea_decoded.ais.lon",        "Longitude"),
    ais_lat      = PF("nmea_decoded.ais.lat",        "Latitude"),
    ais_cog      = PF("nmea_decoded.ais.cog",        "Course Over Ground (°)"),
    ais_hdg      = PF("nmea_decoded.ais.hdg",        "True Heading (°)"),
    ais_ts       = PU8("nmea_decoded.ais.ts",        "Timestamp (s)"),
    ais_raim     = PBOOL("nmea_decoded.ais.raim",    "RAIM Flag"),
    ais_epfd     = PU8("nmea_decoded.ais.epfd",      "EPFD Type"),
    ais_dte      = PBOOL("nmea_decoded.ais.dte",     "DTE"),
    ais_assigned = PBOOL("nmea_decoded.ais.assigned","Assigned Mode"),
    ais_band     = PBOOL("nmea_decoded.ais.band",    "Band Flag"),
    ais_display  = PBOOL("nmea_decoded.ais.display", "Display Flag"),
    ais_dsc      = PBOOL("nmea_decoded.ais.dsc",     "DSC Flag"),
    ais_msg22    = PBOOL("nmea_decoded.ais.msg22",   "Msg 22 Flag"),
    ais_classb   = PBOOL("nmea_decoded.ais.classb",  "Class B CS Unit"),
}

p.fields = (function()
    local t = {}
    for _, v in pairs(pf) do
        t[#t+1] = v
    end
    return t
end)()

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function csv(s)
    local t = {}
    for part in (s .. ","):gmatch("([^,]*),") do
        t[#t+1] = part:gsub("[\r\n]+$", "")
    end
    return t
end

local function f(fs, n)   return fs[n] or "" end
local function fn(fs, n)  return tonumber(fs[n]) or 0 end

local function latlon(dm, hemi)
    if dm == "" then return "(empty)" end
    local d = (hemi == "N" or hemi == "S") and 2 or 3
    return dm:sub(1, d) .. "° " .. dm:sub(d + 1) .. "' " .. hemi
end

local function nmea_to_dd(dm, hemi)
    if dm == "" or hemi == "" then return nil end
    local deg_len = (hemi == "N" or hemi == "S") and 2 or 3
    local deg = tonumber(dm:sub(1, deg_len))
    local min = tonumber(dm:sub(deg_len + 1))
    if not deg or not min then return nil end
    local dd = deg + (min / 60.0)
    if hemi == "S" or hemi == "W" then
        dd = -dd
    end
    return dd
end

local function hms(t)
    if #t < 6 then return t end
    return t:sub(1,2) .. ":" .. t:sub(3,4) .. ":" .. t:sub(5) .. " UTC"
end

local function dmy(d)
    if #d < 6 then return d end
    return d:sub(1,2) .. "/" .. d:sub(3,4) .. "/" .. d:sub(5,6)
end

local function av(v)
    return v == "A" and "Active/Valid"
        or v == "V" and "Void/Invalid"
        or (v == "" and "(empty)" or v)
end

local FIX = {
    ["0"]="No Fix", ["1"]="GPS", ["2"]="DGPS", ["3"]="PPS",
    ["4"]="RTK Fixed", ["5"]="RTK Float", ["6"]="DR",
    ["7"]="Manual", ["8"]="Simulation"
}

local function twos_complement(u, width)
    local sign = 2^(width - 1)
    if u >= sign then
        return u - 2^width
    end
    return u
end

-- AIS 6-bit text table
local AIS_TXT = {
    [0]='@',[1]='A',[2]='B',[3]='C',[4]='D',[5]='E',[6]='F',[7]='G',
    [8]='H',[9]='I',[10]='J',[11]='K',[12]='L',[13]='M',[14]='N',[15]='O',
    [16]='P',[17]='Q',[18]='R',[19]='S',[20]='T',[21]='U',[22]='V',[23]='W',
    [24]='X',[25]='Y',[26]='Z',[27]='[',[28]='\\',[29]=']',[30]='^',[31]='_',
    [32]=' ',[33]='!',[34]='"',[35]='#',[36]='$',[37]='%',[38]='&',[39]="'",
    [40]='(',[41]=')',[42]='*',[43]='+',[44]=',',[45]='-',[46]='.',[47]='/',
    [48]='0',[49]='1',[50]='2',[51]='3',[52]='4',[53]='5',[54]='6',[55]='7',
    [56]='8',[57]='9',[58]=':',[59]=';',[60]='<',[61]='=',[62]='>',[63]='?'
}

local function ais6_to_val(ch)
    local b = string.byte(ch)
    if not b then return nil end
    local v = b - 48
    if v > 40 then v = v - 8 end
    if v < 0 or v > 63 then return nil end
    return v
end

local function val_to_6bits(v)
    local out = {}
    for i = 5, 0, -1 do
        out[#out+1] = tostring(math.floor(v / (2^i)) % 2)
    end
    return table.concat(out)
end

local function ais_payload_to_bits(payload, fill_bits)
    local t = {}
    for i = 1, #payload do
        local v = ais6_to_val(payload:sub(i, i))
        if v == nil then
            return nil, "bad AIS char at " .. i
        end
        t[#t+1] = val_to_6bits(v)
    end
    local bits = table.concat(t)
    fill_bits = tonumber(fill_bits) or 0
    if fill_bits > 0 and fill_bits < 6 and #bits >= fill_bits then
        bits = bits:sub(1, #bits - fill_bits)
    end
    return bits
end

local function ubits(bitstr, start_bit, width)
    local s = start_bit + 1
    local e = start_bit + width
    if s > #bitstr or e > #bitstr then return nil end
    local v = 0
    for i = s, e do
        v = v * 2
        if bitstr:sub(i, i) == "1" then
            v = v + 1
        end
    end
    return v
end

local function sbits(bitstr, start_bit, width)
    local u = ubits(bitstr, start_bit, width)
    if u == nil then return nil end
    return twos_complement(u, width)
end

local function ais_text(bitstr, start_bit, width)
    local out = {}
    for i = 0, width - 6, 6 do
        local v = ubits(bitstr, start_bit + i, 6)
        if v == nil then break end
        out[#out+1] = AIS_TXT[v] or "?"
    end
    local s = table.concat(out)
    s = s:gsub("@+$", "")
    s = s:gsub("%s+$", "")
    s = s:gsub("^%s+", "")
    return s
end

local function add_if(tree, field, val)
    if val ~= nil then
        tree:add(field, val)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- AIS decoders
-- ─────────────────────────────────────────────────────────────────────────────

local function decode_position_A(t, bits)
    add_if(t, pf.ais_navstat, ubits(bits, 38, 4))
    add_if(t, pf.ais_rot_raw, sbits(bits, 42, 8))

    local sog    = ubits(bits, 50, 10)
    local posacc = ubits(bits, 60, 1)
    local lon    = sbits(bits, 61, 28)
    local lat    = sbits(bits, 89, 27)
    local cog    = ubits(bits, 116, 12)
    local hdg    = ubits(bits, 128, 9)
    local ts     = ubits(bits, 137, 6)
    local raim   = ubits(bits, 148, 1)

    if sog and sog < 1023 then t:add(pf.ais_sog, sog / 10.0) end
    if posacc ~= nil then t:add(pf.ais_posacc, posacc == 1) end
    if lon ~= nil and lon ~= 0x6791AC0 then t:add(pf.ais_lon, lon / 600000.0) end
    if lat ~= nil and lat ~= 0x3412140 then t:add(pf.ais_lat, lat / 600000.0) end
    if cog and cog < 3600 then t:add(pf.ais_cog, cog / 10.0) end
    if hdg and hdg < 511 then t:add(pf.ais_hdg, hdg) end
    add_if(t, pf.ais_ts, ts)
    if raim ~= nil then t:add(pf.ais_raim, raim == 1) end
end

local function decode_position_B18(t, bits)
    local sog      = ubits(bits, 46, 10)
    local posacc   = ubits(bits, 56, 1)
    local lon      = sbits(bits, 57, 28)
    local lat      = sbits(bits, 85, 27)
    local cog      = ubits(bits, 112, 12)
    local hdg      = ubits(bits, 124, 9)
    local ts       = ubits(bits, 133, 6)
    local csunit   = ubits(bits, 141, 1)
    local display  = ubits(bits, 142, 1)
    local dsc      = ubits(bits, 143, 1)
    local band     = ubits(bits, 144, 1)
    local msg22    = ubits(bits, 145, 1)
    local assigned = ubits(bits, 146, 1)
    local raim     = ubits(bits, 148, 1)

    if sog and sog < 1023 then t:add(pf.ais_sog, sog / 10.0) end
    if posacc ~= nil then t:add(pf.ais_posacc, posacc == 1) end
    if lon ~= nil and lon ~= 0x6791AC0 then t:add(pf.ais_lon, lon / 600000.0) end
    if lat ~= nil and lat ~= 0x3412140 then t:add(pf.ais_lat, lat / 600000.0) end
    if cog and cog < 3600 then t:add(pf.ais_cog, cog / 10.0) end
    if hdg and hdg < 511 then t:add(pf.ais_hdg, hdg) end
    add_if(t, pf.ais_ts, ts)
    if csunit   ~= nil then t:add(pf.ais_classb, csunit == 1) end
    if display  ~= nil then t:add(pf.ais_display, display == 1) end
    if dsc      ~= nil then t:add(pf.ais_dsc, dsc == 1) end
    if band     ~= nil then t:add(pf.ais_band, band == 1) end
    if msg22    ~= nil then t:add(pf.ais_msg22, msg22 == 1) end
    if assigned ~= nil then t:add(pf.ais_assigned, assigned == 1) end
    if raim     ~= nil then t:add(pf.ais_raim, raim == 1) end
end

local function decode_ais_payload(t, payload, fill_bits)
    local bits, err = ais_payload_to_bits(payload, fill_bits)
    if not bits then
        return nil, err
    end

    t:add(pf.ais_bits, bits)

    local msgtype = ubits(bits, 0, 6)
    local repeati = ubits(bits, 6, 2)
    local mmsi    = ubits(bits, 8, 30)

    add_if(t, pf.ais_msgtype, msgtype)
    add_if(t, pf.ais_repeat, repeati)
    add_if(t, pf.ais_mmsi, mmsi)

    if msgtype == 1 or msgtype == 2 or msgtype == 3 then
        decode_position_A(t, bits)

    elseif msgtype == 5 then
        local imo      = ubits(bits, 40, 30)
        local callsign = ais_text(bits, 70, 42)
        local name     = ais_text(bits, 112, 120)
        local shiptype = ubits(bits, 232, 8)
        local to_bow   = ubits(bits, 240, 9)
        local to_stern = ubits(bits, 249, 9)
        local to_port  = ubits(bits, 258, 6)
        local to_star  = ubits(bits, 264, 6)
        local epfd     = ubits(bits, 270, 4)
        local dte      = ubits(bits, 302, 1)

        add_if(t, pf.ais_imo, imo)
        if callsign ~= "" then t:add(pf.ais_callsign, callsign) end
        if name ~= "" then
            t:add(pf.ais_name, name)
            t:add(pf.ais_text_dec, name)
        end
        add_if(t, pf.ais_shiptype, shiptype)
        add_if(t, pf.ais_to_bow, to_bow)
        add_if(t, pf.ais_to_stern, to_stern)
        add_if(t, pf.ais_to_port, to_port)
        add_if(t, pf.ais_to_star, to_star)
        add_if(t, pf.ais_epfd, epfd)
        if dte ~= nil then t:add(pf.ais_dte, dte == 1) end

    elseif msgtype == 18 then
        decode_position_B18(t, bits)

    elseif msgtype == 19 then
        local sog      = ubits(bits, 46, 10)
        local posacc   = ubits(bits, 56, 1)
        local lon      = sbits(bits, 57, 28)
        local lat      = sbits(bits, 85, 27)
        local cog      = ubits(bits, 112, 12)
        local hdg      = ubits(bits, 124, 9)
        local ts       = ubits(bits, 133, 6)
        local name     = ais_text(bits, 143, 120)
        local shiptype = ubits(bits, 263, 8)
        local to_bow   = ubits(bits, 271, 9)
        local to_stern = ubits(bits, 280, 9)
        local to_port  = ubits(bits, 289, 6)
        local to_star  = ubits(bits, 295, 6)
        local epfd     = ubits(bits, 301, 4)
        local assigned = ubits(bits, 305, 1)
        local dte      = ubits(bits, 306, 1)

        if sog and sog < 1023 then t:add(pf.ais_sog, sog / 10.0) end
        if posacc ~= nil then t:add(pf.ais_posacc, posacc == 1) end
        if lon ~= nil and lon ~= 0x6791AC0 then t:add(pf.ais_lon, lon / 600000.0) end
        if lat ~= nil and lat ~= 0x3412140 then t:add(pf.ais_lat, lat / 600000.0) end
        if cog and cog < 3600 then t:add(pf.ais_cog, cog / 10.0) end
        if hdg and hdg < 511 then t:add(pf.ais_hdg, hdg) end
        add_if(t, pf.ais_ts, ts)

        if name ~= "" then
            t:add(pf.ais_name, name)
            t:add(pf.ais_text_dec, name)
        end
        add_if(t, pf.ais_shiptype, shiptype)
        add_if(t, pf.ais_to_bow, to_bow)
        add_if(t, pf.ais_to_stern, to_stern)
        add_if(t, pf.ais_to_port, to_port)
        add_if(t, pf.ais_to_star, to_star)
        add_if(t, pf.ais_epfd, epfd)
        if assigned ~= nil then t:add(pf.ais_assigned, assigned == 1) end
        if dte ~= nil then t:add(pf.ais_dte, dte == 1) end

    elseif msgtype == 24 then
        local partno = ubits(bits, 38, 2)
        add_if(t, pf.ais_partno, partno)

        if partno == 0 then
            local name = ais_text(bits, 40, 120)
            if name ~= "" then
                t:add(pf.ais_name, name)
                t:add(pf.ais_text_dec, name)
            end
        elseif partno == 1 then
            local shiptype = ubits(bits, 40, 8)
            local vendor   = ais_text(bits, 48, 18)
            local model    = ubits(bits, 66, 4)
            local serial   = ubits(bits, 70, 20)
            local callsign = ais_text(bits, 90, 42)
            local to_bow   = ubits(bits, 132, 9)
            local to_stern = ubits(bits, 141, 9)
            local to_port  = ubits(bits, 150, 6)
            local to_star  = ubits(bits, 156, 6)
            local mother   = ubits(bits, 132, 30)

            add_if(t, pf.ais_shiptype, shiptype)
            if vendor ~= "" then
                t:add(pf.ais_vendor, vendor)
                t:add(pf.ais_text_dec, vendor)
            end
            add_if(t, pf.ais_model, model)
            add_if(t, pf.ais_serial, serial)
            if callsign ~= "" then t:add(pf.ais_callsign, callsign) end
            add_if(t, pf.ais_to_bow, to_bow)
            add_if(t, pf.ais_to_stern, to_stern)
            add_if(t, pf.ais_to_port, to_port)
            add_if(t, pf.ais_to_star, to_star)
            if mother and mother > 99999999 then
                t:add(pf.ais_mother, mother)
            end
        end

    elseif msgtype == 27 then
        local posacc = ubits(bits, 38, 1)
        local raim   = ubits(bits, 39, 1)
        local navstat= ubits(bits, 40, 4)
        local lon    = sbits(bits, 44, 18)
        local lat    = sbits(bits, 62, 17)
        local sog    = ubits(bits, 79, 6)
        local cog    = ubits(bits, 85, 9)
        local gnss   = ubits(bits, 94, 1)

        if posacc ~= nil then t:add(pf.ais_posacc, posacc == 1) end
        if raim   ~= nil then t:add(pf.ais_raim, raim == 1) end
        add_if(t, pf.ais_navstat, navstat)
        if lon ~= nil then t:add(pf.ais_lon, lon / 600.0) end
        if lat ~= nil then t:add(pf.ais_lat, lat / 600.0) end
        if sog ~= nil then t:add(pf.ais_sog, sog) end
        if cog ~= nil then t:add(pf.ais_cog, cog / 10.0) end
        add_if(t, pf.ais_epfd, gnss)
    end

    return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Sentence decoders
-- ─────────────────────────────────────────────────────────────────────────────

local dec = {}

dec.HDT = function(t, fs)
    t:add(pf.hdt_hdg, fn(fs, 1))
end

dec.ROT = function(t, fs)
    local r = fn(fs, 1)
    t:add(pf.rot_rate, r)
    t:add(pf.rot_dir, r > 0 and "Starboard (right)" or r < 0 and "Port (left)" or "No turn")
    t:add(pf.rot_sta, av(f(fs, 2)))
end

dec.VTG = function(t, fs)
    t:add(pf.vtg_cogt, fn(fs, 1))
    t:add(pf.vtg_cogm, fn(fs, 3))
    t:add(pf.vtg_kn,   fn(fs, 5))
    t:add(pf.vtg_kmh,  fn(fs, 7))
end

dec.GGA = function(t, fs)
    t:add(pf.gga_utc, hms(f(fs, 1)))
    t:add(pf.gga_lat, latlon(f(fs, 2), f(fs, 3)))
    t:add(pf.gga_lon, latlon(f(fs, 4), f(fs, 5)))

    local lat_dd = nmea_to_dd(f(fs, 2), f(fs, 3))
    local lon_dd = nmea_to_dd(f(fs, 4), f(fs, 5))
    if lat_dd then t:add(pf.gga_lat_dd, lat_dd) end
    if lon_dd then t:add(pf.gga_lon_dd, lon_dd) end

    t:add(pf.gga_fix, FIX[f(fs, 6)] or f(fs, 6))
    t:add(pf.gga_sat, fn(fs, 7))
    t:add(pf.gga_hdop, fn(fs, 8))
    t:add(pf.gga_alt, fn(fs, 9))
end

dec.RMC = function(t, fs)
    t:add(pf.rmc_utc, hms(f(fs, 1)))
    t:add(pf.rmc_sta, av(f(fs, 2)))
    t:add(pf.rmc_lat, latlon(f(fs, 3), f(fs, 4)))
    t:add(pf.rmc_lon, latlon(f(fs, 5), f(fs, 6)))

    local lat_dd = nmea_to_dd(f(fs, 3), f(fs, 4))
    local lon_dd = nmea_to_dd(f(fs, 5), f(fs, 6))
    if lat_dd then t:add(pf.rmc_lat_dd, lat_dd) end
    if lon_dd then t:add(pf.rmc_lon_dd, lon_dd) end

    t:add(pf.rmc_sog, fn(fs, 7))
    t:add(pf.rmc_cog, fn(fs, 8))
    t:add(pf.rmc_dat, dmy(f(fs, 9)))
    if f(fs, 10) ~= "" then
        t:add(pf.rmc_var, fn(fs, 10))
    end
end

dec.GLL = function(t, fs)
    t:add(pf.gll_lat, latlon(f(fs, 1), f(fs, 2)))
    t:add(pf.gll_lon, latlon(f(fs, 3), f(fs, 4)))

    local lat_dd = nmea_to_dd(f(fs, 1), f(fs, 2))
    local lon_dd = nmea_to_dd(f(fs, 3), f(fs, 4))
    if lat_dd then t:add(pf.gll_lat_dd, lat_dd) end
    if lon_dd then t:add(pf.gll_lon_dd, lon_dd) end

    t:add(pf.gll_utc, hms(f(fs, 5)))
    t:add(pf.gll_sta, av(f(fs, 6)))
end

dec.VHW = function(t, fs)
    t:add(pf.vhw_hdgt, fn(fs, 1))
    t:add(pf.vhw_hdgm, fn(fs, 3))
    t:add(pf.vhw_kn,   fn(fs, 5))
    t:add(pf.vhw_kmh,  fn(fs, 7))
end

dec.VDR = function(t, fs)
    t:add(pf.vdr_sett, fn(fs, 1))
    t:add(pf.vdr_setm, fn(fs, 3))
    t:add(pf.vdr_drft, fn(fs, 5))
end

dec.VLW = function(t, fs)
    t:add(pf.vlw_tot, fn(fs, 1))
    t:add(pf.vlw_trp, fn(fs, 3))
end

dec.VBW = function(t, fs)
    t:add(pf.vbw_lsw, fn(fs, 1))
    t:add(pf.vbw_tsw, fn(fs, 2))
    t:add(pf.vbw_svw, av(f(fs, 3)))
    t:add(pf.vbw_lsg, fn(fs, 4))
    t:add(pf.vbw_tsg, fn(fs, 5))
    t:add(pf.vbw_ssg, av(f(fs, 6)))
end

dec.MWV = function(t, fs)
    local ref = f(fs, 2)
    t:add(pf.mwv_ang, fn(fs, 1))
    t:add(pf.mwv_ref, ref == "R" and "Relative" or ref == "T" and "True" or ref)
    t:add(pf.mwv_spd, fn(fs, 3))
    t:add(pf.mwv_sta, av(f(fs, 5)))
end

dec.ZDA = function(t, fs)
    t:add(pf.zda_utc, hms(f(fs, 1)))
    t:add(pf.zda_day, f(fs, 2))
    t:add(pf.zda_mon, f(fs, 3))
    t:add(pf.zda_yr,  f(fs, 4))
end

dec.RMB = function(t, fs)
    t:add(pf.rmb_sta, av(f(fs, 1)))
    t:add(pf.rmb_xte, fn(fs, 2))
    local d = f(fs, 3)
    t:add(pf.rmb_dir, d == "L" and "Steer Left" or d == "R" and "Steer Right" or d)
    t:add(pf.rmb_org, f(fs, 4))
    t:add(pf.rmb_dst, f(fs, 5))
    t:add(pf.rmb_lat, latlon(f(fs, 6), f(fs, 7)))
    t:add(pf.rmb_lon, latlon(f(fs, 8), f(fs, 9)))
    t:add(pf.rmb_rng, fn(fs, 10))
    t:add(pf.rmb_brg, fn(fs, 11))
    t:add(pf.rmb_vel, fn(fs, 12))
    t:add(pf.rmb_arr, av(f(fs, 13)))
end

dec.APB = function(t, fs)
    t:add(pf.apb_sta, av(f(fs, 1)))
    t:add(pf.apb_xte, fn(fs, 3))
    local d = f(fs, 4)
    t:add(pf.apb_dir, d == "L" and "Steer Left" or d == "R" and "Steer Right" or d)
    t:add(pf.apb_arr, av(f(fs, 6)))
    t:add(pf.apb_per, av(f(fs, 7)))
    t:add(pf.apb_wpt, f(fs, 10))
    t:add(pf.apb_brd, fn(fs, 11))
    t:add(pf.apb_hdg, fn(fs, 13))
end

dec.XDR = function(t, fs)
    local TT = {
        A="Angular", C="Temperature", D="Depth", F="Frequency", G="Generic",
        H="Humidity", N="Force", P="Pressure", R="RPM", S="Switch",
        T="Temperature", U="Voltage", V="Volume", Z="Salinity"
    }
    local i = 1
    while f(fs, i) ~= "" do
        t:add(pf.xdr_rdg, string.format(
            "%s: %s%s  id=%s",
            TT[f(fs, i)] or f(fs, i),
            f(fs, i + 1),
            f(fs, i + 2),
            f(fs, i + 3)
        ))
        i = i + 4
    end
end

dec.DTM = function(t, fs)
    t:add(pf.dtm_loc, f(fs, 1))
    t:add(pf.dtm_lat, f(fs, 3) .. "' " .. f(fs, 4))
    t:add(pf.dtm_lon, f(fs, 5) .. "' " .. f(fs, 6))
    t:add(pf.dtm_alt, fn(fs, 7))
    t:add(pf.dtm_ref, f(fs, 8))
end

dec.ZTG = function(t, fs)
    t:add(pf.ztg_utc, hms(f(fs, 1)))
    t:add(pf.ztg_ttg, hms(f(fs, 2)))
    t:add(pf.ztg_wpt, f(fs, 3))
end

dec.ALR = function(t, fs)
    t:add(pf.alr_tim, hms(f(fs, 1)))
    t:add(pf.alr_num, f(fs, 2))
    local c = f(fs, 3)
    t:add(pf.alr_cnd, c == "A" and "ALARM – Threshold Exceeded" or c == "V" and "Normal" or c)
    local a = f(fs, 4)
    t:add(pf.alr_ack, a == "A" and "Acknowledged" or a == "V" and "Not Acknowledged" or a)
    local txt = (f(fs, 5) or ""):gsub(",$", ""):match("^%s*(.-)%s*$")
    t:add(pf.alr_txt, txt == "" and "(none)" or txt)
end

local function dec_ais(t, fs)
    local total = f(fs, 1)
    local num   = f(fs, 2)
    local msgid = f(fs, 3)
    local ch    = f(fs, 4)
    local pay   = f(fs, 5)
    local fill  = f(fs, 6)

    t:add(pf.ais_tot, total .. " sentence(s)")
    t:add(pf.ais_num, num .. " of " .. total)
    t:add(pf.ais_mid, msgid == "" and "(single)" or msgid)
    t:add(pf.ais_ch, ch == "A" and "A – 161.975 MHz" or ch == "B" and "B – 162.025 MHz" or ch)
    t:add(pf.ais_pay_raw, pay)
    t:add(pf.ais_fil, fill .. " bit(s)")

    -- Decode only single-fragment payloads here.
    if total == "1" and pay ~= "" then
        decode_ais_payload(t, pay, fill)
    end
end

dec.VDM = dec_ais
dec.VDO = dec_ais

-- ─────────────────────────────────────────────────────────────────────────────
-- Post-dissector
-- ─────────────────────────────────────────────────────────────────────────────

function p.dissector(tvb, pinfo, root)
    local talker_fi = fi_talker()
    local sid_fi    = fi_sid()
    local data_fi   = fi_data()

    if not talker_fi or not sid_fi then
        return
    end

    local talker = tostring(talker_fi.value)
    local sid    = tostring(sid_fi.value):upper()
    local data   = data_fi and tostring(data_fi.value) or ""

    local subtree = root:add(p, tvb(), string.format("NMEA Decoded ▸ %s%s", talker, sid))
    subtree:add(pf.sentence, talker .. sid)

    local decoder = dec[sid]
    if decoder then
        local ok, err = pcall(decoder, subtree, csv(data))
        if not ok then
            print("[nmea_fields] ERROR [" .. sid .. "]: " .. tostring(err))
        end
    end
end

register_postdissector(p)
print("[nmea_fields v12] Ready")
