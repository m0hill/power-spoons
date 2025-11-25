return function(manager)
	local P = {}

	local CONFIG = {
		HOTKEY_MODS = { "cmd", "shift" },
		HOTKEY_KEY = "s",
		MODEL = "gemini-flash-lite-latest",
		MIME_TYPE = "image/png",
		PROMPT = table.concat({
			"Extract all text from this image. If the text is in a non-english language, translate it to English.",
			"Format it in a clear, organized way with proper spacing and line breaks.",
			"Use only these symbols: hyphens (-), commas (,), numbers (1, 2, 3), and spaces for indentation.",
			"When separating information, use a hyphen (-) or comma (,) or space or new line (whatever is appropriate).",
			"Do not use bullets or bullet symbols like •. Do not use asterisks.",
			"Put your entire answer inside a code block using three backticks (```).",
		}, " "),
		SCREENSHOT_TIMEOUT = 60,
		ENABLE_NOTIFY = true,
		ENABLE_SOUND = true,
	}

	local state = {
		captureTask = nil,
		busy = false,
		timer = nil,
		hotkey = nil,
	}

	local function playSound(type)
		if not CONFIG.ENABLE_SOUND then
			return
		end
		local sounds = {
			capture = "Tink",
			process = "Purr",
			success = "Glass",
			error = "Basso",
			cancel = "Funk",
		}
		if sounds[type] then
			hs.sound.getByName(sounds[type]):play()
		end
	end

	local function notify(title, text)
		if not CONFIG.ENABLE_NOTIFY then
			return
		end
		hs.notify.new({ title = title, informativeText = text or "", withdrawAfter = 4 }):send()
	end

	local function cleanUp(path)
		if path and hs.fs.attributes(path) then
			os.remove(path)
		end
	end

	local function reset(path)
		state.busy = false
		if state.captureTask then
			state.captureTask = nil
		end
		if state.timer then
			state.timer:stop()
			state.timer = nil
		end
		cleanUp(path)
	end

	local function extractTextFromResponse(body)
		if type(body) ~= "table" then
			return nil
		end

		local candidates = body.candidates
		if type(candidates) ~= "table" then
			return nil
		end

		for _, candidate in ipairs(candidates) do
			local content = candidate.content
			if type(content) == "table" then
				local parts = content.parts
				if type(parts) == "table" then
					for _, part in ipairs(parts) do
						if type(part.text) == "string" and part.text ~= "" then
							return part.text
						end
					end
				end
			end
		end

		return nil
	end

	local function postToGemini(path)
		local attrs = hs.fs.attributes(path)
		if not attrs or attrs.size == 0 then
			reset(path)
			notify("Gemini OCR", "No screenshot captured")
			playSound("cancel")
			return
		end

		local apiKey = manager.getSecret("GEMINI_API_KEY")
		if not apiKey or apiKey == "" then
			reset(path)
			notify("Gemini OCR", "GEMINI_API_KEY is missing")
			playSound("error")
			return
		end

		local file = io.open(path, "rb")
		if not file then
			reset(path)
			notify("Gemini OCR", "Unable to read screenshot")
			playSound("error")
			return
		end

		local bytes = file:read("*all")
		file:close()

		local encoded = hs.base64.encode(bytes, false)
		local payload = {
			contents = {
				{
					parts = {
						{
							inline_data = {
								mime_type = CONFIG.MIME_TYPE,
								data = encoded,
							},
						},
						{
							text = CONFIG.PROMPT,
						},
					},
				},
			},
		}

		local body = hs.json.encode(payload)
		local headers = {
			["Content-Type"] = "application/json",
			["x-goog-api-key"] = apiKey,
		}

		local apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/" .. CONFIG.MODEL .. ":generateContent"

		playSound("process")

		hs.http.asyncPost(apiUrl, body, headers, function(status, responseData, responseHeaders)
			local resultText = nil
			if status == 200 and type(responseData) == "string" then
				local ok, decoded = pcall(hs.json.decode, responseData)
				if ok then
					resultText = extractTextFromResponse(decoded)
				end
			end

			if not resultText or resultText == "" then
				reset(path)
				notify("Gemini OCR", "Failed to interpret API response")
				playSound("error")
				return
			end

			local cleaned = resultText:gsub("^```[%w]*\n?", ""):gsub("\n?```$", "")

			hs.pasteboard.setContents(cleaned)

			local preview = cleaned
			if #preview > 150 then
				preview = preview:sub(1, 147) .. "..."
			end

			notify("Gemini OCR", preview)
			playSound("success")
			reset(path)
		end)
	end

	local function startCapture()
		if state.busy then
			notify("Gemini OCR", "Please wait for the previous request")
			return
		end

		local tmpDir = hs.fs.temporaryDirectory()
		local tmpPath = tmpDir .. string.format("powerspoons_gemini_%d.png", hs.timer.absoluteTime())
		state.busy = true

		state.timer = hs.timer.doAfter(CONFIG.SCREENSHOT_TIMEOUT, function()
			if state.captureTask then
				state.captureTask:terminate()
			end
			reset(tmpPath)
			notify("Gemini OCR", "Screenshot timed out")
		end)

		state.captureTask = hs.task.new("/usr/sbin/screencapture", function(exitCode)
			if exitCode ~= 0 then
				reset(tmpPath)
				notify("Gemini OCR", "Capture cancelled")
				playSound("cancel")
				return
			end

			if state.timer then
				state.timer:stop()
				state.timer = nil
			end

			playSound("capture")
			postToGemini(tmpPath)
		end, { "-i", "-o", "-x", "-t", "png", tmpPath })

		if not state.captureTask:start() then
			reset(tmpPath)
			notify("Gemini OCR", "Unable to start screenshot")
			playSound("error")
			return
		end
	end

	function P.start()
		if state.hotkey then
			state.hotkey:delete()
			state.hotkey = nil
		end
		state.hotkey = hs.hotkey.bind(CONFIG.HOTKEY_MODS, CONFIG.HOTKEY_KEY, startCapture)
	end

	function P.stop()
		if state.hotkey then
			state.hotkey:delete()
			state.hotkey = nil
		end
		if state.captureTask then
			state.captureTask:terminate()
			state.captureTask = nil
		end
		if state.timer then
			state.timer:stop()
			state.timer = nil
		end
		state.busy = false
	end

	function P.getStatus()
		return state.busy and "Processing…" or "Ready"
	end

	return P
end
