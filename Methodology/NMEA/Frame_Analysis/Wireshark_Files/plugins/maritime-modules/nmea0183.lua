-- nmea_fields.lua  v8  (debug edition)
-- Put this in %APPDATA%\Roaming\Wireshark\plugins\nmea_fields.lua
-- After Ctrl+Shift+L, go to:  Tools → Lua Console  (or Help → Lua Console)
-- You should see debug print lines there telling you exactly what's happening.

print("========================================")
print("[nmea_fields] FILE LOADED - v8 debug")
print("========================================")

-- Step 1: can we see the fkie-cad fields at all?
local ok1, fi_talker  = pcall(Field.new, "nmea-0183.talkerid")
local ok2, fi_sid     = pcall(Field.new, "nmea-0183.sentenceid")
local ok3, fi_data    = pcall(Field.new, "nmea-0183.data")

print("[nmea_fields] Field.new nmea-0183.talkerid  : " .. tostring(ok1) .. " / " .. tostring(fi_talker))
print("[nmea_fields] Field.new nmea-0183.sentenceid: " .. tostring(ok2) .. " / " .. tostring(fi_sid))
print("[nmea_fields] Field.new nmea-0183.data      : " .. tostring(ok3) .. " / " .. tostring(fi_data))

local p = Proto("nmea_decoded", "NMEA 0183 Decoded Fields")
local PS = ProtoField.string
local pf = {
    sentence = PS("nmea_decoded.sentence", "Sentence"),
    dbg      = PS("nmea_decoded.debug",    "Debug"),
    -- HDT
    hdt_hdg  = PS("nmea_decoded.hdt.heading", "Heading (° True)"),
    -- VTG
    vtg_cogt = PS("nmea_decoded.vtg.cogt", "Course Over Ground (True)"),
    vtg_cogm = PS("nmea_decoded.vtg.cogm", "Course Over Ground (Magnetic)"),
    vtg_kn   = PS("nmea_decoded.vtg.kn",   "Speed Over Ground (kn)"),
    vtg_kmh  = PS("nmea_decoded.vtg.kmh",  "Speed Over Ground (km/h)"),
    -- GGA
    gga_utc  = PS("nmea_decoded.gga.utc",  "UTC Time"),
    gga_lat  = PS("nmea_decoded.gga.lat",  "Latitude"),
    gga_lon  = PS("nmea_decoded.gga.lon",  "Longitude"),
    gga_fix  = PS("nmea_decoded.gga.fix",  "Fix Quality"),
    gga_sat  = PS("nmea_decoded.gga.sat",  "Satellites in Use"),
    gga_hdp  = PS("nmea_decoded.gga.hdop", "HDOP"),
    gga_alt  = PS("nmea_decoded.gga.alt",  "Altitude (MSL)"),
    -- RMC
    rmc_utc  = PS("nmea_decoded.rmc.utc",  "UTC Time"),
    rmc_sta  = PS("nmea_decoded.rmc.stat", "Status"),
    rmc_lat  = PS("nmea_decoded.rmc.lat",  "Latitude"),
    rmc_lon  = PS("nmea_decoded.rmc.lon",  "Longitude"),
    rmc_sog  = PS("nmea_decoded.rmc.sog",  "Speed Over Ground (kn)"),
    rmc_cog  = PS("nmea_decoded.rmc.cog",  "Course Over Ground (°T)"),
    rmc_dat  = PS("nmea_decoded.rmc.date", "Date"),
    -- GLL
    gll_lat  = PS("nmea_decoded.gll.lat",  "Latitude"),
    gll_lon  = PS("nmea_decoded.gll.lon",  "Longitude"),
    gll_utc  = PS("nmea_decoded.gll.utc",  "UTC Time"),
    gll_sta  = PS("nmea_decoded.gll.stat", "Status"),
    -- RMB
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
    -- ROT
    rot_rt   = PS("nmea_decoded.rot.rate",   "Rate of Turn (°/min)"),
    rot_dir  = PS("nmea_decoded.rot.dir",    "Turn Direction"),
    rot_sta  = PS("nmea_decoded.rot.status", "Status"),
    -- ALR
    alr_tim  = PS("nmea_decoded.alr.time",  "Alarm Time"),
    alr_num  = PS("nmea_decoded.alr.num",   "Alarm ID"),
    alr_cnd  = PS("nmea_decoded.alr.cond",  "Alarm Condition"),
    alr_ack  = PS("nmea_decoded.alr.ack",   "Acknowledge State"),
    alr_txt  = PS("nmea_decoded.alr.text",  "Alarm Text"),
    -- MWV
    mwv_ang  = PS("nmea_decoded.mwv.angle", "Wind Angle (°)"),
    mwv_ref  = PS("nmea_decoded.mwv.ref",   "Reference"),
    mwv_spd  = PS("nmea_decoded.mwv.speed", "Wind Speed"),
    mwv_sta  = PS("nmea_decoded.mwv.stat",  "Status"),
    -- ZDA
    zda_utc  = PS("nmea_decoded.zda.utc",  "UTC Time"),
    zda_day  = PS("nmea_decoded.zda.day",  "Day"),
    zda_mon  = PS("nmea_decoded.zda.mon",  "Month"),
    zda_yr   = PS("nmea_decoded.zda.year", "Year"),
    -- VHW
    vhw_hdgt = PS("nmea_decoded.vhw.hdgt",  "Heading True (°)"),
    vhw_hdgm = PS("nmea_decoded.vhw.hdgm",  "Heading Magnetic (°)"),
    vhw_kn   = PS("nmea_decoded.vhw.kn",    "Speed Through Water (kn)"),
    vhw_kmh  = PS("nmea_decoded.vhw.kmh",   "Speed Through Water (km/h)"),
    -- VLW
    vlw_tot  = PS("nmea_decoded.vlw.total", "Total Cumulative Distance (nm)"),
    vlw_trp  = PS("nmea_decoded.vlw.trip",  "Trip Distance (nm)"),
    -- VBW
    vbw_lsw  = PS("nmea_decoded.vbw.lsw",  "Long. Water Speed (kn)"),
    vbw_tsw  = PS("nmea_decoded.vbw.tsw",  "Trans. Water Speed (kn)"),
    vbw_svw  = PS("nmea_decoded.vbw.svw",  "Water Speed Status"),
    vbw_lsg  = PS("nmea_decoded.vbw.lsg",  "Long. Ground Speed (kn)"),
    vbw_tsg  = PS("nmea_decoded.vbw.tsg",  "Trans. Ground Speed (kn)"),
    vbw_ssg  = PS("nmea_decoded.vbw.ssg",  "Ground Speed Status"),
    -- APB
    apb_sta  = PS("nmea_decoded.apb.stat", "Status"),
    apb_xte  = PS("nmea_decoded.apb.xte",  "Cross-Track Error (nm)"),
    apb_dir  = PS("nmea_decoded.apb.dir",  "Steer Direction"),
    apb_arr  = PS("nmea_decoded.apb.arr",  "Arrival Circle"),
    apb_per  = PS("nmea_decoded.apb.perp", "Passed Perpendicular"),
    apb_wpt  = PS("nmea_decoded.apb.wpt",  "Destination Waypoint"),
    apb_brd  = PS("nmea_decoded.apb.brd",  "Bearing to Dest (°T)"),
    apb_hdg  = PS("nmea_decoded.apb.hdg",  "Heading to Steer (°M)"),
    -- VDR
    vdr_sett = PS("nmea_decoded.vdr.sett",  "Current Set Direction (°T)"),
    vdr_setm = PS("nmea_decoded.vdr.setm",  "Current Set Direction (°M)"),
    vdr_drft = PS("nmea_decoded.vdr.drift", "Current Drift Speed (kn)"),
    -- XDR
    xdr_rdg  = PS("nmea_decoded.xdr.rdg",  "Transducer Reading"),
    -- DTM
    dtm_loc  = PS("nmea_decoded.dtm.local",  "Local Datum"),
    dtm_lat  = PS("nmea_decoded.dtm.lat",    "Lat Offset"),
    dtm_lon  = PS("nmea_decoded.dtm.lon",    "Lon Offset"),
    dtm_alt  = PS("nmea_decoded.dtm.alt",    "Alt Offset (m)"),
    dtm_ref  = PS("nmea_decoded.dtm.ref",    "Reference Datum"),
    -- ZTG
    ztg_utc  = PS("nmea_decoded.ztg.utc",   "UTC Time"),
    ztg_ttg  = PS("nmea_decoded.ztg.ttg",   "Time-to-Go"),
    ztg_wpt  = PS("nmea_decoded.ztg.wpt",   "Destination Waypoint"),
    -- AIS
    ais_tot  = PS("nmea_decoded.ais.total",   "Total Sentences"),
    ais_num  = PS("nmea_decoded.ais.num",     "Sentence Number"),
    ais_mid  = PS("nmea_decoded.ais.msgid",   "Seq Message ID"),
    ais_ch   = PS("nmea_decoded.ais.chan",    "Radio Channel"),
    ais_pay  = PS("nmea_decoded.ais.payload", "Encoded Payload"),
    ais_fil  = PS("nmea_decoded.ais.fill",    "Fill Bits"),
}
p.fields = (function() local t={} for _,v in pairs(pf) do t[#t+1]=v end return t end)()

-- Helpers
local function csv(s)
    local t={}
    for part in (s..","):gmatch("([^,]*),") do t[#t+1]=part:gsub("[\r\n]+$","") end
    return t
end
local function f(fs,n) return fs[n] or "" end
local function latlon(dm,hemi)
    if dm=="" then return "(empty)" end
    local d=(hemi=="N" or hemi=="S") and 2 or 3
    return dm:sub(1,d).."° "..dm:sub(d+1).."' "..hemi
end
local function hms(t)
    if #t<6 then return t end
    return t:sub(1,2)..":"..t:sub(3,4)..":"..t:sub(5).." UTC"
end
local function dmy(d)
    if #d<6 then return d end
    return d:sub(1,2).."/"..d:sub(3,4).."/"..d:sub(5,6)
end
local function av(v)
    return v=="A" and "Active/Valid" or v=="V" and "Void/Invalid" or (v=="" and "(empty)" or v)
end
local SU={K="km/h",M="m/s",N="knots",S="mph"}
local FIX={["0"]="No Fix",["1"]="GPS",["2"]="DGPS",["3"]="PPS",
           ["4"]="RTK Fixed",["5"]="RTK Float",["6"]="DR",["7"]="Manual",["8"]="Simulation"}

-- Decoders (fs[1]=first field, fkie strips sentence header and checksum from data)
local dec={}
dec.HDT=function(t,fs) t:add(pf.hdt_hdg, f(fs,1).."° True") end
dec.VTG=function(t,fs)
    t:add(pf.vtg_cogt,f(fs,1).."° True")
    t:add(pf.vtg_cogm,f(fs,3).."° Magnetic")
    t:add(pf.vtg_kn,  f(fs,5).." kn")
    t:add(pf.vtg_kmh, f(fs,7).." km/h")
end
dec.GGA=function(t,fs)
    t:add(pf.gga_utc,hms(f(fs,1)))
    t:add(pf.gga_lat,latlon(f(fs,2),f(fs,3)))
    t:add(pf.gga_lon,latlon(f(fs,4),f(fs,5)))
    t:add(pf.gga_fix,FIX[f(fs,6)] or f(fs,6))
    t:add(pf.gga_sat,f(fs,7))
    t:add(pf.gga_hdp,f(fs,8))
    t:add(pf.gga_alt,f(fs,9).." "..f(fs,10))
end
dec.RMC=function(t,fs)
    t:add(pf.rmc_utc,hms(f(fs,1)))
    t:add(pf.rmc_sta,av(f(fs,2)))
    t:add(pf.rmc_lat,latlon(f(fs,3),f(fs,4)))
    t:add(pf.rmc_lon,latlon(f(fs,5),f(fs,6)))
    t:add(pf.rmc_sog,f(fs,7).." kn")
    t:add(pf.rmc_cog,f(fs,8).."°")
    t:add(pf.rmc_dat,dmy(f(fs,9)))
end
dec.GLL=function(t,fs)
    t:add(pf.gll_lat,latlon(f(fs,1),f(fs,2)))
    t:add(pf.gll_lon,latlon(f(fs,3),f(fs,4)))
    t:add(pf.gll_utc,hms(f(fs,5)))
    t:add(pf.gll_sta,av(f(fs,6)))
end
dec.RMB=function(t,fs)
    t:add(pf.rmb_sta,av(f(fs,1)))
    t:add(pf.rmb_xte,f(fs,2).." nm")
    local d=f(fs,3); t:add(pf.rmb_dir,d=="L" and "Steer Left" or d=="R" and "Steer Right" or d)
    t:add(pf.rmb_org,f(fs,4))
    t:add(pf.rmb_dst,f(fs,5))
    t:add(pf.rmb_lat,latlon(f(fs,6),f(fs,7)))
    t:add(pf.rmb_lon,latlon(f(fs,8),f(fs,9)))
    t:add(pf.rmb_rng,f(fs,10).." nm")
    t:add(pf.rmb_brg,f(fs,11).."°")
    t:add(pf.rmb_vel,f(fs,12).." kn")
    t:add(pf.rmb_arr,av(f(fs,13)))
end
dec.APB=function(t,fs)
    t:add(pf.apb_sta,av(f(fs,1)))
    t:add(pf.apb_xte,f(fs,3).." "..f(fs,5))
    local d=f(fs,4); t:add(pf.apb_dir,d=="L" and "Steer Left" or d=="R" and "Steer Right" or d)
    t:add(pf.apb_arr,av(f(fs,6)))
    t:add(pf.apb_per,av(f(fs,7)))
    t:add(pf.apb_wpt,f(fs,10))
    t:add(pf.apb_brd,f(fs,11).."°"..f(fs,12))
    t:add(pf.apb_hdg,f(fs,13).."°"..f(fs,14))
end
dec.ROT=function(t,fs)
    local r=f(fs,1); local rn=tonumber(r) or 0
    t:add(pf.rot_rt, r.."°/min")
    t:add(pf.rot_dir,rn>0 and "Starboard" or rn<0 and "Port" or "No turn")
    t:add(pf.rot_sta,av(f(fs,2)))
end
dec.VHW=function(t,fs)
    t:add(pf.vhw_hdgt,f(fs,1).."° True")
    t:add(pf.vhw_hdgm,f(fs,3).."° Magnetic")
    t:add(pf.vhw_kn,  f(fs,5).." kn")
    t:add(pf.vhw_kmh, f(fs,7).." km/h")
end
dec.VDR=function(t,fs)
    t:add(pf.vdr_sett,f(fs,1).."° True")
    t:add(pf.vdr_setm,f(fs,3).."° Magnetic")
    t:add(pf.vdr_drft,f(fs,5).." kn")
end
dec.VLW=function(t,fs)
    t:add(pf.vlw_tot,f(fs,1).." nm")
    t:add(pf.vlw_trp,f(fs,3).." nm")
end
dec.VBW=function(t,fs)
    t:add(pf.vbw_lsw,f(fs,1).." kn")
    t:add(pf.vbw_tsw,f(fs,2).." kn")
    t:add(pf.vbw_svw,av(f(fs,3)))
    t:add(pf.vbw_lsg,f(fs,4).." kn")
    t:add(pf.vbw_tsg,f(fs,5).." kn")
    t:add(pf.vbw_ssg,av(f(fs,6)))
end
dec.MWV=function(t,fs)
    local ref=f(fs,2); local u=f(fs,4)
    t:add(pf.mwv_ang,f(fs,1).."°")
    t:add(pf.mwv_ref,ref=="R" and "Relative" or ref=="T" and "True" or ref)
    t:add(pf.mwv_spd,f(fs,3).." "..(SU[u] or u))
    t:add(pf.mwv_sta,av(f(fs,5)))
end
dec.XDR=function(t,fs)
    local TT={A="Angular",C="Temperature",D="Depth",F="Frequency",G="Generic",
              H="Humidity",N="Force",P="Pressure",R="RPM",S="Switch",
              T="Temperature",U="Voltage",V="Volume",Z="Salinity"}
    local i=1
    while f(fs,i)~="" do
        t:add(pf.xdr_rdg,string.format("%s: %s%s  id=%s",TT[f(fs,i)] or f(fs,i),f(fs,i+1),f(fs,i+2),f(fs,i+3)))
        i=i+4
    end
end
dec.ZDA=function(t,fs)
    t:add(pf.zda_utc,hms(f(fs,1)))
    t:add(pf.zda_day,f(fs,2))
    t:add(pf.zda_mon,f(fs,3))
    t:add(pf.zda_yr, f(fs,4))
end
dec.DTM=function(t,fs)
    t:add(pf.dtm_loc,f(fs,1))
    t:add(pf.dtm_lat,f(fs,3).."' "..f(fs,4))
    t:add(pf.dtm_lon,f(fs,5).."' "..f(fs,6))
    t:add(pf.dtm_alt,f(fs,7).." m")
    t:add(pf.dtm_ref,f(fs,8))
end
dec.ZTG=function(t,fs)
    t:add(pf.ztg_utc,hms(f(fs,1)))
    t:add(pf.ztg_ttg,hms(f(fs,2)))
    t:add(pf.ztg_wpt,f(fs,3))
end
dec.ALR=function(t,fs)
    t:add(pf.alr_tim,hms(f(fs,1)))
    t:add(pf.alr_num,f(fs,2))
    local c=f(fs,3); t:add(pf.alr_cnd,c=="A" and "ALARM – Threshold Exceeded" or c=="V" and "Normal" or c)
    local a=f(fs,4); t:add(pf.alr_ack,a=="A" and "Acknowledged" or a=="V" and "Not Acknowledged" or a)
    local txt=(f(fs,5) or ""):gsub(",$",""):match("^%s*(.-)%s*$")
    t:add(pf.alr_txt,txt=="" and "(none)" or txt)
end
local function dec_ais(t,fs)
    t:add(pf.ais_tot,f(fs,1).." sentence(s)")
    t:add(pf.ais_num,f(fs,2).." of "..f(fs,1))
    t:add(pf.ais_mid,f(fs,3)==""  and "(single)" or f(fs,3))
    local ch=f(fs,4); t:add(pf.ais_ch,ch=="A" and "A – 161.975 MHz" or ch=="B" and "B – 162.025 MHz" or ch)
    t:add(pf.ais_pay,f(fs,5))
    t:add(pf.ais_fil,f(fs,6).." bit(s)")
end
dec.VDM=dec_ais; dec.VDO=dec_ais

-- Track call count for debug
local call_count = 0
local nmea_count = 0

function p.dissector(tvb, pinfo, root)
    call_count = call_count + 1

    local talker_fi = fi_talker()
    local sid_fi    = fi_sid()
    local data_fi   = fi_data()

    -- Log every 10th call and whenever we see NMEA fields
    if talker_fi or sid_fi then
        nmea_count = nmea_count + 1
        local talker = talker_fi and tostring(talker_fi.value) or "NIL"
        local sid    = sid_fi    and tostring(sid_fi.value)    or "NIL"
        local data   = data_fi   and tostring(data_fi.value)   or "NIL"
        print(string.format("[nmea_fields] #%d NMEA pkt: talker=%s sid=%s data=%s",
            nmea_count, talker, sid, data:sub(1,40)))

        local subtree = root:add(p, tvb(),
            string.format("NMEA Decoded  ▸  %s%s", talker, sid:upper()))
        subtree:add(pf.sentence, talker..sid:upper())
        subtree:add(pf.dbg, string.format("raw data[%d]: %s", #data, data))

        local fs = csv(data)
        local decoder = dec[sid:upper()]
        if decoder then
            local ok, err = pcall(decoder, subtree, fs)
            if not ok then
                subtree:add(pf.dbg, "ERROR: "..(err or "?"))
                print("[nmea_fields] DECODE ERROR ["..sid.."]: "..(err or "?"))
            end
        else
            subtree:add(pf.dbg, "No decoder for: "..sid)
        end
    elseif call_count % 50 == 0 then
        print(string.format("[nmea_fields] post-dissector alive, call#%d, nmea_seen=%d, talker=nil",
            call_count, nmea_count))
    end
end

register_postdissector(p)

print("[nmea_fields] register_postdissector called - watching for nmea-0183.talkerid")
print("[nmea_fields] Open Tools > Lua Console to see live debug output")