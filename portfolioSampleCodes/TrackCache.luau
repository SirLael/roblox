--!strict
-- @Big_Honor | sirlael

--========================
-- State
--========================
local TrackCache: { [Animator]: {[number]: AnimationTrack} } = {}
local TrackCacheHandler: { [string]: any} = {}
TrackCacheHandler._cache = TrackCache

--========================
-- Public API
--========================
function TrackCacheHandler:GetTrack(animator : Animator, animationId : number)
	if not TrackCache[animator] then
		TrackCache[animator] = {}

		animator.AncestryChanged:Connect(function(_, parent)
			if not parent then
				TrackCache[animator] = nil
			end
		end)
	end

	local cache = TrackCache[animator]

	if cache[animationId] then
		return cache[animationId]
	end

	local anim = Instance.new("Animation")
	anim.Name = tostring(animationId)

	local animId = tostring(animationId):gsub("rbxassetid://", "")
	anim.AnimationId = "rbxassetid://" .. animId

	local track = animator:LoadAnimation(anim)
	cache[animationId] = track

	return track
end

function TrackCacheHandler:ClearAnimator(animator : Animator)
	TrackCache[animator] = nil
end

return TrackCacheHandler
