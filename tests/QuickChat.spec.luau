local QuickChat = require(Shared.Config.QuickChat)
local Strings = require(Shared.Strings)

describe("QuickChat", function()
	it("are 12 mesaje", function()
		expect(#QuickChat.list).toBe(12)
	end)
	it("toate mesajele au text în cele 5 limbi", function()
		for _, message in QuickChat.list do
			for _, language in { "ro", "en", "ru", "es", "pt" } do
				expect(Strings.has(language, "quick." .. message.id)).toBe(true)
			end
		end
	end)
end)
