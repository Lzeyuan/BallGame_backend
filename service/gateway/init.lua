local skynet = require "skynet"
local socketdriver = require "skynet.socketdriver"
local netpack = require "skynet.netpack"
local gateserver = require "snax.gateserver"
local codec = require "codec"
local runconfig = require "runconfig"


local connections = {}
local gateway_players = {}
local testService = nil

local M = {
  name = "",
  id   = 0,
  exit = nil,
  init = nil,
  OnStart = nil,
  resp = {},
}

function M:Init(name, id)
  self.name = name
  self.id = tonumber(id)
end

M:Init(...)

--创建连接对象
local create_connection = function()
  return {
    fd = nil,
    address = nil,
    player_id = nil
  }
end

--创建万玩家对象
local create_gateway_player = function()
  return {
    player_id = nil,
    agent = nil,
    connection = nil
  }
end

local CMD = {}

CMD.send_by_fd = function(source, fd, msg)
  if connections[fd] == nil then
    return
  end

  local buffer = codec.json_pack(msg._cmd, msg)
  local buffer_msg_string = buffer:sub(5)
  skynet.error(string.format("send %d [%s] %s", fd, msg[1], buffer_msg_string))
  socketdriver.send(fd, buffer)
end

CMD.send = function(source, player_id, msg)
  local gplayer = gateway_players[player_id]
  if gplayer == nil then
    return
  end

  local c = gplayer.connection
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
  local connection = connections[fd]
  if connection == nil then
    local reason = "未完成登录即下线"
    skynet.call("agentmgr", "lua", "reqkick", player_id, reason)
    return false
  end

  connection.player_id = player_id

  local gplayer = create_gateway_player()
  gplayer.player_id = player_id
  gplayer.agent = agent
  gplayer.connection = connection
  gateway_players[player_id] = gplayer

  return true
end

CMD.kick = function(source, player_id)
  local gateway_player = gateway_players[player_id]
  if gateway_player == nil then
    return
  end

  gateway_players[player_id] = nil

  local connection = gateway_player.connection
  if connection == nil then
    return
  end

  connection[connection.fd] = nil
  gateserver.closeclient(connection.fd)
end

local handler = {}

function handler.command(cmd, source, ...)
  skynet.error(cmd)
  local f = assert(CMD[cmd])
  return f(source, ...)
end

function handler.open(source, config)
	testService = skynet.newservice("test", "test", M.id)
  return config.address, config.port
end

function handler.connect(fd, address)
  print(string.format("connect from %s %d", address, fd))
  local connection = create_connection()
  connection.fd = fd
  connection.address = address
  connections[fd] = connection
  gateserver.openclient(fd)
end

function handler.message(fd, message_buffer, size)
  skynet.error("message:" .. size)
  local message_string = netpack.tostring(message_buffer, size)
  local s = message_string:sub(3)
  skynet.error("[gateway] recv from fd:" .. fd .. " str:" .. s)
  local isok, cmd, message = codec.json_unpack(message_string);
  skynet.error("[gateway] cmd: " .. cmd)

  if not isok then
    skynet.error("[message] json_unpack fail")
    return
  end

  local connection = connections[fd]
  local player_id = connection.player_id

  -- todo:多个if
  if cmd == "EchoTest" then
    if testService then
      skynet.send(testService, "lua", "test", fd, cmd, message)
    end
  elseif not player_id then
    skynet.error("start login")
    local node = skynet.getenv("node")
    local nodecfg = runconfig[node]
    --todo:login节点负载均衡
    local login_id = math.random(1, #nodecfg.login)
    local login = "login" .. login_id
    skynet.send(login, "lua", "client", fd, cmd, message)
  else
    local gplayer = gateway_players[player_id]
    local agent = gplayer.agent
    skynet.send(agent, "lua", "client", cmd, message)
  end
end

local function close_fd(fd)
  local c = connections[fd]
  if c == nil then
    return
  end

  local player_id = c.player_id
  if player_id == nil then
    return
  else
    gateway_players[player_id] = nil
    local reason = "断线"
    skynet.call("agentmgr", "lua", "repick", player_id, reason)
  end
  gateserver.closeclient(fd)
end

function handler.disconnect(fd)
  local c = connections[fd]
  skynet.error("close " .. c.address .. " fd:" .. fd)
  close_fd(fd)
end

function handler.error(fd, error)
  skynet.error("[gateway] error " .. error)
  close_fd(fd)
end

gateserver.start(handler)