local skynet = require "skynet"
local socket = require "skynet.socket"
local s = require "service"
local runconfig = require "runconfig"
local cjson = require "cjson"

local conns = {}

local players = {}

--创建连接对象
local conn = function()
    return {
        fd = nil,
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

--start辅助函数
local str_unpack = function(msg_str)
    local msg = {}
    while true do
        local arg, rest = string.match(msg_str, "(.-),(.*)")
        if arg then
            msg_str = rest
            table.insert(msg, arg)
        else
            table.insert(msg, msg_str)
            break
        end
    end
    return msg[1], msg
end

local str_pack = function(cmd, msg)
    return table.concat(msg, ",") .. "\r\n"
end
--end辅助函数

--获取信息内容(,)
local process_msg = function(fd, msg_str)
    skynet.error("raw msg：" .. msg_str)

    local cmd, msg = str_unpack(msg_str)
    skynet.error(string.format("recv %d [cmd] {%s}", fd, table.concat(msg, ",")))

    local conn = conns[fd]
    local player_id = conn.player_id
    if not player_id then
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local login_id = math.random(1, #nodecfg.login)
        local login = "login" .. login_id

        skynet.send(login, "lua", "client", fd, cmd, msg)
    else
        local gplayer = players[player_id]
        local agent = gplayer.agent
        skynet.send(agent, "lua", "client", cmd, msg)
    end
end

--截取一条条信息(\r\n)
local process_buffer = function(fd, read_buffer)
    while true do
        local msg_str, rest = string.match(read_buffer, "(.-)\r\n(.*)")
        if msg_str then
            read_buffer = rest
            process_msg(fd, msg_str)
        else
            return read_buffer
        end
    end
end

local disconnect = function(fd)
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

--监听并消息
local recv_loop = function(fd)
    socket.start(fd)
    skynet.error(string.format("socket connected %d", fd))

    local read_buffer = ""
    while true do
        local recvstr = socket.read(fd)
        skynet.error("receive" .. recvstr);

        if recvstr then
            read_buffer = read_buffer .. recvstr
            read_buffer = process_buffer(fd, read_buffer)
        else
            skynet.error(string.format("socket close %d", fd))
            disconnect(fd)
            socket.close(fd)
            return
        end
    end
end

--每当有新连接
local connect = function(fd, address)
    -- print("connect from " .. address .. " " .. fd)
    print(string.format("connect from %s %d", address, fd))
    local c = conn()
    conns[fd] = c
    c.fd = fd
    skynet.fork(recv_loop, fd)
end

function s.init()
    local node = skynet.getenv("node")
    local nodecfg = runconfig[node]
    local port = nodecfg.gateway[s.id].port

    local listenfd = socket.listen("0.0.0.0", port)
    skynet.error("Listen socket:", "0.0.0.0", port)
    socket.start(listenfd, connect)
end

s.resp.send_by_fd = function(source, fd, msg)
    if conns[fd] == nil then
        return
    end

    local buffer = str_pack(msg[1], msg)
    skynet.error(string.format("send %d [%s] {%s}", fd, msg[1], table.concat(msg, ",")))
    socket.write(fd, buffer)
end

s.resp.send = function(source, player_id, msg)
    local gplayer = players[player_id]
    if gplayer == nil then
        return
    end

    local c = gplayer.conn
    if c == gplayer then
        return
    end
    s.resp.send_by_fd(source, c.fd, msg)
end

--[[
处理agentmger返回结果
return:
    1.未完成登录即下线
    2.创建角色
--]]
s.resp.sure_agent = function(source, fd, player_id, agent)
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

s.resp.kick = function(source, player_id)
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
    socket.close(c.fd)
end

s.start(...)
