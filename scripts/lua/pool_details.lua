--
-- (C) 2017 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    require "snmp_utils"
    shaper_utils = require "shaper_utils"
end

require "lua_utils"
require "graph_utils"
require "alert_utils"
local host_pools_utils = require "host_pools_utils"

local pool_id     = _GET["pool"]
local page        = _GET["page"]

if (not ntop.isPro()) then
  return
end

interface.select(ifname)
local ifstats = interface.getStats()
local ifId = ifstats.id
local pool_name = host_pools_utils.getPoolName(ifId, pool_id)

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local base_url = ntop.getHttpPrefix()..'/lua/pool_details.lua'
local page_params = {}

page_params["ifid"] = ifId
page_params["pool"] = pool_id
page_params["page"] = page

if(pool_id == nil) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("pool_details.pool_parameter_missing_message").."</div>")
    return
end

print [[
<div class="bs-docs-example">
  <nav class="navbar navbar-default" role="navigation">
    <div class="navbar-collapse collapse">
      <ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">"..i18n("pool_details.host_pool")..": "..pool_name.."</A> </li>")

local go_page_params = table.clone(page_params)

if page == "historical" then
  print("<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i>\n")
else
  go_page_params["page"] = "historical"
  print("<li><a href=\""..getPageUrl(base_url, go_page_params).."\"><i class='fa fa-area-chart fa-lg'></i>\n")
end

if ntop.isEnterprise() and ifstats.inline and pool_id ~= host_pools_utils.DEFAULT_POOL_ID then
  if page == "quotas" then
    print("<li class=\"active\"><a href=\"#\">"..i18n("quotas").."</i>\n")
  else
    go_page_params["page"] = "quotas"
    print("<li><a href=\""..getPageUrl(base_url, go_page_params).."\">"..i18n("quotas").."\n")
  end
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
      </ul>
    </div>
  </nav>
</div>
]]

local pools_stats = interface.getHostPoolsStats()
local pool_stats = pools_stats and pools_stats[tonumber(pool_id)]

if ntop.isEnterprise() and pool_id ~= host_pools_utils.DEFAULT_POOL_ID and ifstats.inline and (page == "quotas") and (pool_stats ~= nil) then
  host_pools_utils.printQuotas(pool_id, nil, page_params)
elseif page == "historical" then
  local rrdbase = host_pools_utils.getRRDBase(ifId, pool_id)

  if(not ntop.exists(rrdbase.."/bytes.rrd")) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("pool_details.no_available_data_for_host_pool_message",{pool_name=pool_name}))
    print(" "..i18n("pool_details.host_pool_timeseries_enable_message",{url=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=on_disk_ts",icon_flask="<i class=\"fa fa-flask\"></i>"})..'</div>')
  else
    local rrdfile
    if(not isEmptyString(_GET["rrd_file"])) then
      rrdfile = _GET["rrd_file"]
    else
      rrdfile = "bytes.rrd"
    end

    local host_url = getPageUrl(base_url, page_params)
    drawRRD(ifId, 'pool:'..pool_id, rrdfile, _GET["zoom"], host_url, 1, _GET["epoch"])
  end
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
