local skynet = require "skynet"
local s = require "service"

CMD = {}

s.gateway = nil

function CMD.EchoTest(fd, msg, source)
    return {
        _cmd = "EchoTest",
        Message = "hello world! received: " .. msg.Message
    }
end

s.resp.test = function(source, fd, cmd, msg)
    skynet.error("[test] cmd: " .. cmd)

    if CMD[cmd] then
        local ret_msg = CMD[cmd](fd, msg, source)
        skynet.send(source, "lua", "send_by_fd", fd, ret_msg)
    else
        skynet.error("[test] s.resp.test fail", cmd)
    end
end

function s.OnStart(gateway)
	s.gateway = gateway
end

s.start(...)