-- Power Spoons – Remote Package Manager for Hammerspoon
-- Paste this into your ~/.hammerspoon/init.lua and reload config.

local PowerSpoons = (function()
	-- Configuration
	local MANIFEST_URL = "https://raw.githubusercontent.com/m0hill/power-spoons/main/manifest.json"
	local POWERSPOONS_DIR = os.getenv("HOME") .. "/.hammerspoon/powerspoons"
	local STATE_FILE = POWERSPOONS_DIR .. "/state.json"
	local SECRETS_FILE = POWERSPOONS_DIR .. "/secrets.json"
	local SETTINGS_DIR = POWERSPOONS_DIR .. "/settings"
	local CACHE_DIR = POWERSPOONS_DIR .. "/cache"
	local AUTO_REFRESH_INTERVAL = 24 * 60 * 60 -- 24 hours

	-- Manager API
	local M = {}

	-- Runtime state (ephemeral - never persisted)
	local runtime = {
		menubar = nil,
		instances = {}, -- [id] = running package instance
	}

	local function logError(context, err)
		local message = string.format("[Power Spoons] %s: %s", context or "Error", err or "unknown error")
		if hs.printf then
			hs.printf(message)
		else
			print(message)
		end
	end

	-- Helpers
	local function ensureDir(path)
		local attrs = hs.fs.attributes(path)
		if not attrs then
			hs.fs.mkdir(path)
		end
	end

	local function ensurePowerSpoonsDir()
		ensureDir(POWERSPOONS_DIR)
		ensureDir(CACHE_DIR)
		ensureDir(SETTINGS_DIR)
	end

	local function readJsonFile(filePath, defaultValue)
		local file = io.open(filePath, "r")
		if not file then
			return defaultValue
		end
		local content = file:read("*all")
		file:close()

		if not content or content == "" then
			return defaultValue
		end

		local ok, data = pcall(hs.json.decode, content)
		if not ok then
			logError("JSON decode failed for " .. filePath, data)
			return defaultValue
		end

		if type(data) ~= "table" then
			logError("JSON decode returned non-table for " .. filePath, "Unexpected data type")
			return defaultValue
		end

		return data
	end

	local function writeJsonFile(filePath, data)
		local ok, json = pcall(hs.json.encode, data, true)
		if not ok then
			-- json contains error message when ok is false
			logError("JSON encode failed for " .. filePath, json)
			return false, "Failed to encode JSON: " .. tostring(json)
		end

		if not json then
			logError("JSON encode returned nil for " .. filePath, "No JSON produced")
			return false, "JSON encode returned nil"
		end

		local file = io.open(filePath, "w")
		if not file then
			logError("File write failed for " .. filePath, "Unable to open file")
			return false, "Failed to open file for writing"
		end

		file:write(json)
		file:close()
		return true
	end

	-- Persistence layer
	local function loadState()
		local defaultState = {
			version = 1,
			manifest = nil,
			lastRefresh = 0,
			packages = {}, -- [id] = { installed=bool, enabled=bool }
		}
		local state = readJsonFile(STATE_FILE, defaultState)
		-- Ensure all fields exist
		state.version = state.version or 1
		state.manifest = state.manifest or nil
		state.lastRefresh = state.lastRefresh or 0
		state.packages = type(state.packages) == "table" and state.packages or {}
		return state
	end

	local function saveState(state)
		ensurePowerSpoonsDir()
		return writeJsonFile(STATE_FILE, state)
	end

	local function loadSecrets()
		local defaultSecrets = {}
		return readJsonFile(SECRETS_FILE, defaultSecrets)
	end

	local function saveSecrets(secrets)
		ensurePowerSpoonsDir()
		return writeJsonFile(SECRETS_FILE, secrets)
	end

	-- Migration from old hs.settings to file-based storage
	local function migrateFromSettings()
		local OLD_SETTINGS_KEY = "powerspoons.state"
		local oldData = hs.settings.get(OLD_SETTINGS_KEY)
		if not oldData or type(oldData) ~= "table" then
			return false
		end

		-- Check if migration already happened
		if hs.fs.attributes(STATE_FILE) then
			return false
		end

		-- Migrate state
		local newState = {
			version = oldData.version or 1,
			manifest = oldData.manifest,
			lastRefresh = oldData.lastRefresh or 0,
			packages = oldData.packages or {},
		}
		local savedState, stateErr = saveState(newState)
		if not savedState then
			logError("Migrating legacy state", stateErr)
		end

		-- Migrate secrets
		if oldData.secrets and type(oldData.secrets) == "table" then
			local savedSecrets, secretsErr = saveSecrets(oldData.secrets)
			if not savedSecrets then
				logError("Migrating legacy secrets", secretsErr)
			end
		end

		-- Helper to check if a value is JSON-serializable
		local function isJsonSafe(val)
			if val == nil then
				return true
			end
			local t = type(val)
			if t == "string" or t == "number" or t == "boolean" then
				return true
			end
			if t == "table" then
				-- Try encoding to check if safe
				local ok, _ = pcall(hs.json.encode, val)
				return ok
			end
			return false
		end

		-- Migrate package settings
		-- Known package prefixes: lyrics., trimmy., whisper., gemini.
		local packagePrefixes = { "lyrics", "trimmy", "whisper", "gemini" }
		for _, pkgId in ipairs(packagePrefixes) do
			local prefix = pkgId .. "."
			local pkgSettings = {}
			local foundAny = false

			-- Scan all hs.settings keys for this package
			local allKeys = hs.settings.getKeys() or {}
			for _, key in ipairs(allKeys) do
				if key:sub(1, #prefix) == prefix then
					local settingKey = key:sub(#prefix + 1)
					local value = hs.settings.get(key)

					-- Only migrate JSON-safe values
					if isJsonSafe(value) then
						pkgSettings[settingKey] = value
						foundAny = true
					end

					-- Clear old setting
					hs.settings.set(key, nil)
				end
			end

			if foundAny then
				M.setSettings(pkgId, pkgSettings)
			end
		end

		-- Clear old settings
		hs.settings.set(OLD_SETTINGS_KEY, nil)

		return true
	end

	-- Helpers (continued)
	local function ensureCacheDir()
		ensurePowerSpoonsDir()
	end

	local function getCacheFilePath(packageId)
		return CACHE_DIR .. "/" .. packageId .. ".lua"
	end

	-- Universal sound effects map
	local SOUNDS = {
		success = "Glass",
		error = "Basso",
		warning = "Funk",
		start = "Ping",
		stop = "Purr",
		info = "Tink",
		capture = "Tink",
		process = "Purr",
		cancel = "Funk",
	}

	-- Internal notify for manager use
	local function notify(title, text)
		hs.notify
			.new({
				title = title,
				informativeText = text or "",
				withdrawAfter = 3,
			})
			:send()
	end

	local function reportError(context, err, shouldNotify)
		logError(context, err)
		if shouldNotify then
			notify("Power Spoons", context .. ": " .. tostring(err or "unknown error"))
		end
	end

	-- Universal Notification API for packages
	-- options: { withdrawAfter = number, sound = string, soundEnabled = bool }
	function M.notify(title, text, options)
		options = options or {}
		local notification = hs.notify.new({
			title = title,
			informativeText = text or "",
			withdrawAfter = options.withdrawAfter or 3,
		})
		if options.sound and options.soundEnabled ~= false then
			notification:soundName(options.sound)
		end
		notification:send()
	end

	-- Universal Sound API for packages
	-- type: "success", "error", "warning", "start", "stop", "info", "capture", "process", "cancel"
	function M.playSound(soundType)
		local soundName = SOUNDS[soundType]
		if soundName then
			local sound = hs.sound.getByName(soundName)
			if sound then
				sound:play()
			end
		end
	end

	-- Universal Logging API for packages
	function M.log(packageId, message)
		local prefix = packageId and ("[Power Spoons:" .. packageId .. "]") or "[Power Spoons]"
		local fullMessage = string.format("%s %s", prefix, message or "")
		if hs.printf then
			hs.printf(fullMessage)
		else
			print(fullMessage)
		end
	end

	local function secretMask(value)
		if not value or value == "" then
			return "[Not set]"
		end
		if #value <= 4 then
			return "[••••]"
		end
		return "[••••" .. value:sub(-4) .. "]"
	end

	-- Secrets API
	function M.getSecret(key)
		local secrets = loadSecrets()
		return secrets[key]
	end

	function M.setSecret(key, value)
		local secrets = loadSecrets()
		if value == nil or value == "" then
			secrets[key] = nil
		else
			secrets[key] = value
		end
		local saved, err = saveSecrets(secrets)
		if not saved then
			reportError("Saving secret '" .. key .. "'", err, true)
		end
	end

	-- Package Settings API
	-- Each package gets its own settings file: ~/.hammerspoon/powerspoons/settings/{packageId}.json
	function M.getSetting(packageId, key, defaultValue)
		local settingsFile = SETTINGS_DIR .. "/" .. packageId .. ".json"
		local settings = readJsonFile(settingsFile, {})
		local value = settings[key]
		if value == nil then
			return defaultValue
		end
		return value
	end

	function M.setSetting(packageId, key, value)
		ensurePowerSpoonsDir()
		local settingsFile = SETTINGS_DIR .. "/" .. packageId .. ".json"
		local settings = readJsonFile(settingsFile, {})
		if value == nil then
			settings[key] = nil
		else
			settings[key] = value
		end
		local ok, err = writeJsonFile(settingsFile, settings)
		if not ok then
			reportError("Saving setting '" .. packageId .. "." .. key .. "'", err, true)
		end
		return ok, err
	end

	function M.getSettings(packageId)
		local settingsFile = SETTINGS_DIR .. "/" .. packageId .. ".json"
		return readJsonFile(settingsFile, {})
	end

	function M.setSettings(packageId, settingsTable)
		ensurePowerSpoonsDir()
		local settingsFile = SETTINGS_DIR .. "/" .. packageId .. ".json"
		local ok, err = writeJsonFile(settingsFile, settingsTable)
		if not ok then
			reportError("Saving settings for '" .. packageId .. "'", err, true)
		end
		return ok, err
	end

	local function openSecretPrompt(secretDef)
		local current = M.getSecret(secretDef.key) or ""
		local button, text = hs.dialog.textPrompt(secretDef.label, secretDef.hint or "", current, "Save", "Cancel")
		if button == "Save" then
			if text and text ~= "" then
				M.setSecret(secretDef.key, text)
			else
				M.setSecret(secretDef.key, nil)
			end
		end
	end

	-- Package helpers
	local function getPackageDef(id)
		local state = loadState()
		if not state.manifest or not state.manifest.packages then
			return nil
		end
		for _, def in ipairs(state.manifest.packages) do
			if def.id == id then
				return def
			end
		end
		return nil
	end

	local function getPackageFlags(id)
		local state = loadState()
		local flags = state.packages[id]
		if not flags then
			return { installed = false, enabled = false, version = nil, lastUpdated = nil }
		end
		return {
			installed = flags.installed == true,
			enabled = flags.enabled ~= false,
			version = flags.version,
			lastUpdated = flags.lastUpdated,
		}
	end

	-- Package loading & execution
	local function loadPackageCode(packageId, code)
		local chunkFunc, err = load(code, packageId .. ".lua")
		if not chunkFunc then
			return nil, "Failed to load package code: " .. tostring(err)
		end

		local ok, factoryOrErr = pcall(chunkFunc)
		if not ok then
			return nil, "Failed to execute package code: " .. tostring(factoryOrErr)
		end

		if type(factoryOrErr) ~= "function" then
			return nil, "Package must return a function"
		end

		local ok2, packageOrErr = pcall(factoryOrErr, M)
		if not ok2 then
			return nil, "Failed to create package instance: " .. tostring(packageOrErr)
		end

		return packageOrErr, nil
	end

	-- Package download
	local function downloadPackage(packageDef, callback)
		local url = packageDef.source
		if not url then
			reportError("Download package '" .. packageDef.id .. "'", "No source URL specified", true)
			callback(false, "No source URL specified")
			return
		end

		hs.http.asyncGet(url, nil, function(status, body, _)
			if status ~= 200 then
				logError("Download package '" .. packageDef.id .. "'", "HTTP " .. tostring(status))
				callback(false, "HTTP " .. tostring(status))
				return
			end

			if not body or body == "" then
				logError("Download package '" .. packageDef.id .. "'", "Empty response body")
				callback(false, "Empty response")
				return
			end

			-- Save to cache
			ensureCacheDir()
			local cachePath = getCacheFilePath(packageDef.id)
			local file = io.open(cachePath, "w")
			if file then
				file:write(body)
				file:close()
			else
				logError("Download package '" .. packageDef.id .. "'", "Unable to write cache file")
				callback(false, "Failed to cache package")
				return
			end

			callback(true, body)
		end)
	end

	-- Package lifecycle
	local function startPackage(id)
		local flags = getPackageFlags(id)
		if not flags.installed or not flags.enabled then
			return
		end

		if runtime.instances[id] then
			return -- Already running
		end

		local def = getPackageDef(id)
		if not def then
			logError("Start package '" .. id .. "'", "Not found in manifest")
			notify("Power Spoons", "Package '" .. id .. "' not found in manifest")
			return
		end

		-- Load code from cache
		local cachePath = getCacheFilePath(id)
		local file = io.open(cachePath, "r")
		if not file then
			logError("Start package '" .. id .. "'", "Code not cached")
			notify("Power Spoons", "Package '" .. id .. "' code not cached. Try reinstalling.")
			return
		end
		local code = file:read("*all")
		file:close()

		if not code then
			logError("Start package '" .. id .. "'", "Cached code empty")
			notify("Power Spoons", "Package '" .. id .. "' code not available")
			return
		end

		local instance, err = loadPackageCode(id, code)
		if not instance then
			logError("Start package '" .. id .. "'", err)
			notify("Power Spoons", "Failed to load package '" .. id .. "': " .. tostring(err))
			return
		end

		runtime.instances[id] = instance

		if instance.start then
			local ok, errStart = pcall(instance.start)
			if not ok then
				logError("Start package '" .. id .. "'", errStart)
				notify("Power Spoons", "Failed to start package '" .. id .. "': " .. tostring(errStart))
			end
		end
	end

	local function stopPackage(id)
		local instance = runtime.instances[id]
		if not instance then
			return
		end
		if instance.stop then
			local ok, errStop = pcall(instance.stop)
			if not ok then
				logError("Stop package '" .. id .. "'", errStop)
			end
		end
		runtime.instances[id] = nil
	end

	local function installPackage(id, callback)
		local def = getPackageDef(id)
		if not def then
			reportError("Install package '" .. id .. "'", "Package not found", true)
			if callback then
				callback(false, "Package not found")
			end
			return
		end

		downloadPackage(def, function(success, bodyOrErr)
			if not success then
				reportError("Failed to download '" .. id .. "'", bodyOrErr, true)
				if callback then
					callback(false, bodyOrErr)
				end
				return
			end

			-- Update persistent state
			local state = loadState()
			local pkgState = state.packages[id] or {}
			pkgState.installed = true
			if pkgState.enabled == nil then
				pkgState.enabled = true
			end
			pkgState.version = def.version or pkgState.version
			pkgState.lastUpdated = os.time()
			state.packages[id] = pkgState
			local saved, saveErr = saveState(state)
			if not saved then
				reportError("Saving state after installing '" .. id .. "'", saveErr, true)
			end

			startPackage(id)
			notify("Power Spoons", "Installed: " .. def.name)

			if callback then
				callback(true)
			end
		end)
	end

	local function updatePackage(id, callback)
		local def = getPackageDef(id)
		if not def then
			reportError("Update package '" .. id .. "'", "Package not found", true)
			if callback then
				callback(false, "Package not found")
			end
			return
		end

		local flags = getPackageFlags(id)
		if not flags.installed then
			reportError("Update package '" .. id .. "'", "Package is not installed", true)
			if callback then
				callback(false, "Package is not installed")
			end
			return
		end

		downloadPackage(def, function(success, bodyOrErr)
			if not success then
				reportError("Failed to update '" .. id .. "'", bodyOrErr, true)
				if callback then
					callback(false, bodyOrErr)
				end
				return
			end

			local state = loadState()
			local pkgState = state.packages[id] or {}
			pkgState.installed = true
			if pkgState.enabled == nil then
				pkgState.enabled = true
			end
			pkgState.version = def.version or pkgState.version
			pkgState.lastUpdated = os.time()
			state.packages[id] = pkgState
			local saved, saveErr = saveState(state)
			if not saved then
				reportError("Saving state after updating '" .. id .. "'", saveErr, true)
			end

			if runtime.instances[id] then
				stopPackage(id)
			end

			if pkgState.enabled then
				startPackage(id)
			end

			notify("Power Spoons", string.format("Updated: %s (%s)", def.name, def.version or "new version"))

			if callback then
				callback(true)
			end
		end)
	end

	local function uninstallPackage(id)
		stopPackage(id)

		-- Update persistent state
		local state = loadState()
		state.packages[id] = nil
		local saved, saveErr = saveState(state)
		if not saved then
			reportError("Saving state after uninstalling '" .. id .. "'", saveErr, true)
		end

		-- Delete cached file
		local cachePath = getCacheFilePath(id)
		if hs.fs.attributes(cachePath) then
			os.remove(cachePath)
		end
	end

	-- Forward declaration for buildMenu (used in togglePackageEnabled)
	local buildMenu

	local function togglePackageEnabled(id)
		local flags = getPackageFlags(id)

		if not flags.installed then
			-- Install it
			installPackage(id, function(_)
				if runtime.menubar then
					runtime.menubar:setMenu(buildMenu())
				end
			end)
			return
		end

		-- Toggle enabled state
		local state = loadState()
		if not state.packages[id] then
			state.packages[id] = { installed = true, enabled = false }
		end

		if state.packages[id].enabled then
			state.packages[id].enabled = false
			local saved, saveErr = saveState(state)
			if not saved then
				reportError("Disabling package '" .. id .. "'", saveErr, true)
			end
			stopPackage(id)
		else
			state.packages[id].enabled = true
			local saved, saveErr = saveState(state)
			if not saved then
				reportError("Enabling package '" .. id .. "'", saveErr, true)
			end
			startPackage(id)
		end
	end

	-- Manifest fetching
	local function fetchManifest(callback)
		hs.http.asyncGet(MANIFEST_URL, nil, function(status, body, _)
			if status ~= 200 then
				logError("Fetch manifest", "HTTP " .. tostring(status))
				if callback then
					callback(false, "HTTP " .. tostring(status))
				end
				return
			end

			local ok, manifest = pcall(hs.json.decode, body)
			if not ok or type(manifest) ~= "table" then
				logError("Fetch manifest", "Invalid JSON")
				if callback then
					callback(false, "Invalid manifest JSON")
				end
				return
			end

			-- Update persistent state
			local state = loadState()
			state.manifest = manifest
			state.lastRefresh = os.time()
			local saved, saveErr = saveState(state)
			if not saved then
				reportError("Saving state after manifest refresh", saveErr, true)
			end

			if callback then
				callback(true, manifest)
			end
		end)
	end

	local function refreshManifest(manual, callback)
		if manual then
			notify("Power Spoons", "Refreshing package list...")
		end

		fetchManifest(function(success, resultOrErr)
			if not success then
				reportError("Failed to refresh manifest", resultOrErr, manual)
				if callback then
					callback(false)
				end
				return
			end

			-- Stop packages that are no longer in manifest
			local state = loadState()
			local validIds = {}
			if state.manifest and state.manifest.packages then
				for _, def in ipairs(state.manifest.packages) do
					validIds[def.id] = true
				end
			end

			-- Stop and remove instances for packages not in manifest
			for id, _ in pairs(runtime.instances) do
				if not validIds[id] then
					stopPackage(id)
				end
			end

			-- Restart enabled packages
			if state.manifest and state.manifest.packages then
				for _, def in ipairs(state.manifest.packages) do
					local flags = state.packages[def.id]
					if flags and flags.installed and flags.enabled then
						startPackage(def.id)
					end
				end
			end

			if manual then
				notify("Power Spoons", "Package list refreshed!")
			end

			if callback then
				callback(true)
			end
		end)
	end

	-- Menubar UI
	buildMenu = function()
		local state = loadState()
		local menu = {}

		table.insert(menu, {
			title = "Power Spoons – Package Manager",
			disabled = true,
		})
		table.insert(menu, { title = "-" })

		-- Installed section
		local anyInstalled = false
		if state.manifest and state.manifest.packages then
			for _, def in ipairs(state.manifest.packages) do
				local flags = state.packages[def.id]
				if flags and flags.installed then
					if not anyInstalled then
						table.insert(menu, {
							title = "Installed",
							disabled = true,
						})
						anyInstalled = true
					end

					local status = ""
					if flags.enabled then
						status = " (enabled)"
					else
						status = " (disabled)"
					end

					local installedVersion = flags.version or "unknown"
					local latestVersion = def.version or "unknown"
					local updateAvailable = flags.installed
						and def.version
						and flags.version
						and def.version ~= flags.version
					if updateAvailable then
						status = status .. " – update available"
					end

					local submenu = {
						{
							title = flags.enabled and "Disable" or "Enable",
							fn = function()
								togglePackageEnabled(def.id)
								if runtime.menubar then
									runtime.menubar:setMenu(buildMenu())
								end
							end,
						},
					}

					if updateAvailable then
						table.insert(submenu, {
							title = "Update to " .. latestVersion,
							fn = function()
								updatePackage(def.id, function()
									if runtime.menubar then
										runtime.menubar:setMenu(buildMenu())
									end
								end)
							end,
						})
					end

					table.insert(submenu, {
						title = "Uninstall…",
						fn = function()
							uninstallPackage(def.id)
							if runtime.menubar then
								runtime.menubar:setMenu(buildMenu())
							end
						end,
					})
					table.insert(submenu, { title = "-" })
					table.insert(submenu, {
						title = def.description or "",
						disabled = true,
					})
					table.insert(submenu, {
						title = "Installed version: " .. installedVersion,
						disabled = true,
					})
					table.insert(submenu, {
						title = "Latest version: " .. latestVersion,
						disabled = true,
					})

					-- Add README link if available
					if def.readme then
						table.insert(submenu, {
							title = "ℹ️  View README…",
							fn = function()
								hs.urlevent.openURL(def.readme)
							end,
						})
					end

					if def.hotkey then
						table.insert(submenu, {
							title = "Hotkey: " .. def.hotkey,
							disabled = true,
						})
					end

					-- Package-specific secrets
					if def.secrets and #def.secrets > 0 then
						table.insert(submenu, { title = "-" })
						table.insert(submenu, {
							title = "API Keys / Secrets",
							disabled = true,
						})

						for _, s in ipairs(def.secrets) do
							local val = M.getSecret(s.key)
							local masked = secretMask(val)
							local label = s.label or s.key
							local lineTitle = string.format("%s: %s", label, masked)

							table.insert(submenu, {
								title = lineTitle,
								menu = {
									{
										title = "Set / Update…",
										fn = function()
											openSecretPrompt(s)
											if runtime.menubar then
												runtime.menubar:setMenu(buildMenu())
											end
										end,
									},
									{
										title = "Clear",
										fn = function()
											M.setSecret(s.key, nil)
											if runtime.menubar then
												runtime.menubar:setMenu(buildMenu())
											end
										end,
									},
								},
							})
						end
					end

					-- Package-specific menu items
					local instance = runtime.instances[def.id]
					if instance and instance.getMenuItems then
						local menuItems = instance.getMenuItems()
						if menuItems and #menuItems > 0 then
							table.insert(submenu, { title = "-" })
							for _, item in ipairs(menuItems) do
								-- Wrap menu item functions to refresh menubar
								if item.fn then
									local originalFn = item.fn
									item.fn = function()
										originalFn()
										if runtime.menubar then
											runtime.menubar:setMenu(buildMenu())
										end
									end
								end
								-- Handle nested submenus
								if item.menu then
									for _, subitem in ipairs(item.menu) do
										if subitem.fn then
											local originalSubFn = subitem.fn
											subitem.fn = function()
												originalSubFn()
												if runtime.menubar then
													runtime.menubar:setMenu(buildMenu())
												end
											end
										end
									end
								end
								table.insert(submenu, item)
							end
						end
					end

					table.insert(menu, {
						title = def.name .. status,
						menu = submenu,
					})
				end
			end
		end

		if anyInstalled then
			table.insert(menu, { title = "-" })
		end

		-- Available section
		local anyAvailable = false
		if state.manifest and state.manifest.packages then
			for _, def in ipairs(state.manifest.packages) do
				local flags = state.packages[def.id]
				if not flags or not flags.installed then
					if not anyAvailable then
						table.insert(menu, {
							title = "Available",
							disabled = true,
						})
						anyAvailable = true
					end

					local availableSubmenu = {
						{
							title = "Install & Enable",
							fn = function()
								installPackage(def.id, function(success)
									if runtime.menubar then
										runtime.menubar:setMenu(buildMenu())
									end
								end)
							end,
						},
						{ title = "-" },
						{
							title = def.description or "",
							disabled = true,
						},
					}

					-- Add README link if available
					if def.readme then
						table.insert(availableSubmenu, {
							title = "ℹ️  View README…",
							fn = function()
								hs.urlevent.openURL(def.readme)
							end,
						})
					end

					table.insert(menu, {
						title = "+ " .. def.name,
						menu = availableSubmenu,
					})
				end
			end
		end

		if anyAvailable then
			table.insert(menu, { title = "-" })
		end

		-- System section
		table.insert(menu, {
			title = "Refresh package list",
			fn = function()
				refreshManifest(true, function()
					if runtime.menubar then
						runtime.menubar:setMenu(buildMenu())
					end
				end)
			end,
		})

		table.insert(menu, {
			title = "About Power Spoons…",
			fn = function()
				local stateAbout = loadState()
				local lastRefreshStr = "Never"
				if stateAbout.lastRefresh > 0 then
					lastRefreshStr = tostring(os.date("%Y-%m-%d %H:%M", stateAbout.lastRefresh))
				end

				hs.dialog.blockAlert(
					"Power Spoons",
					string.format(
						[[Power Spoons – Remote Package Manager

• Single menubar icon
• Install/enable/disable packages
• Manage API keys via UI
• Packages fetched from GitHub
• File-based configuration

Config: ~/.hammerspoon/powerspoons/
Last refresh: %s
Repository: github.com/m0hill/power-spoons]],
						lastRefreshStr
					),
					"OK"
				)
			end,
		})

		return menu
	end

	-- Manager init
	function M.init()
		-- Ensure directories exist
		ensurePowerSpoonsDir()

		-- Migrate from old hs.settings if needed
		migrateFromSettings()

		-- Create menubar item
		if not runtime.menubar then
			runtime.menubar = hs.menubar.new()
		end
		runtime.menubar:setTitle("⚡")
		runtime.menubar:setTooltip("Power Spoons – Package Manager")

		-- Load persistent state
		local state = loadState()

		-- Start enabled packages
		if state.manifest and state.manifest.packages then
			for _, def in ipairs(state.manifest.packages) do
				local flags = state.packages[def.id]
				if flags and flags.installed and flags.enabled then
					startPackage(def.id)
				end
			end
		end

		-- Build initial menu
		runtime.menubar:setMenu(buildMenu())

		-- Auto-refresh manifest if needed
		local now = os.time()
		if not state.manifest or (now - state.lastRefresh) > AUTO_REFRESH_INTERVAL then
			refreshManifest(false, function()
				if runtime.menubar then
					runtime.menubar:setMenu(buildMenu())
				end
			end)
		end
	end

	return M
end)()

-- Initialize Power Spoons on config load
PowerSpoons.init()
