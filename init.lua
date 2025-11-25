-- Power Spoons – Remote Package Manager for Hammerspoon
-- Paste this into your ~/.hammerspoon/init.lua and reload config.

local PowerSpoons = (function()
	-- Configuration
	local MANIFEST_URL = "https://raw.githubusercontent.com/m0hill/power-spoons/main/manifest.json"
	local SETTINGS_KEY = "powerspoons.state"
	local CACHE_DIR = os.getenv("HOME") .. "/.hammerspoon/powerspoons_cache"
	local AUTO_REFRESH_INTERVAL = 24 * 60 * 60 -- 24 hours

	-- Manager state
	local M = {}

	local state = {
		menubar = nil,
		packages = {}, -- [id] = { def=manifest_entry, installed=bool, enabled=bool, code=string|nil, instance=obj|nil }
		secrets = {}, -- [key] = string
		manifest = nil,
		lastRefresh = 0,
	}

	-- Helpers
	local function ensureCacheDir()
		local attrs = hs.fs.attributes(CACHE_DIR)
		if not attrs then
			hs.fs.mkdir(CACHE_DIR)
		end
	end

	local function getCacheFilePath(packageId)
		return CACHE_DIR .. "/" .. packageId .. ".lua"
	end

	local function notify(title, text)
		hs.notify
			.new({
				title = title,
				informativeText = text or "",
				withdrawAfter = 3,
			})
			:send()
	end

	-- Persistence (settings + secrets)
	local function loadPersistedState()
		local persisted = hs.settings.get(SETTINGS_KEY)
		if type(persisted) ~= "table" then
			persisted = {}
		end
		if type(persisted.packages) ~= "table" then
			persisted.packages = {}
		end
		if type(persisted.secrets) ~= "table" then
			persisted.secrets = {}
		end
		if type(persisted.manifest) ~= "table" then
			persisted.manifest = nil
		end

		state.secrets = persisted.secrets
		state.lastRefresh = persisted.lastRefresh or 0

		return persisted.packages, persisted.manifest
	end

	local function savePersistedState()
		local persistedPackages = {}
		for id, pkg in pairs(state.packages) do
			persistedPackages[id] = {
				installed = pkg.installed and true or false,
				enabled = pkg.enabled and true or false,
			}
		end

		hs.settings.set(SETTINGS_KEY, {
			packages = persistedPackages,
			secrets = state.secrets,
			manifest = state.manifest,
			lastRefresh = state.lastRefresh,
		})
	end

	-- Secrets API
	function M.getSecret(key)
		return state.secrets[key]
	end

	function M.setSecret(key, value)
		if value == nil or value == "" then
			state.secrets[key] = nil
		else
			state.secrets[key] = value
		end
		savePersistedState()
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

	local function openSecretPrompt(secretDef)
		local current = state.secrets[secretDef.key] or ""
		local button, text = hs.dialog.textPrompt(secretDef.label, secretDef.hint or "", current, "Save", "Cancel")
		if button == "Save" then
			if text and text ~= "" then
				M.setSecret(secretDef.key, text)
			else
				M.setSecret(secretDef.key, nil)
			end
		end
	end

	-- Package loading & execution
	local function loadPackageCode(packageId, code)
		-- Create a function from the code string
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
			callback(false, "No source URL specified")
			return
		end

		hs.http.asyncGet(url, nil, function(status, body, headers)
			if status ~= 200 then
				callback(false, "HTTP " .. tostring(status))
				return
			end

			if not body or body == "" then
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
			end

			callback(true, body)
		end)
	end

	-- Package lifecycle
	local function startPackage(id)
		local pkg = state.packages[id]
		if not pkg or not pkg.enabled then
			return
		end
		if pkg.instance then
			return -- Already running
		end

		if not pkg.code then
			-- Try to load from cache
			local cachePath = getCacheFilePath(id)
			local file = io.open(cachePath, "r")
			if file then
				pkg.code = file:read("*all")
				file:close()
			end
		end

		if not pkg.code then
			notify("Power Spoons", "Package '" .. id .. "' code not available. Try refreshing.")
			return
		end

		local instance, err = loadPackageCode(id, pkg.code)
		if not instance then
			notify("Power Spoons", "Failed to load package '" .. id .. "': " .. tostring(err))
			return
		end

		pkg.instance = instance

		if pkg.instance.start then
			local ok, errStart = pcall(pkg.instance.start)
			if not ok then
				notify("Power Spoons", "Failed to start package '" .. id .. "': " .. tostring(errStart))
			end
		end
	end

	local function stopPackage(id)
		local pkg = state.packages[id]
		if not pkg or not pkg.instance then
			return
		end
		if pkg.instance.stop then
			pcall(pkg.instance.stop)
		end
		pkg.instance = nil
	end

	local function installPackage(id, callback)
		local pkg = state.packages[id]
		if not pkg or not pkg.def then
			if callback then
				callback(false, "Package not found")
			end
			return
		end

		-- Download package code
		downloadPackage(pkg.def, function(success, bodyOrErr)
			if not success then
				notify("Power Spoons", "Failed to download '" .. id .. "': " .. tostring(bodyOrErr))
				if callback then
					callback(false, bodyOrErr)
				end
				return
			end

			pkg.code = bodyOrErr
			pkg.installed = true
			pkg.enabled = true

			savePersistedState()
			startPackage(id)

			notify("Power Spoons", "Installed: " .. pkg.def.name)

			if callback then
				callback(true)
			end
		end)
	end

	local function togglePackageEnabled(id)
		local pkg = state.packages[id]
		if not pkg then
			return
		end

		if not pkg.installed then
			-- Install it
			installPackage(id, function(success)
				if success and state.menubar then
					state.menubar:setMenu(buildMenu())
				end
			end)
			return
		end

		if pkg.enabled then
			pkg.enabled = false
			stopPackage(id)
		else
			pkg.enabled = true
			startPackage(id)
		end
		savePersistedState()
	end

	local function uninstallPackage(id)
		local pkg = state.packages[id]
		if not pkg then
			return
		end

		stopPackage(id)
		pkg.enabled = false
		pkg.installed = false
		pkg.code = nil

		-- Delete cached file
		local cachePath = getCacheFilePath(id)
		if hs.fs.attributes(cachePath) then
			os.remove(cachePath)
		end

		savePersistedState()
	end

	-- Manifest fetching
	local function fetchManifest(callback)
		hs.http.asyncGet(MANIFEST_URL, nil, function(status, body, headers)
			if status ~= 200 then
				if callback then
					callback(false, "HTTP " .. tostring(status))
				end
				return
			end

			local ok, manifest = pcall(hs.json.decode, body)
			if not ok or type(manifest) ~= "table" then
				if callback then
					callback(false, "Invalid manifest JSON")
				end
				return
			end

			state.manifest = manifest
			state.lastRefresh = os.time()
			savePersistedState()

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
				notify("Power Spoons", "Failed to refresh: " .. tostring(resultOrErr))
				if callback then
					callback(false)
				end
				return
			end

			-- Rebuild package state from new manifest
			local persistedPackages = {}
			for id, pkg in pairs(state.packages) do
				persistedPackages[id] = {
					installed = pkg.installed,
					enabled = pkg.enabled,
					code = pkg.code,
				}
			end

			state.packages = {}

			if state.manifest and state.manifest.packages then
				for _, pkgDef in ipairs(state.manifest.packages) do
					local persisted = persistedPackages[pkgDef.id] or {}

					state.packages[pkgDef.id] = {
						def = pkgDef,
						installed = persisted.installed or false,
						enabled = persisted.enabled or false,
						code = persisted.code,
						instance = nil,
					}
				end
			end

			savePersistedState()

			-- Restart enabled packages
			for id, pkg in pairs(state.packages) do
				if pkg.enabled and pkg.installed then
					startPackage(id)
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
	local function buildMenu()
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
				local pkg = state.packages[def.id]
				if pkg and pkg.installed then
					if not anyInstalled then
						table.insert(menu, {
							title = "Installed",
							disabled = true,
						})
						anyInstalled = true
					end

					local status = ""
					if pkg.enabled then
						status = " (enabled)"
					else
						status = " (disabled)"
					end

					local submenu = {
						{
							title = pkg.enabled and "Disable" or "Enable",
							fn = function()
								togglePackageEnabled(def.id)
								if state.menubar then
									state.menubar:setMenu(buildMenu())
								end
							end,
						},
						{
							title = "Uninstall…",
							fn = function()
								uninstallPackage(def.id)
								if state.menubar then
									state.menubar:setMenu(buildMenu())
								end
							end,
						},
						{ title = "-" },
						{
							title = def.description or "",
							disabled = true,
						},
						{
							title = "Version: " .. (def.version or "unknown"),
							disabled = true,
						},
					}

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

					-- Package-specific secrets (API keys) live inside this package submenu
					if def.secrets and #def.secrets > 0 then
						table.insert(submenu, { title = "-" })
						table.insert(submenu, {
							title = "API Keys / Secrets",
							disabled = true,
						})

						for _, s in ipairs(def.secrets) do
							local val = state.secrets[s.key]
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
											if state.menubar then
												state.menubar:setMenu(buildMenu())
											end
										end,
									},
									{
										title = "Clear",
										fn = function()
											M.setSecret(s.key, nil)
											if state.menubar then
												state.menubar:setMenu(buildMenu())
											end
										end,
									},
								},
							})
						end
					end

					-- Standard interface for package-specific menu items
					if pkg.instance and pkg.instance.getMenuItems then
						local menuItems = pkg.instance.getMenuItems()
						if menuItems and #menuItems > 0 then
							table.insert(submenu, { title = "-" })
							for _, item in ipairs(menuItems) do
								-- Wrap menu item functions to refresh menubar
								if item.fn then
									local originalFn = item.fn
									item.fn = function()
										originalFn()
										if state.menubar then
											state.menubar:setMenu(buildMenu())
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
												if state.menubar then
													state.menubar:setMenu(buildMenu())
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
				local pkg = state.packages[def.id]
				if not pkg or not pkg.installed then
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
									if state.menubar then
										state.menubar:setMenu(buildMenu())
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

		-- Secrets are now managed per-package inside each package submenu.

		-- System section
		table.insert(menu, {
			title = "Refresh package list",
			fn = function()
				refreshManifest(true, function()
					if state.menubar then
						state.menubar:setMenu(buildMenu())
					end
				end)
			end,
		})

		table.insert(menu, {
			title = "About Power Spoons…",
			fn = function()
				local lastRefreshStr = "Never"
				if state.lastRefresh > 0 then
					lastRefreshStr = os.date("%Y-%m-%d %H:%M", state.lastRefresh)
				end

				hs.dialog.blockAlert(
					"Power Spoons",
					string.format(
						[[Power Spoons – Remote Package Manager

• Single menubar icon
• Install/enable/disable packages
• Manage API keys via UI
• Packages fetched from GitHub
• All state stored locally

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
		-- Ensure cache directory exists
		ensureCacheDir()

		-- Create menubar item
		if not state.menubar then
			state.menubar = hs.menubar.new()
		end
		state.menubar:setTitle("⚡")
		state.menubar:setTooltip("Power Spoons – Package Manager")

		-- Load persisted state
		local persistedPackages, persistedManifest = loadPersistedState()

		-- Use persisted manifest if available
		if persistedManifest then
			state.manifest = persistedManifest
		end

		-- Build runtime package table from manifest
		if state.manifest and state.manifest.packages then
			for _, pkgDef in ipairs(state.manifest.packages) do
				local persisted = persistedPackages[pkgDef.id] or {}

				state.packages[pkgDef.id] = {
					def = pkgDef,
					installed = persisted.installed or false,
					enabled = persisted.enabled or false,
					code = nil, -- Will be loaded on demand
					instance = nil,
				}

				-- Load code from cache if installed
				if persisted.installed then
					local cachePath = getCacheFilePath(pkgDef.id)
					local file = io.open(cachePath, "r")
					if file then
						state.packages[pkgDef.id].code = file:read("*all")
						file:close()
					end
				end
			end
		end

		-- Start enabled packages
		for id, pkg in pairs(state.packages) do
			if pkg.enabled and pkg.installed then
				startPackage(id)
			end
		end

		-- Build initial menu
		state.menubar:setMenu(buildMenu())

		-- Auto-refresh manifest if needed
		local now = os.time()
		if not state.manifest or (now - state.lastRefresh) > AUTO_REFRESH_INTERVAL then
			refreshManifest(false, function()
				if state.menubar then
					state.menubar:setMenu(buildMenu())
				end
			end)
		end

		print("[Power Spoons] Initialized. Click the ⚡ icon in the menubar to get started.")
	end

	return M
end)()

-- Initialize Power Spoons on config load
PowerSpoons.init()
