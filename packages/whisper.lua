-- Whisper Transcription Package
-- Version: 1.0.0
-- Description: Hold Option+/ to record and auto-paste transcription via Groq Whisper

return function(manager)
	local P = {}

	local CONFIG = {
		MODEL = "whisper-large-v3-turbo",
		SAMPLE_RATE = 16000,
		MIN_BYTES = 1000,
		MAX_HOLD_SECONDS = 300,
		API_TIMEOUT = 90,
		HOTKEY_MODS = { "alt" },
		HOTKEY_KEY = "/",
		ENABLE_NOTIFY = true,
		ENABLE_SOUND = true,
	}

	local API_URL = "https://api.groq.com/openai/v1/audio/transcriptions"

	-- Runtime vars
	local rec_path = nil
	local is_recording = false
	local is_busy = false
	local rec_task = nil
	local stop_timer = nil
	local wav_path = nil
	local hotkey = nil

	local function notify(title, text)
		if not CONFIG.ENABLE_NOTIFY then
			return
		end
		hs.notify
			.new({
				title = title,
				informativeText = text or "",
				withdrawAfter = 3,
			})
			:send()
	end

	local function playSound(type)
		if not CONFIG.ENABLE_SOUND then
			return
		end
		local sounds = {
			start = "Ping",
			stop = "Purr",
			error = "Basso",
			success = "Glass",
		}
		if sounds[type] then
			hs.sound.getByName(sounds[type]):play()
		end
	end

	local function which(cmd)
		local out = hs.execute("command -v " .. cmd)
		out = (out or ""):gsub("%s+$", "")
		if out ~= "" then
			return out
		end

		local fallbacks = {
			"/opt/homebrew/bin/" .. cmd,
			"/usr/local/bin/" .. cmd,
			"/usr/bin/" .. cmd,
		}

		for _, p in ipairs(fallbacks) do
			if hs.fs.attributes(p, "mode") then
				return p
			end
		end

		return nil
	end

	local function tmpWavPath()
		local dir = os.getenv("TMPDIR") or "/tmp/"
		local name = string.format(
			"powerspoons-whisper-%d-%d.wav",
			os.time(),
			math.random(1000, 9999)
		)
		return dir .. name
	end

	local function cleanupRecordingRuntime()
		if rec_task and rec_task:isRunning() then
			rec_task:terminate()
		end
		rec_task = nil

		if stop_timer then
			stop_timer:stop()
			stop_timer = nil
		end

		is_recording = false
	end

	local function transcribeAudio(path)
		local apiKey = manager.getSecret("GROQ_API_KEY")
		if not apiKey or apiKey == "" then
			notify(
				"Whisper",
				"Missing Groq API key.\nSet it via Power Spoons → Secrets."
			)
			if path then
				os.remove(path)
			end
			return
		end

		local attrs = path and hs.fs.attributes(path)
		if not attrs or (attrs.size or 0) < CONFIG.MIN_BYTES then
			if path then
				os.remove(path)
			end
			notify("Whisper", "Recording too short. Please speak longer.")
			return
		end

		is_busy = true

		local args = {
			"-sS",
			"-m",
			tostring(CONFIG.API_TIMEOUT),
			"-H",
			"Authorization: Bearer " .. apiKey,
			"-F",
			"file=@" .. path .. ";type=audio/wav",
			"-F",
			"model=" .. CONFIG.MODEL,
			"-F",
			"response_format=json",
			API_URL,
		}

		local curl = hs.task.new("/usr/bin/curl", function(exitCode, out, err)
			is_busy = false
			if path then
				os.remove(path)
			end
			wav_path = nil

			out = (out or ""):gsub("%s+$", "")

			if exitCode ~= 0 then
				notify("Whisper", "Network error while calling API.")
				playSound("error")
				return
			end

			local ok, body = pcall(hs.json.decode, out or "")
			if not ok or not body then
				notify("Whisper", "Invalid API response.")
				playSound("error")
				return
			end

			if body.error then
				local msg = body.error.message or "Unknown API error"
				notify("Whisper", "Transcription error: " .. msg)
				playSound("error")
				return
			end

			local text = (body.text or ""):gsub("^%s+", ""):gsub("%s+$", "")
			if text == "" then
				notify("Whisper", "No speech detected in audio.")
				return
			end

			hs.pasteboard.setContents(text)
			hs.eventtap.keyStroke({ "cmd" }, "v", 0)

			local preview = '"' .. (text:len() > 60 and text:sub(1, 57) .. "..." or text) .. '"'
			notify("Whisper", "Transcribed: " .. preview)
			playSound("success")
		end, args)

		curl:start()
	end

	local function stopRecordingAndTranscribe()
		if not is_recording then
			return
		end

		cleanupRecordingRuntime()
		playSound("stop")

		local path = wav_path
		wav_path = nil

		if not path then
			notify("Whisper", "No recording captured.")
			return
		end

		transcribeAudio(path)
	end

	local function startRecording()
		if is_busy then
			notify(
				"Whisper",
				"Currently transcribing. Wait for it to finish."
			)
			return
		end
		if is_recording then
			notify("Whisper", "Already recording.")
			return
		end

		if not rec_path then
			rec_path = which("rec")
			if not rec_path then
				notify(
					"Whisper",
					"'sox' is not installed.\nInstall via: brew install sox"
				)
				return
			end
		end

		wav_path = tmpWavPath()
		is_recording = true

		rec_task = hs.task.new(rec_path, function(exitCode, out, err)
			stopRecordingAndTranscribe()
		end, {
			"-q",
			"-c",
			"1",
			"-r",
			tostring(CONFIG.SAMPLE_RATE),
			wav_path,
		})

		if not rec_task:start() then
			is_recording = false
			wav_path = nil
			notify("Whisper", "Could not start audio recording.")
			playSound("error")
			return
		end

		stop_timer = hs.timer.doAfter(
			CONFIG.MAX_HOLD_SECONDS,
			stopRecordingAndTranscribe
		)

		notify(
			"Whisper",
			"Recording… release "
				.. table.concat(CONFIG.HOTKEY_MODS, "+")
				.. "+"
				.. CONFIG.HOTKEY_KEY
				.. " to transcribe."
		)
		playSound("start")
	end

	function P.start()
		if hotkey then
			hotkey:delete()
			hotkey = nil
		end
		hotkey = hs.hotkey.bind(
			CONFIG.HOTKEY_MODS,
			CONFIG.HOTKEY_KEY,
			startRecording,
			stopRecordingAndTranscribe
		)
	end

	function P.stop()
		if hotkey then
			hotkey:delete()
			hotkey = nil
		end
		cleanupRecordingRuntime()
		if wav_path then
			os.remove(wav_path)
			wav_path = nil
		end
		is_busy = false
	end

	function P.getStatus()
		if is_busy then
			return "Transcribing…"
		elseif is_recording then
			return "Recording…"
		else
			return "Ready"
		end
	end

	return P
end
