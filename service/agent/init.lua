local skynet = require "skynet"
local s = require "service"

s.client = {}
s.gateway = nil

require "scene"


s.resp.client = function(source, cmd, msg)
	if s.client[cmd] then
		local ret_msg = s.client[cmd](msg, source)
		if ret_msg then
			skynet.send(source, "lua", "send", s.id, ret_msg)
		end
	else
		skynet.error("[agent] s.resp.client fail", cmd)
	end
end

s.client.work = function(msg)
	s.data.coin = s.data.coin + 1
	return { "work", s.data.coin }
end

s.resp.kick = function(source)
	s.leave_scene()
	--在此处保存角色数据
	skynet.sleep(200)
end

s.resp.exit = function(source)
	skynet.exit()
end

function s.send_to_client(msg)
	skynet.send(s.gateway, "lua", "send", s.id, msg)
end

s.init = function()
	--playerid = s.id
	--在此处加载角色数据
	-- skynet.sleep(200)
	s.data = {
		coin = 100,
		hp = 200,
	}
end

function s.OnStart(gateway)
	s.gateway = gateway
end

s.start(...)
