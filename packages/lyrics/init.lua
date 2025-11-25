return function(manager)
	local P = {}

	local PACKAGE_ID = "lyrics"
	local POLL_INTERVAL = 0.5
	local API_ENDPOINT = "https://lrclib.net/api/get"

	local pollTimer = nil
	local overlay = nil
	local currentTrackId = nil
	local currentTrackState = nil
	local lyricsState = nil
	local fetchToken = 0
	local dragContext = nil
	local dragEventTap = nil

	local function formatTime(seconds)
		if not seconds or seconds < 0 then
			return "--:--"
		end
		local rounded = math.floor(seconds + 0.5)
		local minutes = math.floor(rounded / 60)
		local secs = rounded % 60
		return string.format("%d:%02d", minutes, secs)
	end

	local function parseSyncedLyrics(raw)
		if type(raw) ~= "string" or raw == "" then
			return nil
		end

		local entries = {}
		for line in raw:gmatch("[^\r\n]+") do
			local stamps = {}
			for tag in line:gmatch("%[[^%]]+%]") do
				local m, s = tag:match("%[(%d+):(%d+%.?%d*)%]")
				if m and s then
					local total = tonumber(m) * 60 + tonumber(s)
					table.insert(stamps, total)
				end
			end

			local text = line:gsub("%[[^%]]+%]", "")
			text = text:gsub("^%s+", ""):gsub("%s+$", "")

			if #stamps > 0 then
				for _, ts in ipairs(stamps) do
					table.insert(entries, { time = ts, text = text })
				end
			end
		end

		if #entries == 0 then
			return nil
		end

		table.sort(entries, function(a, b)
			return a.time < b.time
		end)
		return entries
	end

	local function ensureOverlay()
		if overlay then
			return overlay
		end

		local frame = manager.getSetting(PACKAGE_ID, "overlay.frame")
		if not frame then
			local screen = hs.screen.mainScreen():frame()
			local width = math.min(600, math.floor(screen.w * 0.45))
			local height = 170
			frame = {
				x = screen.x + (screen.w - width) / 2,
				y = screen.y + screen.h - height - 120,
				w = width,
				h = height,
			}
		end

		overlay = hs.canvas.new(frame)
		overlay:level(hs.canvas.windowLevels.floating)
		overlay:alpha(0.97)
		overlay:clickActivating(false)
		overlay:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)

		overlay:appendElements({
			id = "background",
			type = "rectangle",
			action = "fill",
			fillColor = { white = 0.08, alpha = 0.65 },
			roundedRectRadii = { xRadius = 14, yRadius = 14 },
			trackMouseDown = true,
		}, {
			id = "info",
			type = "text",
			frame = { x = "5%", y = "6%", w = "90%", h = "18%" },
			text = "",
			textAlignment = "center",
			textColor = { white = 0.85 },
			textFont = "Helvetica Neue",
			textSize = 15,
			textLineBreak = "truncateTail",
		}, {
			id = "current",
			type = "text",
			frame = { x = "5%", y = "28%", w = "90%", h = "40%" },
			text = "",
			textAlignment = "center",
			textColor = { white = 1 },
			textFont = "Helvetica Neue Bold",
			textSize = 26,
			textLineBreak = "wordWrap",
		}, {
			id = "next",
			type = "text",
			frame = { x = "5%", y = "70%", w = "90%", h = "22%" },
			text = "",
			textAlignment = "center",
			textColor = { white = 0.7 },
			textFont = "Helvetica Neue",
			textSize = 18,
			textLineBreak = "truncateTail",
		})

		overlay:mouseCallback(function(canvas, message, elementId, x, y)
			if message == "mouseDown" and elementId == "background" then
				local mousePos = hs.mouse.absolutePosition()
				dragContext = {
					origin = mousePos,
					frameStart = canvas:frame(),
				}

				if dragEventTap then
					dragEventTap:stop()
				end

				dragEventTap = hs.eventtap
					.new({ hs.eventtap.event.types.leftMouseDragged, hs.eventtap.event.types.leftMouseUp }, function(event)
						if event:getType() == hs.eventtap.event.types.leftMouseDragged then
							if dragContext then
								local mousePos = hs.mouse.absolutePosition()
								local dx = mousePos.x - dragContext.origin.x
								local dy = mousePos.y - dragContext.origin.y
								local frame = dragContext.frameStart
								canvas:frame({
									x = frame.x + dx,
									y = frame.y + dy,
									w = frame.w,
									h = frame.h,
								})
							end
						elseif event:getType() == hs.eventtap.event.types.leftMouseUp then
							if dragContext then
								manager.setSetting(PACKAGE_ID, "overlay.frame", canvas:frame())
								dragContext = nil
							end
							if dragEventTap then
								dragEventTap:stop()
								dragEventTap = nil
							end
						end
						return false
					end)
					:start()
			end
		end)

		local visible = manager.getSetting(PACKAGE_ID, "overlay.visible", true)

		if visible then
			overlay:show()
		end

		return overlay
	end

	local function updateOverlayTexts(infoText, mainText, secondaryText)
		local canvas = ensureOverlay()
		canvas["info"].text = infoText or ""
		canvas["current"].text = mainText or ""
		canvas["next"].text = secondaryText or ""
	end

	local function getSpotifyState()
		local script = [[
set spotifyRunning to false
tell application "System Events"
    if (name of processes) contains "Spotify" then set spotifyRunning to true
end tell
if spotifyRunning then
    tell application "Spotify"
        set playerState to player state as string
        if playerState is "stopped" then
            return {playerState:playerState}
        end if
        set trackName to name of current track
        set trackArtist to artist of current track
        set trackAlbum to album of current track
        set trackDuration to duration of current track
        set trackPosition to player position
        return {playerState:playerState, trackName:trackName, trackArtist:trackArtist, trackAlbum:trackAlbum, trackDuration:trackDuration, trackPosition:trackPosition}
    end tell
else
    return {playerState:"not_running"}
end if
]]

		local ok, result = hs.osascript.applescript(script)
		if not ok then
			return { playerState = "error" }
		end

		if type(result) ~= "table" then
			return { playerState = "unknown" }
		end

		local state = {
			playerState = result.playerState or "unknown",
			name = result.trackName,
			artist = result.trackArtist,
			album = result.trackAlbum,
		}

		if result.trackDuration then
			local durationMs = tonumber(result.trackDuration)
			if durationMs and durationMs > 0 then
				state.duration = durationMs / 1000
			end
		end

		if result.trackPosition then
			local pos = tonumber(result.trackPosition)
			if pos and pos >= 0 then
				state.position = pos
			end
		end

		return state
	end

	local function determineTrackId(state)
		if not state or not state.name or not state.artist then
			return nil
		end
		return table.concat({ state.name, state.artist, state.album or "" }, "::")
	end

	local function computeLyricLines(position)
		if not lyricsState or not lyricsState.entries then
			return nil, nil
		end

		if not position then
			return lyricsState.entries[1], lyricsState.entries[2]
		end

		local currentEntry = nil
		for i = 1, #lyricsState.entries do
			local entry = lyricsState.entries[i]
			if position + 0.02 >= entry.time then
				currentEntry = entry
			else
				return currentEntry, lyricsState.entries[i]
			end
		end

		return currentEntry, nil
	end

	local function render(state)
		if not state then
			updateOverlayTexts("Spotify", "Waiting for playback data…", "")
			return
		end

		if state.playerState == "not_running" then
			lyricsState = nil
			currentTrackId = nil
			updateOverlayTexts("Spotify", "Spotify is not running", "")
			return
		end

		if state.playerState == "stopped" then
			lyricsState = nil
			currentTrackId = nil
			updateOverlayTexts("Spotify", "Playback stopped", "")
			return
		end

		if state.playerState == "error" then
			updateOverlayTexts("Spotify", "Unable to query Spotify", "")
			return
		end

		local trackLabel = ""
		if state.name and state.artist then
			trackLabel = string.format("%s — %s", state.name, state.artist)
		elseif state.name then
			trackLabel = state.name
		else
			trackLabel = "Spotify"
		end

		local statusLabel = state.playerState or ""
		if state.duration and state.position then
			trackLabel = string.format(
				"%s • %s %s / %s",
				trackLabel,
				statusLabel,
				formatTime(state.position),
				formatTime(state.duration)
			)
		elseif statusLabel ~= "" then
			trackLabel = string.format("%s • %s", trackLabel, statusLabel)
		end

		if lyricsState and lyricsState.loading then
			updateOverlayTexts(trackLabel, "Loading lyrics…", "")
			return
		end

		if lyricsState and lyricsState.error then
			updateOverlayTexts(trackLabel, lyricsState.error, "")
			return
		end

		local currentEntry, nextEntry = computeLyricLines(state.position)

		if currentEntry then
			local main = currentEntry.text ~= "" and currentEntry.text or "♪"
			local secondary = nextEntry and nextEntry.text or ""
			updateOverlayTexts(trackLabel, main, secondary)
		elseif nextEntry then
			updateOverlayTexts(trackLabel, "", nextEntry.text)
		else
			updateOverlayTexts(trackLabel, "Lyrics not ready", "")
		end
	end

	local function handleLyricsResponse(state, requestId, status, body)
		if requestId ~= fetchToken then
			return
		end

		if status ~= 200 or not body or body == "" then
			lyricsState = { error = "Lyrics unavailable" }
			render(currentTrackState or state)
			return
		end

		local ok, payload = pcall(hs.json.decode, body)
		if not ok or type(payload) ~= "table" then
			lyricsState = { error = "Lyrics unavailable" }
			render(currentTrackState or state)
			return
		end

		local entries = parseSyncedLyrics(payload.syncedLyrics)
		if not entries or #entries == 0 then
			lyricsState = { error = "No synced lyrics found" }
			render(currentTrackState or state)
			return
		end

		lyricsState = { entries = entries }
		render(currentTrackState or state)
	end

	local function fetchLyrics(state)
		if not state or not state.name or not state.artist then
			lyricsState = { error = "Missing track info" }
			render(state)
			return
		end

		lyricsState = { loading = true }
		render(state)

		fetchToken = fetchToken + 1
		local requestId = fetchToken

		local params = {
			"track_name=" .. hs.http.encodeForQuery(state.name),
			"artist_name=" .. hs.http.encodeForQuery(state.artist),
		}

		local url = string.format("%s?%s", API_ENDPOINT, table.concat(params, "&"))

		hs.http.asyncGet(url, nil, function(status, body)
			handleLyricsResponse(state, requestId, status, body)
		end)
	end

	local function tick()
		local state = getSpotifyState()
		currentTrackState = state

		local newTrackId = determineTrackId(state)

		if newTrackId ~= currentTrackId then
			currentTrackId = newTrackId
			lyricsState = nil
			if newTrackId then
				fetchLyrics(state)
			end
		end

		render(state)
	end

	function P.start()
		if not pollTimer then
			pollTimer = hs.timer.doEvery(POLL_INTERVAL, tick)
			tick()
		end
	end

	function P.stop()
		if pollTimer then
			pollTimer:stop()
			pollTimer = nil
		end
		if dragEventTap then
			dragEventTap:stop()
			dragEventTap = nil
		end
		if overlay then
			overlay:delete()
			overlay = nil
		end
		currentTrackId = nil
		lyricsState = nil
		dragContext = nil
	end

	function P.toggleVisibility()
		local visible = manager.getSetting(PACKAGE_ID, "overlay.visible", true)
		local newVisible = not visible
		manager.setSetting(PACKAGE_ID, "overlay.visible", newVisible)

		if overlay then
			if newVisible then
				overlay:show()
			else
				overlay:hide()
			end
		end
	end

	function P.isVisible()
		return manager.getSetting(PACKAGE_ID, "overlay.visible", true)
	end

	function P.getMenuItems()
		return {
			{
				title = (P.isVisible() and "Hide" or "Show") .. " Overlay",
				fn = function()
					P.toggleVisibility()
				end,
			},
		}
	end

	return P
end
