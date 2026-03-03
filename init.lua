-- Voice Command: Right Cmd
-- Short press: toggle mode (press→speak→press→done)
-- Long press (3s+): hold mode (release to finish)

-- ============================================================
-- IMPORTANT: Tüm watcher ve timer'lar GLOBAL olmalı.
-- "local" olursa Lua GC bunları ~40 dk sonra öldürüyor.
-- ============================================================

-- === SELF-HEALING CONFIG ===
LOAD_TIME = hs.timer.secondsSinceEpoch()
LAST_ACTIVITY = LOAD_TIME
HEALTH_INTERVAL = 300        -- 5 dakikada bir health check
MIN_RELOAD_GAP = 600         -- reload'lar arası minimum 10 dakika
ACTIVITY_TIMEOUT = 600       -- 10 dk inaktifse reload yapma (kullanıcı yok)
HEARTBEAT_PATH = os.getenv("HOME") .. "/.hammerspoon/.heartbeat"

-- === VOICE STATE ===
recording = false
holdMode = false
recTask = nil
cmdTimer = nil
holdTimer = nil
sourceWindow = nil  -- kaydın başladığı pencere
tmpFile = "/tmp/voice-input.wav"
model = os.getenv("HOME") .. "/.local/share/whisper-cpp/ggml-medium.bin"

-- === OVERLAY UI ===
overlay = nil
tickTimer = nil
recordStart = 0

function getOverlayPosition(w, h)
    local ok, result = pcall(function()
        local win = hs.window.focusedWindow()
        if win then
            local f = win:frame()
            return {x = f.x + 10, y = f.y + f.h - h - 10}
        end
        return nil
    end)
    if ok and result then
        return result.x, result.y
    end
    local screen = hs.screen.mainScreen():frame()
    return 10, screen.h - h - 80
end

function createOverlay(mode)
    local ok, err = pcall(function()
        local w, h = 260, 44
        local x, y = getOverlayPosition(w, h)

        local appName = "?"
        if sourceWindow then
            pcall(function() appName = sourceWindow:application():name() end)
        end

        overlay = hs.canvas.new({x = x, y = y, w = w, h = h})
        overlay:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
        overlay:level(hs.canvas.windowLevels.overlay)

        overlay[1] = {
            type = "rectangle",
            roundedRectRadii = {xRadius = 12, yRadius = 12},
            fillColor = {red = 0.15, green = 0.15, blue = 0.15, alpha = 0.9},
            action = "fill"
        }
        overlay[2] = {
            type = "circle",
            center = {x = 20, y = h/2},
            radius = 6,
            fillColor = {red = 1, green = 0.2, blue = 0.2, alpha = 1},
            action = "fill"
        }
        overlay[3] = {
            type = "text",
            text = "0:00",
            textColor = {white = 1},
            textSize = 18,
            textFont = "Menlo",
            frame = {x = 35, y = (h-24)/2, w = 60, h = 24}
        }

        local modeText = mode == "hold" and "Hold · release" or "→ " .. appName
        overlay[4] = {
            type = "text",
            text = modeText,
            textColor = {white = 0.7},
            textSize = 11,
            frame = {x = 100, y = (h-16)/2, w = 170, h = 16}
        }

        overlay:show()
        recordStart = hs.timer.secondsSinceEpoch()

        tickTimer = hs.timer.doEvery(1, function()
            if overlay then
                pcall(function()
                    local elapsed = math.floor(hs.timer.secondsSinceEpoch() - recordStart)
                    overlay[3].text = string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60)
                end)
            end
        end)
    end)
    if not ok then
        print("[ERROR] Overlay: " .. tostring(err))
    end
end

function destroyOverlay()
    pcall(function()
        if tickTimer then tickTimer:stop(); tickTimer = nil end
        if overlay then overlay:delete(); overlay = nil end
    end)
end

function showStatus(msg, duration)
    pcall(function()
        local w, h = 260, 44
        local x, y = getOverlayPosition(w, h)

        local status = hs.canvas.new({x = x, y = y, w = w, h = h})
        status:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
        status:level(hs.canvas.windowLevels.overlay)
        status[1] = {
            type = "rectangle",
            roundedRectRadii = {xRadius = 12, yRadius = 12},
            fillColor = {red = 0.15, green = 0.15, blue = 0.15, alpha = 0.9},
            action = "fill"
        }
        status[2] = {
            type = "text",
            text = msg,
            textColor = {white = 1},
            textSize = 14,
            textAlignment = "center",
            frame = {x = 10, y = (h-20)/2, w = w-20, h = 20}
        }
        status:show()
        hs.timer.doAfter(duration, function() pcall(function() status:delete() end) end)
    end)
end

-- === CORE ===
function forceCleanup()
    recording = false
    holdMode = false
    destroyOverlay()
    if recTask then pcall(function() recTask:terminate() end); recTask = nil end
    if cmdTimer then cmdTimer:stop(); cmdTimer = nil end
    if holdTimer then holdTimer:stop(); holdTimer = nil end
    os.execute("pkill -f 'rec.*voice-input' 2>/dev/null")
end

function startRecording(mode)
    forceCleanup()
    recording = true
    sourceWindow = hs.window.focusedWindow()  -- kaydın başladığı pencereyi hatırla
    recTask = hs.task.new("/opt/homebrew/bin/rec", nil, {
        "-q", "-r", "16000", "-c", "1", "-b", "16", tmpFile
    })
    recTask:start()
    createOverlay(mode)
end

function stopAndTranscribe()
    if not recording then return end
    recording = false
    holdMode = false
    destroyOverlay()
    if recTask then pcall(function() recTask:terminate() end); recTask = nil end
    os.execute("pkill -f 'rec.*voice-input' 2>/dev/null")
    showStatus("Transcribing...", 30)

    hs.task.new("/opt/homebrew/bin/whisper-cli", function(exitCode, stdOut, stdErr)
        local result = (stdOut or ""):gsub("%[.*%]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if result ~= "" then
            hs.pasteboard.setContents(result)
            showStatus("Sending...", 2)
            hs.timer.doAfter(0.3, function()
                -- Kaydın başladığı pencereye geri dön
                if sourceWindow then
                    pcall(function() sourceWindow:focus() end)
                end
                hs.timer.doAfter(0.3, function()
                    hs.eventtap.keyStroke({"cmd"}, "v")
                    hs.timer.doAfter(0.5, function()
                        hs.eventtap.keyStroke({}, "return")
                        sourceWindow = nil
                        hs.timer.doAfter(1, function() hs.reload() end)
                    end)
                end)
            end)
        else
            showStatus("No speech detected", 2)
            hs.timer.doAfter(2, function() hs.reload() end)
        end
    end, {
        "-m", model, "-l", "tr", "-f", tmpFile, "--no-timestamps"
    }):start()
end

-- === INPUT (eventtap + aktivite takibi) ===
Watcher = hs.eventtap.new({hs.eventtap.event.types.flagsChanged, hs.eventtap.event.types.keyDown}, function(event)
    -- Her tuş basımı = kullanıcı aktif
    LAST_ACTIVITY = hs.timer.secondsSinceEpoch()

    local ok, err = pcall(function()
        local evType = event:getType()
        local flags = event:getRawEventData().CGEventData.flags

        if evType == hs.eventtap.event.types.keyDown then
            if cmdTimer then cmdTimer:stop(); cmdTimer = nil end
            return
        end

        local isRightCmd = (flags & 0x10) > 0

        if isRightCmd then
            if recording and not holdMode then
                stopAndTranscribe()
            else
                cmdTimer = hs.timer.doAfter(0.5, function()
                    cmdTimer = nil
                    startRecording("toggle")
                    holdTimer = hs.timer.doAfter(2.5, function()
                        holdTimer = nil
                        if recording then
                            holdMode = true
                            destroyOverlay()
                            createOverlay("hold")
                        end
                    end)
                end)
            end
        else
            if cmdTimer then cmdTimer:stop(); cmdTimer = nil end
            if holdTimer then holdTimer:stop(); holdTimer = nil end
            if recording and holdMode then
                stopAndTranscribe()
            end
        end
    end)
    if not ok then
        print("[ERROR] Watcher: " .. tostring(err))
        hs.timer.doAfter(1, function() hs.reload() end)
    end

    return false
end)
Watcher:start()

-- Escape to cancel recording (only intercepts when recording is active)
EscWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    if event:getKeyCode() == 53 and recording then -- 53 = escape
        holdMode = false
        forceCleanup()
        showStatus("Cancelled", 1)
        hs.timer.doAfter(1.5, function() hs.reload() end)
        return true -- consume the event
    end
    return false -- pass through to other apps
end)
EscWatcher:start()

-- === CONFIG FILE WATCHER ===
ConfigWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", function(files)
    for _, file in ipairs(files) do
        if file:match("%.lua$") then
            hs.reload()
            return
        end
    end
end)
ConfigWatcher:start()

-- === HEARTBEAT (harici watchdog için) ===
function writeHeartbeat()
    local f = io.open(HEARTBEAT_PATH, "w")
    if f then
        f:write(tostring(os.time()))
        f:close()
    end
end

HeartbeatTimer = hs.timer.new(30, function()
    writeHeartbeat()
end)
HeartbeatTimer:start()
writeHeartbeat() -- ilk heartbeat hemen yaz

-- === HEALTH CHECK (5 dk'da bir) ===
HealthTimer = hs.timer.new(HEALTH_INTERVAL, function()
    local now = hs.timer.secondsSinceEpoch()
    local sinceLoad = now - LOAD_TIME
    local sinceActivity = now - LAST_ACTIVITY

    -- GC çalıştır (memory leak önlemi)
    collectgarbage("collect")
    collectgarbage("collect")

    local luaMem = math.floor(collectgarbage("count"))
    print(string.format("[HEALTH] uptime=%.0fs idle=%.0fs lua=%dKB recording=%s watcher=%s",
        sinceLoad, sinceActivity, luaMem,
        tostring(recording), tostring(Watcher:isEnabled())))

    -- Watcher ölmüşse → acil reload
    if not Watcher:isEnabled() then
        print("[HEALTH] Watcher dead → reload")
        hs.reload()
        return
    end

    -- Kayıt aktifse → süresine bak
    if recording then
        -- Kaydın gerçek süresi 5 dk'yı geçtiyse → stuck, temizle
        local recordingDuration = now - recordStart
        if recordingDuration > 300 then
            print(string.format("[HEALTH] Stuck recording (duration=%.0fs) → cleanup", recordingDuration))
            forceCleanup()
            showStatus("Auto-recovered", 2)
        end
        return
    end

    -- Son reload'dan 10 dk geçmemişse → bekle
    if sinceLoad < MIN_RELOAD_GAP then
        return
    end

    -- Kullanıcı 10 dk'dır inaktifse → reload'a gerek yok (uzakta)
    if sinceActivity > ACTIVITY_TIMEOUT then
        return
    end

    -- Tüm koşullar tamam → reload
    print("[HEALTH] Active user, stale config → reload")
    hs.reload()
end)
HealthTimer:start()

-- === WAKE FROM SLEEP ===
SleepWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake then
        -- Uyku sonrası timer'lar güvenilmez → hepsini restart
        hs.timer.doAfter(3, function()
            if not recording then
                print("[WAKE] Reloading after sleep")
                hs.reload()
            end
        end)
    end
end)
SleepWatcher:start()

-- === STARTUP ===
showStatus("Voice ready (Right Cmd · Esc to cancel)", 2)
print(string.format("[BOOT] Hammerspoon loaded at %s", os.date("%H:%M:%S")))
