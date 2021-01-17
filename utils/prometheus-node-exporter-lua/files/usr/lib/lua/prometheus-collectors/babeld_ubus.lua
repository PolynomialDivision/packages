local ubus = require "ubus"

local function scrape()
  local metric_babeld_ubus_route_metric = 
    metric("babeld_ubus_route_metric", "gauge")
  local metric_babeld_ubus_route_smoothed_metric = 
    metric("babeld_ubus_route_smoothed_metric", "gauge")
  local metric_babeld_ubus_route_refmetric = 
    metric("babeld_ubus_route_refmetric", "gauge")
  local metric_babeld_ubus_route_refmetric = 
    metric("babeld_ubus_route_refmetric", "gauge")
  local metric_babeld_ubus_route_age =
    metric("babeld_ubus_route_age", "gauge")
  local metric_babeld_ubus_route_installed = 
    metric("babeld_ubus_route_installed", "gauge")
  local metric_babeld_ubus_route_feasible = 
    metric("babeld_ubus_route_feasible", "gauge")

  local function evaluate_route_metrics(ipversion, dstprefix, vals)
    local label_route = {
      version = "route",
      ipversion = ipversion,
      dstprefix = dstprefix,
      src_prefix = vals['src-prefix'],
      id = vals['id'],
      via = vals['via'],
      nexthop = vals['nexthop'],
      seqno = vals['seqno'],
      channels = vals['channels']
    }

    metric_babeld_ubus_route_metric(label_route, vals['route_metric'])
    metric_babeld_ubus_route_smoothed_metric(label_route, vals['route_smoothed_metric'])
    metric_babeld_ubus_route_refmetric(label_route, vals['refmetric'])
    metric_babeld_ubus_route_age(label_route, vals['age'])
    metric_babeld_ubus_route_installed(label_route,(vals['installed'] == true) and 1 or 0)
    metric_babeld_ubus_route_feasible(label_route, (vals['feasible'] == true) and 1 or 0)
  end

  local u = ubus.connect()
  local routes = u:call("babeld", "get_routes", {})

  for ipversion, ipversion_table in pairs(routes) do
    for dstprefix, dstprefix_table in pairs(ipversion_table) do
      evaluate_route_metrics(ipversion, dstprefix, dstprefix_table)
    end
  end
end

return { scrape = scrape }
