--- === PowerSpoons ===
---
--- Remote package manager for Hammerspoon productivity tools.

local PowerSpoons = {}
PowerSpoons.__index = PowerSpoons

PowerSpoons.name = "PowerSpoons"
PowerSpoons.version = "1.0.0"
PowerSpoons.author = "m0hill"
PowerSpoons.license = "MIT"
PowerSpoons.homepage = "https://github.com/m0hill/power-spoons"

local DEFAULT_CONFIG = {
	manifestUrl = "https://raw.githubusercontent.com/m0hill/power-spoons/main/manifest.json",
	baseDir = os.getenv("HOME") .. "/.hammerspoon/powerspoons",
	autoRefreshInterval = 24 * 60 * 60,
	managerId = "manager",
}

local function logMessage(message)
	local text = "[Power Spoons] " .. tostring(message or "")
	if hs.printf then
		hs.printf(text)
	else
		print(text)
	end
end

local function notifyMessage(message)
	hs.notify
		.new({
			title = "Power Spoons",
			informativeText = message or "",
			withdrawAfter = 4,
		})
		:send()
end

local function ensureDir(path)
	local attrs = hs.fs.attributes(path)
	if not attrs then
		hs.fs.mkdir(path)
	end
end

local function ensureBaseDirs(baseDir)
	ensureDir(baseDir)
	ensureDir(baseDir .. "/cache")
end

local function readFile(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end
	local contents = file:read("*all")
	file:close()
	return contents
end

local function writeFile(path, contents)
	local file = io.open(path, "w")
	if not file then
		return false
	end
	file:write(contents)
	file:close()
	return true
end

function PowerSpoons:init()
	self.config = self.config or {}
	return self
end

function PowerSpoons:setConfig(opts)
	self.config = opts or {}
	return self
end

function PowerSpoons:_resolvedConfig()
	local resolved = {}
	for key, value in pairs(DEFAULT_CONFIG) do
		resolved[key] = value
	end
	for key, value in pairs(self.config or {}) do
		resolved[key] = value
	end
	return resolved
end

function PowerSpoons:_cachePath(config)
	return config.baseDir .. "/cache/" .. config.managerId .. ".lua"
end

function PowerSpoons:_loadManagerFromCache(config)
	local cachePath = self:_cachePath(config)
	local code = readFile(cachePath)
	if not code or code == "" then
		return nil, "Manager code cache is missing"
	end

	local chunk, err = load(code, "powerspoons.manager")
	if not chunk then
		return nil, "Failed to load manager code: " .. tostring(err)
	end

	local ok, factoryOrErr = pcall(chunk)
	if not ok then
		return nil, "Failed to execute manager code: " .. tostring(factoryOrErr)
	end

	if type(factoryOrErr) ~= "function" then
		return nil, "Manager code did not return a factory function"
	end

	local ok2, managerOrErr = pcall(factoryOrErr, {
		manifestUrl = config.manifestUrl,
		baseDir = config.baseDir,
		autoRefreshInterval = config.autoRefreshInterval,
		managerId = config.managerId,
		reloadManager = function()
			self:reloadManager()
		end,
	})
	if not ok2 then
		return nil, "Failed to initialize manager: " .. tostring(managerOrErr)
	end

	if type(managerOrErr) ~= "table" or type(managerOrErr.init) ~= "function" then
		return nil, "Manager factory returned invalid object"
	end

	self.manager = managerOrErr
	self.manager.init()

	return self.manager
end

function PowerSpoons:_fetchManifest(config, callback)
	hs.http.asyncGet(config.manifestUrl, nil, function(status, body)
		if status ~= 200 then
			callback(false, "HTTP " .. tostring(status))
			return
		end

		local ok, manifest = pcall(hs.json.decode, body)
		if not ok or type(manifest) ~= "table" then
			callback(false, "Invalid manifest JSON")
			return
		end

		callback(true, manifest)
	end)
end

function PowerSpoons:_downloadManager(def, config, callback)
	if not def or not def.source then
		callback(false, "Manager source URL missing")
		return
	end

	hs.http.asyncGet(def.source, nil, function(status, body)
		if status ~= 200 then
			callback(false, "HTTP " .. tostring(status))
			return
		end

		if not body or body == "" then
			callback(false, "Empty manager response")
			return
		end

		local cachePath = self:_cachePath(config)
		local ok = writeFile(cachePath, body)
		if not ok then
			callback(false, "Failed to write manager cache")
			return
		end

		callback(true)
	end)
end

function PowerSpoons:_ensureManagerInstalled(config, callback)
	local cachePath = self:_cachePath(config)
	if hs.fs.attributes(cachePath) then
		callback(true)
		return
	end

	self:_fetchManifest(config, function(ok, manifestOrErr)
		if not ok then
			callback(false, manifestOrErr)
			return
		end

		local managerDef = nil
		if manifestOrErr.packages then
			for _, def in ipairs(manifestOrErr.packages) do
				if def.id == config.managerId then
					managerDef = def
					break
				end
			end
		end

		if not managerDef then
			callback(false, "Manager package not found in manifest")
			return
		end

		self:_downloadManager(managerDef, config, callback)
	end)
end

function PowerSpoons:start()
	local config = self:_resolvedConfig()
	ensureBaseDirs(config.baseDir)

	local manager = nil
	local err = nil

	if hs.fs.attributes(self:_cachePath(config)) then
		manager, err = self:_loadManagerFromCache(config)
		if not manager then
			logMessage(err)
		end
	end

	if manager then
		return self
	end

	self:_ensureManagerInstalled(config, function(ok, errOrNil)
		if not ok then
			logMessage(errOrNil)
			notifyMessage("Failed to load manager. Check console for details.")
			return
		end

		local _, loadErr = self:_loadManagerFromCache(config)
		if loadErr then
			logMessage(loadErr)
			notifyMessage("Failed to start manager. Check console for details.")
		end
	end)

	return self
end

function PowerSpoons:reloadManager()
	local config = self:_resolvedConfig()
	if self.manager and self.manager.stop then
		self.manager.stop()
	end
	self.manager = nil

	local _, err = self:_loadManagerFromCache(config)
	if err then
		logMessage(err)
		notifyMessage("Failed to reload manager. Check console for details.")
	end
end

function PowerSpoons:stop()
	if self.manager and self.manager.stop then
		self.manager.stop()
	end
	self.manager = nil
	return self
end

return PowerSpoons
