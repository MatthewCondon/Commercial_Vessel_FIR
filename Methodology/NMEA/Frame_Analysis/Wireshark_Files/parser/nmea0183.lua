-- nmea_fields.lua  v7  (correct field indexing)
--
-- Post-dissector on top of fkie-cad maritime-dissector.
-- Reads nmea-0183.talkerid / nmea-0183.sentenceid / nmea-0183.data
-- and adds a fully decoded subtree.
--
-- KEY INSIGHT (from reading fkie-cad source):
--   nmea-0183.data contains ONLY the CSV body after the sentence ID,
--   with no leading comma and no trailing *checksum.
--   e.g.  $HEHDT,040.8,T*23  →  data = "040.8,T"
--   So fs[1]="040.8", fs[2]="T"  (1-based, no placeholder needed)
--
-- INSTALL:
--   Windows: %APPDATA%\Wireshark\plugins\nmea_fields.lua
--   macOS:   ~/.config/wireshark/plugins/nmea_fields.lua
--   Linux:   ~/.config/wireshark/plugins/nmea_fields.lua
--   Then: Analyze → Reload Lua Plugins  (Ctrl+Shift+L)

local fi_talker = Field.new("nmea-0183.talkerid")
local fi_sid    = Field.new("nmea-0183.sentenceid")
local fi_data   = Field.new("nmea-0183.data")

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

-- Split on comma; fs[1] = first value
local function csv(s)
    local t = {}
    for part in (s .. ","):gmatch("([^,]*),") do
        t[#t+1] = part:gsub("[\r\n]+$","")
    end
    return t
end

local function f(fs, n)  return fs[n] or "" end

local function latlon(dm, hemi)
    if dm == "" then return "(empty)" end
    local d = (hemi=="N" or hemi=="S") and 2 or 3
    return dm:sub(1,d).."° "..dm:sub(d+1).."' "..hemi
end

local function hms(t)
    if #t < 6 then return t end
    return t:sub(1,2)..":"..t:sub(3,4)..":"..t:sub(5).." UTC"
end

local function dmy(d)
    if #d < 6 then return d end
    return d:sub(1,2).."/"..d:sub(3,4).."/"..d:sub(5,6)
end

local function av(v)
    return v=="A" and "Active/Valid" or v=="V" and "Void/Invalid" or (v=="" and "(empty)" or v)
end

local SU = {K="km/h", M="m/s", N="knots", S="mph"}

-- ─────────────────────────────────────────────────────────────────────────────
-- Proto + ProtoFields
-- ─────────────────────────────────────────────────────────────────────────────

local p  = Proto("nmea_decoded", "NMEA 0183 Decoded Fields")
local PS = ProtoField.string

local pf = {
    sentence = PS("nmea_decoded.sentence", "Sentence"),
    -- GGA (data: utc,lat,NS,lon,EW,fix,sats,hdop,alt,M,sep,M,,)
    gga_utc  = PS("nmea_decoded.gga.utc",  "UTC Time"),
    gga_lat  = PS("nmea_decoded.gga.lat",  "Latitude"),
    gga_lon  = PS("nmea_decoded.gga.lon",  "Longitude"),
    gga_fix  = PS("nmea_decoded.gga.fix",  "Fix Quality"),
    gga_sat  = PS("nmea_decoded.gga.sat",  "Satellites in Use"),
    gga_hdp  = PS("nmea_decoded.gga.hdop", "HDOP"),
    gga_alt  = PS("nmea_decoded.gga.alt",  "Altitude (MSL)"),
    gga_sep  = PS("nmea_decoded.gga.sep",  "Geoid Separation"),
    -- RMC (data: utc,status,lat,NS,lon,EW,sog,cog,date,var,varEW)
    rmc_utc  = PS("nmea_decoded.rmc.utc",  "UTC Time"),
    rmc_sta  = PS("nmea_decoded.rmc.stat", "Status"),
    rmc_lat  = PS("nmea_decoded.rmc.lat",  "Latitude"),
    rmc_lon  = PS("nmea_decoded.rmc.lon",  "Longitude"),
    rmc_sog  = PS("nmea_decoded.rmc.sog",  "Speed Over Ground (kn)"),
    rmc_cog  = PS("nmea_decoded.rmc.cog",  "Course Over Ground (°T)"),
    rmc_dat  = PS("nmea_decoded.rmc.date", "Date"),
    rmc_var  = PS("nmea_decoded.rmc.var",  "Magnetic Variation"),
    -- GLL (data: lat,NS,lon,EW,utc,status)
    gll_lat  = PS("nmea_decoded.gll.lat",  "Latitude"),
    gll_lon  = PS("nmea_decoded.gll.lon",  "Longitude"),
    gll_utc  = PS("nmea_decoded.gll.utc",  "UTC Time"),
    gll_sta  = PS("nmea_decoded.gll.stat", "Status"),
    -- VTG (data: cogt,T,cogm,M,sogn,N,sogk,K)
    vtg_cogt = PS("nmea_decoded.vtg.cogt", "Course Over Ground (True)"),
    vtg_cogm = PS("nmea_decoded.vtg.cogm", "Course Over Ground (Magnetic)"),
    vtg_kn   = PS("nmea_decoded.vtg.kn",   "Speed Over Ground (kn)"),
    vtg_kmh  = PS("nmea_decoded.vtg.kmh",  "Speed Over Ground (km/h)"),
    -- ZDA (data: utc,day,month,year,lzh,lzm)
    zda_utc  = PS("nmea_decoded.zda.utc",  "UTC Time"),
    zda_day  = PS("nmea_decoded.zda.day",  "Day"),
    zda_mon  = PS("nmea_decoded.zda.mon",  "Month"),
    zda_yr   = PS("nmea_decoded.zda.year", "Year"),
    -- RMB (data: status,xte,dir,orig,dest,dlat,NS,dlon,EW,range,bearing,vel,arr)
    rmb_sta  = PS("nmea_decoded.rmb.stat", "Status"),
    rmb_xte  = PS("nmea_decoded.rmb.xte",  "Cross-Track Error (nm)"),
    rmb_dir  = PS("nmea_decoded.rmb.dir",  "Steer Direction"),
    rmb_org  = PS("nmea_decoded.rmb.orig", "From Waypoint"),
    rmb_dst  = PS("nmea_decoded.rmb.dest", "To Waypoint"),
    rmb_lat  = PS("nmea_decoded.rmb.lat",  "Dest Latitude"),
    rmb_lon  = PS("nmea_decoded.rmb.lon",  "Dest Longitude"),
    rmb_rng  = PS("nmea_decoded.rmb.rng",  "Range to Dest (nm)"),
    rmb_brg  = PS("nmea_decoded.rmb.brg",  "Bearing to Dest (°T)"),
    rmb_vel  = PS("nmea_decoded.rmb.vel",  "Closing Velocity (kn)"),
    rmb_arr  = PS("nmea_decoded.rmb.arr",  "Arrival Status"),
    -- APB (data: blink,cycle,xte,dir,units,arr,perp,bear_orig,T,dest,bear_dest,T,hdg,M)
    apb_sta  = PS("nmea_decoded.apb.stat", "Status"),
    apb_xte  = PS("nmea_decoded.apb.xte",  "Cross-Track Error (nm)"),
    apb_dir  = PS("nmea_decoded.apb.dir",  "Steer Direction"),
    apb_arr  = PS("nmea_decoded.apb.arr",  "Arrival Circle Entered"),
    apb_per  = PS("nmea_decoded.apb.perp", "Passed Perpendicular"),
    apb_bor  = PS("nmea_decoded.apb.bor",  "Bearing Origin→Dest"),
    apb_wpt  = PS("nmea_decoded.apb.wpt",  "Destination Waypoint"),
    apb_brd  = PS("nmea_decoded.apb.brd",  "Bearing to Dest (°T)"),
    apb_hdg  = PS("nmea_decoded.apb.hdg",  "Heading to Steer (°M)"),
    -- HDT (data: heading,T)
    hdt_hdg  = PS("nmea_decoded.hdt.heading", "Heading (° True)"),
    -- ROT (data: rate,status)
    rot_rt   = PS("nmea_decoded.rot.rate",   "Rate of Turn (°/min)"),
    rot_dir  = PS("nmea_decoded.rot.dir",    "Turn Direction"),
    rot_sta  = PS("nmea_decoded.rot.status", "Status"),
    -- VHW (data: hdgt,T,hdgm,M,stwn,N,stwk,K)
    vhw_hdgt = PS("nmea_decoded.vhw.hdgt",  "Heading True (°)"),
    vhw_hdgm = PS("nmea_decoded.vhw.hdgm",  "Heading Magnetic (°)"),
    vhw_kn   = PS("nmea_decoded.vhw.kn",    "Speed Through Water (kn)"),
    vhw_kmh  = PS("nmea_decoded.vhw.kmh",   "Speed Through Water (km/h)"),
    -- VDR (data: degt,T,degm,M,speed,N)
    vdr_sett = PS("nmea_decoded.vdr.sett",  "Current Set Direction (°T)"),
    vdr_setm = PS("nmea_decoded.vdr.setm",  "Current Set Direction (°M)"),
    vdr_drft = PS("nmea_decoded.vdr.drift", "Current Drift Speed (kn)"),
    -- VLW (data: total,N,trip,N)
    vlw_tot  = PS("nmea_decoded.vlw.total", "Total Cumulative Distance (nm)"),
    vlw_trp  = PS("nmea_decoded.vlw.trip",  "Trip Distance (nm)"),
    -- VBW (data: lsw,tsw,svw,lsg,tsg,ssg)
    vbw_lsw  = PS("nmea_decoded.vbw.lsw",  "Long. Water Speed (kn)"),
    vbw_tsw  = PS("nmea_decoded.vbw.tsw",  "Trans. Water Speed (kn)"),
    vbw_svw  = PS("nmea_decoded.vbw.svw",  "Water Speed Status"),
    vbw_lsg  = PS("nmea_decoded.vbw.lsg",  "Long. Ground Speed (kn)"),
    vbw_tsg  = PS("nmea_decoded.vbw.tsg",  "Trans. Ground Speed (kn)"),
    vbw_ssg  = PS("nmea_decoded.vbw.ssg",  "Ground Speed Status"),
    -- MWV (data: angle,ref,speed,units,status)
    mwv_ang  = PS("nmea_decoded.mwv.angle", "Wind Angle (°)"),
    mwv_ref  = PS("nmea_decoded.mwv.ref",   "Reference"),
    mwv_spd  = PS("nmea_decoded.mwv.speed", "Wind Speed"),
    mwv_sta  = PS("nmea_decoded.mwv.stat",  "Status"),
    -- XDR (data: type,val,unit,id [repeating])
    xdr_rdg  = PS("nmea_decoded.xdr.rdg",  "Transducer Reading"),
    -- DTM (data: ldatum,lsd,latoff,NS,lonoff,EW,altoff,rdatum)
    dtm_loc  = PS("nmea_decoded.dtm.local",  "Local Datum"),
    dtm_lat  = PS("nmea_decoded.dtm.lat",    "Lat Offset"),
    dtm_lon  = PS("nmea_decoded.dtm.lon",    "Lon Offset"),
    dtm_alt  = PS("nmea_decoded.dtm.alt",    "Alt Offset (m)"),
    dtm_ref  = PS("nmea_decoded.dtm.ref",    "Reference Datum"),
    -- ZTG (data: utc,ttg,wpt)
    ztg_utc  = PS("nmea_decoded.ztg.utc",   "UTC Time"),
    ztg_ttg  = PS("nmea_decoded.ztg.ttg",   "Time-to-Go"),
    ztg_wpt  = PS("nmea_decoded.ztg.wpt",   "Destination Waypoint"),
    -- ALR (data: time,num,cond,ack,text)
    alr_tim  = PS("nmea_decoded.alr.time",  "Alarm Time"),
    alr_num  = PS("nmea_decoded.alr.num",   "Alarm ID"),
    alr_cnd  = PS("nmea_decoded.alr.cond",  "Alarm Condition"),
    alr_ack  = PS("nmea_decoded.alr.ack",   "Acknowledge State"),
    alr_txt  = PS("nmea_decoded.alr.text",  "Alarm Text"),
    -- AIS VDM/VDO (data: total,num,msgid,chan,payload,fill)
    ais_tot  = PS("nmea_decoded.ais.total",   "Total Sentences"),
    ais_num  = PS("nmea_decoded.ais.num",     "Sentence Number"),
    ais_mid  = PS("nmea_decoded.ais.msgid",   "Seq Message ID"),
    ais_ch   = PS("nmea_decoded.ais.chan",    "Radio Channel"),
    ais_pay  = PS("nmea_decoded.ais.payload", "Encoded Payload"),
    ais_fil  = PS("nmea_decoded.ais.fill",    "Fill Bits"),
}

p.fields = (function() local t={} for _,v in pairs(pf) do t[#t+1]=v end return t end)()

-- ─────────────────────────────────────────────────────────────────────────────
-- Decoders  (fs[1] = first CSV field, fs[2] = second, etc.)
-- ─────────────────────────────────────────────────────────────────────────────

local FIX = {["0"]="0-No Fix",["1"]="1-GPS",["2"]="2-DGPS",["3"]="3-PPS",
             ["4"]="4-RTK Fixed",["5"]="5-RTK Float",["6"]="6-DR",
             ["7"]="7-Manual",["8"]="8-Simulation"}

local dec = {}

-- GGA: utc,lat,NS,lon,EW,fix,sats,hdop,alt,M,sep,M,,
dec.GGA = function(t, fs)
    t:add(pf.gga_utc, hms(f(fs,1)))
    t:add(pf.gga_lat, latlon(f(fs,2), f(fs,3)))
    t:add(pf.gga_lon, latlon(f(fs,4), f(fs,5)))
    t:add(pf.gga_fix, FIX[f(fs,6)] or f(fs,6))
    t:add(pf.gga_sat, f(fs,7))
    t:add(pf.gga_hdp, f(fs,8))
    t:add(pf.gga_alt, f(fs,9).." "..f(fs,10))
    t:add(pf.gga_sep, f(fs,11).." "..f(fs,12))
end

-- RMC: utc,status,lat,NS,lon,EW,sog,cog,date,var,varEW
dec.RMC = function(t, fs)
    t:add(pf.rmc_utc, hms(f(fs,1)))
    t:add(pf.rmc_sta, av(f(fs,2)))
    t:add(pf.rmc_lat, latlon(f(fs,3), f(fs,4)))
    t:add(pf.rmc_lon, latlon(f(fs,5), f(fs,6)))
    t:add(pf.rmc_sog, f(fs,7).." kn")
    t:add(pf.rmc_cog, f(fs,8).."°")
    t:add(pf.rmc_dat, dmy(f(fs,9)))
    if f(fs,10) ~= "" then t:add(pf.rmc_var, f(fs,10).."° "..f(fs,11)) end
end

-- GLL: lat,NS,lon,EW,utc,status
dec.GLL = function(t, fs)
    t:add(pf.gll_lat, latlon(f(fs,1), f(fs,2)))
    t:add(pf.gll_lon, latlon(f(fs,3), f(fs,4)))
    t:add(pf.gll_utc, hms(f(fs,5)))
    t:add(pf.gll_sta, av(f(fs,6)))
end

-- VTG: cogt,T,cogm,M,sogn,N,sogk,K
dec.VTG = function(t, fs)
    t:add(pf.vtg_cogt, f(fs,1).."° True")
    t:add(pf.vtg_cogm, f(fs,3).."° Magnetic")
    t:add(pf.vtg_kn,   f(fs,5).." kn")
    t:add(pf.vtg_kmh,  f(fs,7).." km/h")
end

-- ZDA: utc,day,month,year,lzh,lzm
dec.ZDA = function(t, fs)
    t:add(pf.zda_utc, hms(f(fs,1)))
    t:add(pf.zda_day, f(fs,2))
    t:add(pf.zda_mon, f(fs,3))
    t:add(pf.zda_yr,  f(fs,4))
end

-- RMB: status,xte,dir,orig,dest,dlat,NS,dlon,EW,range,bearing,vel,arr
dec.RMB = function(t, fs)
    t:add(pf.rmb_sta, av(f(fs,1)))
    t:add(pf.rmb_xte, f(fs,2).." nm")
    local d = f(fs,3)
    t:add(pf.rmb_dir, d=="L" and "L – Steer Left" or d=="R" and "R – Steer Right" or d)
    t:add(pf.rmb_org, f(fs,4))
    t:add(pf.rmb_dst, f(fs,5))
    t:add(pf.rmb_lat, latlon(f(fs,6), f(fs,7)))
    t:add(pf.rmb_lon, latlon(f(fs,8), f(fs,9)))
    t:add(pf.rmb_rng, f(fs,10).." nm")
    t:add(pf.rmb_brg, f(fs,11).."°")
    t:add(pf.rmb_vel, f(fs,12).." kn")
    t:add(pf.rmb_arr, av(f(fs,13)))
end

-- APB: blink,cycle,xte,dir,units,arr,perp,bear_orig,T,dest,bear_dest,T,hdg,M
dec.APB = function(t, fs)
    t:add(pf.apb_sta, av(f(fs,1)))
    t:add(pf.apb_xte, f(fs,3).." "..f(fs,5))
    local d = f(fs,4)
    t:add(pf.apb_dir, d=="L" and "L – Steer Left" or d=="R" and "R – Steer Right" or d)
    t:add(pf.apb_arr, av(f(fs,6)))
    t:add(pf.apb_per, av(f(fs,7)))
    t:add(pf.apb_bor, f(fs,8).."°"..f(fs,9))
    t:add(pf.apb_wpt, f(fs,10))
    t:add(pf.apb_brd, f(fs,11).."°"..f(fs,12))
    t:add(pf.apb_hdg, f(fs,13).."°"..f(fs,14))
end

-- HDT: heading,T
dec.HDT = function(t, fs)
    t:add(pf.hdt_hdg, f(fs,1).."° True")
end

-- ROT: rate,status
dec.ROT = function(t, fs)
    local r = f(fs,1); local rn = tonumber(r) or 0
    t:add(pf.rot_rt,  r.."°/min")
    t:add(pf.rot_dir, rn>0 and "Starboard (right)" or rn<0 and "Port (left)" or "No turn")
    t:add(pf.rot_sta, av(f(fs,2)))
end

-- VHW: hdgt,T,hdgm,M,stwn,N,stwk,K
dec.VHW = function(t, fs)
    t:add(pf.vhw_hdgt, f(fs,1).."° True")
    t:add(pf.vhw_hdgm, f(fs,3).."° Magnetic")
    t:add(pf.vhw_kn,   f(fs,5).." kn")
    t:add(pf.vhw_kmh,  f(fs,7).." km/h")
end

-- VDR: degt,T,degm,M,speed,N
dec.VDR = function(t, fs)
    t:add(pf.vdr_sett, f(fs,1).."° True")
    t:add(pf.vdr_setm, f(fs,3).."° Magnetic")
    t:add(pf.vdr_drft, f(fs,5).." kn")
end

-- VLW: total,N,trip,N
dec.VLW = function(t, fs)
    t:add(pf.vlw_tot, f(fs,1).." nm")
    t:add(pf.vlw_trp, f(fs,3).." nm")
end

-- VBW: lsw,tsw,svw,lsg,tsg,ssg
dec.VBW = function(t, fs)
    t:add(pf.vbw_lsw, f(fs,1).." kn")
    t:add(pf.vbw_tsw, f(fs,2).." kn")
    t:add(pf.vbw_svw, av(f(fs,3)))
    t:add(pf.vbw_lsg, f(fs,4).." kn")
    t:add(pf.vbw_tsg, f(fs,5).." kn")
    t:add(pf.vbw_ssg, av(f(fs,6)))
end

-- MWV: angle,ref,speed,units,status
dec.MWV = function(t, fs)
    local ref = f(fs,2); local u = f(fs,4)
    t:add(pf.mwv_ang, f(fs,1).."°")
    t:add(pf.mwv_ref, ref=="R" and "Relative" or ref=="T" and "True" or ref)
    t:add(pf.mwv_spd, f(fs,3).." "..(SU[u] or u))
    t:add(pf.mwv_sta, av(f(fs,5)))
end

-- XDR: type,val,unit,id [repeating groups of 4]
dec.XDR = function(t, fs)
    local TT = {A="Angular",C="Temperature",D="Depth",F="Frequency",G="Generic",
                H="Humidity",N="Force",P="Pressure",R="RPM",S="Switch",
                T="Temperature",U="Voltage",V="Volume",Z="Salinity"}
    local i = 1
    while f(fs,i) ~= "" do
        local tp=f(fs,i); local vl=f(fs,i+1); local un=f(fs,i+2); local nm=f(fs,i+3)
        if tp=="" then break end
        t:add(pf.xdr_rdg, string.format("%s: value=%s%s  id=%s", TT[tp] or tp, vl, un, nm))
        i = i + 4
    end
end

-- DTM: ldatum,lsd,latoff,NS,lonoff,EW,altoff,rdatum
dec.DTM = function(t, fs)
    t:add(pf.dtm_loc, f(fs,1))
    t:add(pf.dtm_lat, f(fs,3).."' "..f(fs,4))
    t:add(pf.dtm_lon, f(fs,5).."' "..f(fs,6))
    t:add(pf.dtm_alt, f(fs,7).." m")
    t:add(pf.dtm_ref, f(fs,8))
end

-- ZTG: utc,ttg,wpt
dec.ZTG = function(t, fs)
    t:add(pf.ztg_utc, hms(f(fs,1)))
    t:add(pf.ztg_ttg, hms(f(fs,2)))
    t:add(pf.ztg_wpt, f(fs,3))
end

-- ALR: time,num,cond,ack,text
dec.ALR = function(t, fs)
    t:add(pf.alr_tim, hms(f(fs,1)))
    t:add(pf.alr_num, f(fs,2))
    local c = f(fs,3)
    t:add(pf.alr_cnd, c=="A" and "ALARM – Threshold Exceeded" or c=="V" and "Normal" or c)
    local a = f(fs,4)
    t:add(pf.alr_ack, a=="A" and "Acknowledged" or a=="V" and "Not Acknowledged" or a)
    local txt = (f(fs,5) or ""):gsub(",$",""):match("^%s*(.-)%s*$")
    t:add(pf.alr_txt, txt=="" and "(none)" or txt)
end

-- VDM/VDO: total,num,msgid,chan,payload,fill
local function dec_ais(t, fs)
    t:add(pf.ais_tot, f(fs,1).." sentence(s)")
    t:add(pf.ais_num, f(fs,2).." of "..f(fs,1))
    t:add(pf.ais_mid, f(fs,3)==""  and "(single)" or f(fs,3))
    local ch = f(fs,4)
    t:add(pf.ais_ch,  ch=="A" and "A – 161.975 MHz" or ch=="B" and "B – 162.025 MHz" or ch)
    t:add(pf.ais_pay, f(fs,5))
    t:add(pf.ais_fil, f(fs,6).." bit(s)")
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

    if not talker_fi or not sid_fi then return end

    local talker = tostring(talker_fi.value)
    local sid    = tostring(sid_fi.value):upper()
    local data   = data_fi and tostring(data_fi.value) or ""

    local subtree = root:add(p, tvb(),
        string.format("NMEA Decoded  ▸  %s%s", talker, sid))
    subtree:add(pf.sentence, talker..sid)

    local fs = csv(data)
    local decoder = dec[sid]
    if decoder then
        local ok, err = pcall(decoder, subtree, fs)
        if not ok then
            subtree:add_expert_info(PI_MALFORMED, PI_WARN,
                "Decode error ["..sid.."]: "..(err or "?"))
        end
    else
        subtree:add_expert_info(PI_UNDECODED, PI_NOTE,
            "No decoder for sentence type: "..sid)
    end
end

register_postdissector(p)

print("[nmea_fields.lua v7] Loaded  –  fs[1]=first field (no placeholder offset)")
print("  Decoded: GGA RMC GLL VTG ZDA RMB APB HDT ROT VHW VDR VLW VBW MWV XDR DTM ZTG ALR VDM/VDO")