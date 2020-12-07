local function scrape()
    for e in io.lines("/proc/net/snmp6") do
        local snmp6 = space_split(e)
        metric("snmpv6_" .. snmp6[1], "gauge", nil, tonumber(snmp6[2]))
    end
end

return { scrape = scrape }
