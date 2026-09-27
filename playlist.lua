-- ComputerCraft playlist player
-- Plays every .dfpwm file in a GitHub repo, one after another, forever.
-- Usage:  playlist          (plays in order)
--         playlist shuffle  (plays in random order)
-- Controls: Enter or Space = skip song, hold Ctrl+T = stop

local REPO = "GavinBenson/cc-music"

local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")
if not speaker then error("No speaker attached! Put one next to the computer.", 0) end

local shuffle = ({ ... })[1] == "shuffle"

-- Ask GitHub for the list of files in the repo
local function getSongs()
  local res, err = http.get("https://api.github.com/repos/" .. REPO .. "/contents/")
  if not res then error("Couldn't get song list: " .. tostring(err), 0) end
  local data = textutils.unserializeJSON(res.readAll())
  res.close()

  local songs = {}
  for _, file in ipairs(data or {}) do
    if file.name:match("%.dfpwm$") then
      table.insert(songs, {
        name = (file.name:gsub("%.dfpwm$", "")),
        url = file.download_url,
      })
    end
  end
  return songs
end

-- Download and play one song
local function playSong(song)
  local res, err = http.get(song.url, nil, true)
  if not res then
    print("Couldn't load this song: " .. tostring(err))
    sleep(2)
    return
  end

  local decoder = dfpwm.make_decoder()
  while true do
    local chunk = res.read(16 * 1024)
    if not chunk then break end
    local buffer = decoder(chunk)
    while not speaker.playAudio(buffer) do
      os.pullEvent("speaker_audio_empty")
    end
  end
  res.close()
  os.pullEvent("speaker_audio_empty") -- let the last bit finish
end

-- Wait for Enter or Space to skip
local function waitForSkip()
  while true do
    local _, key = os.pullEvent("key")
    if key == keys.enter or key == keys.space then return end
  end
end

local songs = getSongs()
if #songs == 0 then error("No .dfpwm files found in " .. REPO, 0) end

while true do
  if shuffle then
    for i = #songs, 2, -1 do
      local j = math.random(i)
      songs[i], songs[j] = songs[j], songs[i]
    end
  end

  for i, song in ipairs(songs) do
    term.clear()
    term.setCursorPos(1, 1)
    print(("Now playing (%d/%d):"):format(i, #songs))
    print(song.name)
    print()
    print("Enter/Space = skip")
    print("Hold Ctrl+T = stop")

    parallel.waitForAny(function() playSong(song) end, waitForSkip)
    speaker.stop()
  end
end
