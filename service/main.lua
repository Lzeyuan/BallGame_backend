local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"
local cjson = require "cjson"

local test1 = function()
    local msg = {
        _cmd = "ball_list",
        balls = {
            [1] = { id = 102, x = 10, y = 20, size = 1 },
            [2] = { id = 103, x = 20, y = 30, size = 2 }
        }
    }
    local buffer = cjson.encode(msg)
    print(buffer)

    buffer = [[{"_cmd":"enter","playerid":10086}]]
    local isok, msg = pcall(cjson.decode, buffer)
    if isok then
        print(msg._cmd)
        print(msg.playerid)
    else
        print("error")
    end
end

skynet.start(function()
    test1()
    --初始化
    local mynode = skynet.getenv("node")
    local nodecfg = runconfig[mynode]
    --节点管理
    local nodemgr = skynet.newservice("nodemgr", "nodemgr", 0)
    skynet.name("nodemgr", nodemgr)
    --集群
    cluster.reload(runconfig.cluster)
    cluster.open(mynode)
    --gate
    for i, v in pairs(nodecfg.gateway or {}) do
        local srv = skynet.newservice("gateway", "gateway", i)
        skynet.name("gateway" .. i, srv)
    end
    --login
    for i, v in pairs(nodecfg.login or {}) do
        local srv = skynet.newservice("login", "login", i)
        skynet.name("login" .. i, srv)
    end
    --agentmgr
    local anode = runconfig.agentmgr.node
    if mynode == anode then
        local srv = skynet.newservice("agentmgr", "agentmgr", 0)
        skynet.name("agentmgr", srv)
    else
        local proxy = cluster.proxy(anode, "agentmgr")
        skynet.name("agentmgr", proxy)
    end
    -- --scene (sid->sceneid)
    -- for _, sid in pairs(runconfig.scene[mynode] or {}) do
    --     local srv = skynet.newservice("scene", "scene", sid)
    --     skynet.name("scene" .. sid, srv)
    -- end
    --退出自身



    skynet.exit()
end)
