local skynet = require "skynet"
local s = require "service"

s.client = {}

s.resp.client = function(source, fd, cmd, msg)
    if s.client[cmd] then
        local ret_msg = s.client[cmd](fd, msg, source)
        skynet.send(source, "lua", "send_by_fd", fd, ret_msg)
    else
        skynet.error("[login] s.resp.client fail", cmd)
    end
end

local create_msg = function ()
    return {
        _cmd = "LoginError",
        ErrorCode = nil,
        Message = nil,
    }
end 

s.client.Login = function(fd, msg, source)
    local playerid = msg.UserName
    local password = msg.Password
    local gateway = source
    local node = skynet.getenv("node")
    skynet.error("[login] " .. password)

    local ret_msg = create_msg();

    --todo:校验用户名密码
    if password ~= "123" then
        ret_msg.ErrorCode = 2
        ret_msg.Message = "密码错误"
        skynet.error("[login] 密码错误")
        return ret_msg
    end
    --发给agentmgr
    local isok, agent = skynet.call("agentmgr", "lua", "reqlogin", playerid, node, gateway)
    if not isok then
        ret_msg.ErrorCode = 1
        ret_msg.Message = "登录中或登出中"
        skynet.error("[login] 登录中或登出中")
        return ret_msg
    end
    --回应gate
    local isok = skynet.call(gateway, "lua", "sure_agent", fd, playerid, agent)
    if not isok then
        ret_msg.ErrorCode = 3
        ret_msg.Message = "未完成登录即下线"
        skynet.error("[login] 未完成登录即下线")
        return ret_msg
    end
    ret_msg.ErrorCode = 0
    ret_msg.Message = "登录成功"
    skynet.error("[login] 登录成功")
    return ret_msg
end

s.start(...)
