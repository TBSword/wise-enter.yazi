--- @sync entry

local function setup(self, opts)
	self.open_multi = opts and opts.open_multi or false
end

local function is_folder_only(path)
	local p = io.popen("ls -lA " .. ya.quote(path), "r")
	if p == nil then return false end
	local num = -1
	local flag = false
	for line in p:lines() do
		num = num + 1
		if num == 1 and line:sub(1, 1) == "d" then flag = true end
	end
	p:close()
	return num == 1 and flag or false
end

local function get_innermost_directory(path)
	if not is_folder_only(path) then return path end
	local dirs = io.popen("ls -A " .. ya.quote(path), "r")
	if dirs == nil then return path end
	local next = path
	for dir in dirs:lines() do
		next = path .. "/" .. dir
	end
	dirs:close()
	return get_innermost_directory(next)
end

local function is_archive(mime)
	local patterns = {
		"application/zip",
		"application/gzip",
		"application/x-tar",
		"application/x-bzip",
		"application/x-bzip2",
		"application/x-7z-compressed",
		"application/x-rar",
		"application/x-xz",
	}
	for _, pattern in ipairs(patterns) do
		if mime:match(pattern) then return true end
	end
	return false
end

local function extract(archive)
	local filename = archive:match("(.*)%.([^%.]+)$")
	os.execute("unar -f -d " .. ya.quote(archive) .. " >/dev/null 2>&1")
	return filename
end

local function entry(self, jobs)
	local args = jobs and jobs.args or {}
	local skip_special = args[1] == "skip"

	local h = cx.active.current.hovered
	if h == nil then return end

	if h.cha.is_dir then
		local path = tostring(h.url)
		if is_folder_only(path) then
			ya.emit("cd", { get_innermost_directory(path) })
		else
			ya.emit("enter", {})
		end

	elseif is_archive(h:mime()) then
		local extracted = extract(tostring(h.url))
		ya.emit("cd", { get_innermost_directory(extracted) })

	elseif not skip_special then
		local m = h:mime()
		if m == "text/html" then
			os.execute("firefox-developer-edition --new-window " .. ya.quote(tostring(h.url)) .. " &")
		else
			local url_str = tostring(h.url)
			local is_script = m:find("shellscript")
				or m:find("/x%-sh")
				or m:find("/x%-bash")
				or url_str:find("%.sh$")
				or url_str:find("%.bash$")
				or url_str:find("%.zsh$")
			if is_script then
				os.execute('kitty -- sh -c "cd \"$(dirname ' .. ya.quote(tostring(h.url)) .. ')\" && sh ' .. ya.quote(tostring(h.url)) .. '; echo; echo Press Enter to exit...; read _" &')
			else
				ya.emit("open", { hovered = not self.open_multi })
			end
		end
	else
		ya.emit("open", { hovered = not self.open_multi })
	end
end

return { entry = entry, setup = setup }
