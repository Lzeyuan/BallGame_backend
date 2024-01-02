local cjson = require "cjson"
local skynet = require "skynet"
local codec = {}

function codec.json_pack(cmd, msg)
    local body = cjson.encode(msg)    --协议体字节流
    local namelen = string.len(cmd)   --协议名长度
    local bodylen = string.len(body)  --协议体长度
    local len = namelen + bodylen + 2 --协议总长度
    local format = string.format("> i2 i2 c%d c%d", namelen, bodylen)
    local buff = string.pack(format, len, namelen, cmd, body)
    return buff
end

function codec.json_unpack(buffer)
    local length = string.len(buffer)

    local name_length_format = string.format("> i2 c%d", length - 2)
    local name_length, other = string.unpack(name_length_format, buffer)

    local body_length = length - 2 - name_length
    local format = string.format("> c%d c%d", name_length, body_length)
    ---@diagnostic disable-next-line: param-type-mismatch
    local cmd, bodybuff = string.unpack(format, other)

    local isok, msg = pcall(cjson.decode, bodybuff)

    if not isok or not cmd then
        skynet.error("[json_unpack] error")
        return isok
    end

    local error_string
        = string.format("[json_unpack] len = %d, cmd = %s, namelen = %d", length, cmd, name_length)
    skynet.error(error_string)

    return isok, cmd, msg
end

return codec
