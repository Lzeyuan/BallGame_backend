
local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

s.snode = nil --scene_node
s.sname = nil --scene_id

local create_play_error_msg = function ()
    return {
        _cmd = "PlayError",
        ErrorCode = nil,
        Message = nil,
    }
end 

-- 暂时写死游戏场景
s.client.Enter = function(message)
    local error_msg = create_play_error_msg()
    if s.sname then
        error_msg.ErrorCode = 1001
        error_msg.Message = "已在场景"
        s.send_to_client(error_msg)
    end
    local snode = "node1"
    local sname = "scene1001"
    local isok = s.call(snode, sname, "enter", s.id, mynode, skynet.self())
    if not isok then
        error_msg.ErrorCode = 1002
        error_msg.Message = "进入失败"
        s.send_to_client(error_msg)
    end
    s.snode = snode
    s.sname = sname
    s.send_to_client(error_msg)
end

--改变方向
s.client.Shift  = function(msg)
    if not s.sname then
        return
    end
    local x = msg[2] or 0
    local y = msg[3] or 0
    s.call(s.snode, s.sname, "shift", s.id, x, y)
end

s.leave_scene = function()
    --不在场景
    if not s.sname then
        return
    end
    s.call(s.snode, s.sname, "leave", s.id)
    s.snode = nil
    s.sname = nil
end