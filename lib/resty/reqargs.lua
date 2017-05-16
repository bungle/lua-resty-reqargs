local upload   = require "resty.upload"
local decode   = require "cjson.safe".decode
local tonumber = tonumber
local tmpname  = os.tmpname
local concat   = table.concat
local type     = type
local find     = string.find
local open     = io.open
local sub      = string.sub
local sep      = sub(package.config, 1, 1) or "/"
local ngx      = ngx
local req      = ngx.req
local var      = ngx.var
local body     = req.read_body
local file     = ngx.req.get_body_file
local data     = req.get_body_data
local pargs    = req.get_post_args
local uargs    = req.get_uri_args

local defaults = {
    tmp_dir          = var.reqargs_tmp_dir,
    timeout          = tonumber(var.reqargs_timeout)       or 1000,
    chunk_size       = tonumber(var.reqargs_chunk_size)    or 4096,
    max_get_args     = tonumber(var.reqargs_max_get_args)  or 100,
    max_post_args    = tonumber(var.reqargs_max_post_args) or 100,
    max_line_size    = tonumber(var.reqargs_max_line_size),
    max_file_size    = tonumber(var.reqargs_max_file_size),
    max_file_uploads = tonumber(var.reqargs_max_file_uploads)
}

local function read(f)
    local f, e = open(f, "rb")
    if not f then
        return nil, e
    end
    local c = f:read "*a"
    f:close()
    return c
end

local function basename(s)
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
    options = options or defaults
    local get = uargs(options.max_get_args or defaults.max_get_args)
    local ct = var.content_type or ""
    local post = {}
    local files = {}
    if sub(ct, 1, 33) == "application/x-www-form-urlencoded" then
        body()
        post = pargs(options.max_post_args or defaults.max_post_args)
    elseif sub(ct, 1, 19) == "multipart/form-data" then
        local tmpdr = options.tmp_dir or defaults.tmp_dir
        if tmpdr and sub(tmpdr, -1) ~= sep then
            tmpdr = tmpdr .. sep
        end
        local maxfz = options.max_file_size    or defaults.max_file_size
        local maxfs = options.max_file_uploads or defaults.max_file_uploads
        local chunk = options.chunk_size       or defaults.chunk_size
        local form, e = upload:new(chunk, options.max_line_size or defaults.max_line_size)
        if not form then return nil, e end
        local h, p, f, o, s
        local u = 0
        form:set_timeout(options.timeout or defaults.timeout)
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
                            if maxfz then
                                s = 0
                            end
                            f = {
                                name = d.name,
                                type = h["Content-Type"] and h["Content-Type"][1],
                                file = basename(d.filename),
                                temp = tmpdr and (tmpdr .. basename(tmpname())) or tmpname()
                            }
                            o, e = open(f.temp, "w+b")
                            if not o then return nil, e end
                            o:setvbuf("full", chunk)
                        else
                            p = { name = d.name, data = { n = 1 } }
                        end
                    end
                    h = nil
                end
                if o then
                    if maxfz then
                        s = s + #r
                        if maxfz < s then
                            o:close()
                            return nil, "The maximum size of an uploaded file exceeded."
                        end
                    end
                    if maxfs and maxfs < u + 1 then
                        o:close()
                        return nil, "The maximum number of files allowed to be uploaded simultaneously exceeded."
                    end
                    local ok, e = o:write(r)
                    if not ok then
                        o:close()
                        return nil, e
                    end
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
                    if maxfs and f.size > 0 then
                        u = u + 1
                    end
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
        local t, _, e = form:read()
        if not t then return nil, e end
    elseif sub(ct, 1, 16) == "application/json" then
        body()
        local j = data()
        if j == nil then
            local f = file()
            if f ~= nil then
                j = read(f)
                if j then
                    post = decode(j) or {}
                end
            end
        else
            post = decode(j) or {}
        end
    else
        body()
        local b = data()
        if b == nil then
            local f = file()
            if f ~= nil then
                b = read(f)
            end
        end
        if b then
            post = { b }
        end
    end
    return get, post, files
end
