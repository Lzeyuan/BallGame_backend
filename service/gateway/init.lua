local skynet = require "skynet"
local socketdriver = require "skynet.socketdriver"
local gateserver = require "snax.gateserver"
local cjson = require "cjson"
local runconfig = require "runconfig"

local conns = {}
local players = {}

--创建连接对象
local conn = function()
    return {
        fd = nil,
        address = nil,
        player_id = nil
    }
end

--创建万玩家对象
local gateplayer = function()
    return {
        player_id = nil,
        agent = nil,
        conn = nil
    }
end

local CMD = {}

local function json_pack(cmd, msg)
    msg._cmd = cmd
    local body = cjson.encode(msg)    --协议体字节流
	local namelen = string.len(cmd)   --协议名长度
    local bodylen = string.len(body)  --协议体长度
	local len = namelen + bodylen + 2 --协议总长度
	local format = string.format("> i2 i2 c%d c%d", namelen, bodylen)
	local buff = string.pack(format, len, namelen, cmd, body)
    return buff
end

CMD.send_by_fd = function(source, fd, msg)
    if conns[fd] == nil then
        return
    end

    local buffer = json_pack(msg[1], {
        ErrorCode = msg[2],
        Message = msg[3]
    })
    skynet.error(string.format("send %d [%s] {%s}", fd, msg[1], buffer))
    socketdriver.send(fd, buffer)
end

CMD.send = function(source, player_id, msg)
    local gplayer = players[player_id]
    if gplayer == nil then
        return
    end

    local c = gplayer.conn
    if c == gplayer then
        return
    end
    CMD.send_by_fd(source, c.fd, msg)
end

--[[
处理agentmger返回结果
return:
    1.未完成登录即下线
    2.创建角色
--]]
CMD.sure_agent = function(source, fd, player_id, agent)
    local conn = conns[fd]
    if conn == nil then
        local reason = "未完成登录即下线"
        skynet.call("agentmgr", "lua", "repick", player_id, reason)
        return false
    end

    conn.player_id = player_id

    local gplayer = gateplayer()
    gplayer.player_id = player_id
    gplayer.agent = agent
    gplayer.conn = conn
    players[player_id] = gplayer

    return true
end

CMD.kick = function(source, player_id)
    local gplayer = players[player_id]
    if gplayer == nil then
        return
    end

    players[player_id] = nil

    local c = gplayer.conn
    if c == nil then
        return
    end

    conns[c.fd] = nil
    -- 多余https://github.com/luopeiyu/million_game_server/issues/18
    -- disconnect(c.fd)
    socketdriver.close(c.fd)
end

local handler = {}

function handler.command(cmd, source, ...)
    skynet.error(cmd)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

function handler.open(source, conf)
	return conf.address, conf.port
end

function handler.connect(fd, address)
    print(string.format("connect from %s %d", address, fd))
    local c = conn()
    conns[fd] = c
    c.fd = fd
    c.address = address
end

local function json_unpack(buffer)
    local len = string.len(buffer)
    local namelen_format = string.format("> i2 c%d", len - 2)
    local namelen, other = string.unpack(namelen_format, buffer)
    local bodylen = len - 2 - namelen
    local format = string.format("> c%d c%d", namelen, bodylen)
---@diagnostic disable-next-line: param-type-mismatch
    local cmd, bodybuff = string.unpack(format, other)

    local isok, msg = pcall(cjson.decode, bodybuff)
    if not isok or cmd then
        print("json_unpack error")
        return
    end

    return cmd, msg
end

function handler.message(fd, message_buffer, size)
    local cmd, message_json = json_unpack(message_buffer);
    skynet.error(string.format("recv %d [%s] {%s}", fd, cmd, message_json))
    local isok, message = pcall(cjson.decode, message_json)

    if not isok then
        return
    end

    local conn = conns[fd]
    local player_id = conn.player_id
    if not player_id then
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        --todo:login节点负载均衡
        local login_id = math.random(1, #nodecfg.login)
        local login = "login" .. login_id
        skynet.send(login, "lua", "client", fd, cmd, message)
    else
        local gplayer = players[player_id]
        local agent = gplayer.agent
        skynet.send(agent, "lua", "client", cmd, message)
    end
end

local function close_fd(fd)
    local c = conns[fd]
    if c == nil then
        return
    end

    local player_id = c.player_id
    if player_id == nil then
        return
    else
        players[player_id] = nil
        local reason = "断线"
        skynet.call("agentmgr", "lua", "repick", player_id, reason)
    end
end

function handler.disconnect(fd)
    local c = conns[fd]
    skynet.error("close " .. c.address .." fd:" .. fd)
    close_fd(fd)
end

function handler.error(fd, error)
    skynet.error("[gateway] error " .. error)
    close_fd(fd)
end

gateserver.start(handler)
