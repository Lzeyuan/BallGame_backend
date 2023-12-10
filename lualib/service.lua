local skynet = require "skynet"
local cluster = require "skynet.cluster"

local M = {
    name = "",
    id   = 0,
    exit = nil,
    init = nil,
    resp = {},
}

local function traceback(error)
    skynet.error(error)
    skynet.error(debug.traceback())
end

local dispatch = function(session, adderss, cmd, ...)
    local fun = M.resp[cmd]
    if not fun then
        skynet.ret()
        return
    end

    local ret = table.pack(xpcall(fun, traceback, adderss, ...))
    local isok = ret[1]

    if not isok then
        skynet.ret()
        return
    end

    skynet.retpack(table.unpack(ret, 2))
end

local init = function()
    skynet.dispatch("lua", dispatch)
    if M.init then
        M.init()
    end
end

function M.start(name, id, ...)
    M.name = name
    M.id = tonumber(id)
    skynet.start(init)
end

--阻塞发送
function M.call(node, target_service_address, ...)
    local mynode = skynet.getenv("node")
    if node == mynode then
        return skynet.call(target_service_address, "lua", ...)
    else
        return cluster.call(node, target_service_address, ...)
    end
end

--非阻塞发送
function M.send(node, target_service_address, ...)
    local mynode = skynet.getenv("node")
    if node == mynode then
        return skynet.send(target_service_address, "lua", ...)
    else
        return cluster.send(node, target_service_address, ...)
    end
end

return M
