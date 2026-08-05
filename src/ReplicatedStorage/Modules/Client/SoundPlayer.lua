--!strict
-- Plays a one-shot 2D (non-positional) sound effect from a SoundIds.lua
-- id, no-op'ing gracefully on an unconfigured ("") id instead of every
-- call site needing its own guard. pcall-wrapped: an invalid/moderated-
-- out asset id should never be able to error out whatever gameplay
-- moment it's attached to (matches AssetIds.lua's own "missing art
-- degrades gracefully" philosophy, applied to audio).

local SoundService = game:GetService("SoundService")

local SoundPlayer = {}

function SoundPlayer.play(soundId: string, volume: number?)
	if soundId == "" then
		return
	end
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = volume or 0.6
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		-- Ended won't fire if the asset never loads (bad/moderated id) —
		-- back this up with a hard timeout so a bad id can't leak Sound
		-- instances into SoundService forever.
		task.delay(10, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end)
end

return SoundPlayer
