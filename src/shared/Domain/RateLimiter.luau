--!strict
-- Limitare de rată tip „găleată cu jetoane”, pe cheie (de obicei UserId).

export type RateLimiter = {
	allow: (self: RateLimiter, key: any, now: number) -> boolean,
	forget: (self: RateLimiter, key: any) -> (),
}

local RateLimiter = {}

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	local buckets: { [any]: { tokens: number, at: number } } = {}
	local limiter = {}

	function limiter.allow(_self, key: any, now: number): boolean
		local bucket = buckets[key]
		if not bucket then
			bucket = { tokens = capacity, at = now }
			buckets[key] = bucket
		end
		local elapsed = math.max(now - bucket.at, 0)
		bucket.tokens = math.min(capacity, bucket.tokens + elapsed * refillPerSecond)
		bucket.at = now
		if bucket.tokens >= 1 then
			bucket.tokens -= 1
			return true
		end
		return false
	end

	function limiter.forget(_self, key: any)
		buckets[key] = nil
	end

	return (limiter :: any) :: RateLimiter
end

return RateLimiter
