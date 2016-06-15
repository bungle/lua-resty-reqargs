local upload  = require "resty.upload"
local decode  = require "cjson.safe".decode
local tmpname = os.tmpname
local concat  = table.concat
local type    = type
local find    = string.find
local open    = io.open
local sub     = string.sub
local ngx     = ngx
local req     = ngx.req
local var     = ngx.var
local body    = req.read_body
local data    = req.get_body_data
local pargs   = req.get_post_args
local uargs   = req.get_uri_args

local function rightmost(s, sep)
    local p = 1
    local i = find(s, sep, 1, true)
    while i do
        p = i + 1
        i = find(s, sep, p, true)
    end
    if p > 1 then
        s = sub(s, p)
    end
    return s
end

local function basename(s)
    return rightmost(rightmost(s, "\\"), "/")
end

local function kv(r, s)
    if s == "formdata" then return end
    local e = find(s, "=", 1, true)
    if e then
        r[sub(s, 2, e - 1)] = sub(s, e + 2, #s - 1)
    else
        r[#r+1] = s
    end
end

local function parse(s)
    if not s then return nil end
    local r = {}
    local i = 1
    local b = find(s, ";", 1, true)
    while b do
        local p = sub(s, i, b - 1)
        kv(r, p)
        i = b + 1
        b = find(s, ";", i, true)
    end
    local p = sub(s, i)
    if p ~= "" then kv(r, p) end
    return r
end

return function(options)
    local get = uargs()
    local post = {}
    local files = {}
    local ct = var.content_type
    if ct == nil then return get, post, files end
    if sub(ct, 1, 19) == "multipart/form-data" then
        local chunk   = options.chunk_size or 8192
        local form, e = upload:new(chunk)
        if not form then return nil, e end
        local h, p, f, o
        form:set_timeout(options.timeout or 1000)
        while true do
            local t, r, e = form:read()
            if not t then return nil, e end
            if t == "header" then
                if not h then h = {} end
                if type(r) == "table" then
                    local k, v = r[1], parse(r[2])
                    if v then h[k] = v end
                end
            elseif t == "body" then
                if h then
                    local d = h["Content-Disposition"]
                    if d then
                        if d.filename then
                            f = {
                                name = d.name,
                                type = h["Content-Type"] and h["Content-Type"][1],
                                file = basename(d.filename),
                                temp = tmpname()
                            }
                            o, e = open(f.temp, "w+")
                            if not o then return nil, e end
                            o:setvbuf("full", chunk)
                        else
                            p = { name = d.name, data = { n = 1 } }
                        end
                    end
                    h = nil
                end
                if o then
                    local ok, e = o:write(r)
                    if not ok then return nil, e end
                elseif p then
                    local n = p.data.n
                    p.data[n] = r
                    p.data.n = n + 1
                end
            elseif t == "part_end" then
                if o then
                    f.size = o:seek()
                    o:close()
                    o = nil
                end
                local c, d
                if f then
                    c, d, f = files, f, nil
                elseif p then
                    c, d, p = post, p, nil
                end
                if c then
                    local n = d.name
                    local s = d.data and concat(d.data) or d
                    if n then
                        local z = c[n]
                        if z then
                            if z.n then
                                z.n = z.n + 1
                                z[z.n] = s
                            else
                                z = { z, s }
                                z.n = 2
                            end
                            c[n] = z
                        else
                            c[n] = s
                        end
                    else
                        c.n = c.n + 1
                        c[c.n] = s
                    end
                end
            elseif t == "eof" then
                break
            end
        end
        local t, r, e = form:read()
        if not t then return nil, e end
    elseif sub(ct, 1, 16) == "application/json" then
        body()
        post = decode(data()) or {}
    else
        body()
        post = pargs()
    end
    return get, post, files
end