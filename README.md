# lua-resty-reqargs

Helper to Retrieve `application/x-www-form-urlencoded`, `multipart/form-data`, and `application/json` Request Arguments.

## Synopsis

```lua
local get, post, files = require "resty.reqargs"()
if not get then
    error(post)
end
-- Use get, post, and files...
```

## Installation

Just place [`reqargs.lua`](https://github.com/bungle/lua-resty-reqargs/blob/master/lib/resty/reqargs.lua)
somewhere in your `package.path`, under `resty` directory. If you are using OpenResty, the default location
would be `/usr/local/openresty/lualib/resty`.

### Using OpenResty Package Manager (opm)

```Shell
$ opm get bungle/lua-resty-reqargs
```

### Using LuaRocks

```Shell
$ luarocks install lua-resty-reqargs
```

LuaRocks repository for `lua-resty-reqargs` is located at https://luarocks.org/modules/bungle/lua-resty-reqargs.

## API

This module has only one function, and that function is loaded with require:

```lua
local reqargs = require "resty.reqargs"
```

### get, post, files regargs(options)

When you call the function (`reqargs`) you can pass it `options`. These
options override whatever you may have defined in your Nginx configuration
(or the defaults). You may use the following options:

```lua
{
    tmp_dir          = "/tmp",
    timeout          = 1000,
    chunk_size       = 4096,
    max_get_args     = 100,
    mas_post_args    = 100,
    max_line_size    = 512,
    max_file_uploads = 10
}
```

This function will return three (3) return values, and they are called
`get`, `post`,  and `files`. These are Lua tables containing the data
that was (HTTP) requested. `get` contains HTTP request GET arguments
retrieved with [ngx.req.get_uri_args](https://github.com/openresty/lua-nginx-module#ngxreqget_uri_args).
`post` contains either HTTP request POST arguments retrieved with
[ngx.req.get_post_args](https://github.com/openresty/lua-nginx-module#ngxreqget_post_args),
or in case of `application/json` (as a content type header for the request),
it will read the request body and decode the JSON, and the `post` will
then contain the decoded JSON structure presented as Lua tables. The
last return value `files` contains all the files uploaded. The `files`
return value will only contain data when there are actually files uploaded
and that the request content type is set to `multipart/form-data`. `files`
has the same structure as `get` and `post` for the keys, but the values
are presented as a Lua tables, that look like this (think about PHP's `$_FILES`):

```lua
{
    -- The name of the file upload form field (same as the key)
    name = "photo",
    -- The name of the file that the user selected for the upload
    file = "cat.jpg",
    -- The mimetype of the uploaded file
    type = "image/jpeg"
    -- The file size of the uploaded file (in bytes)
    size = 123465
    -- The location where the uploaded file was streamed
    temp = "/tmp/????"
}
```

In case of error, this function will return `nil`, `error message`.

## Nginx Configuration Variables

You can configure several aspects of `lua-resty-reqargs` directly from
the Nginx configuration, here are the configuration values that you may
use, and their default values:

```nginx
# the default is the system temp dir
set $reqargs_tmp_dir           /tmp;
# see https://github.com/openresty/lua-resty-upload
set $reqargs_timeout           1000;
# see https://github.com/openresty/lua-resty-upload
set $reqargs_chunk_size        4096;
# see https://github.com/openresty/lua-nginx-module#ngxreqget_uri_args
set $reqargs_max_get_args      100;
# see https://github.com/openresty/lua-nginx-module#ngxreqget_post_args
set $reqargs_max_post_args     100;
# see https://github.com/openresty/lua-resty-upload
set $reqargs_max_line_size     512;  
# the default is unlimited
set $reqargs_max_file_uploads  10;
```

## Changes

The changes of every release of this module is recorded in [Changes.md](https://github.com/bungle/lua-resty-reqargs/blob/master/Changes.md) file.

## License

`lua-resty-reqargs` uses two clause BSD license.

```
Copyright (c) 2015 - 2017, Aapo Talvensaari
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this
  list of conditions and the following disclaimer in the documentation and/or
  other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES`
