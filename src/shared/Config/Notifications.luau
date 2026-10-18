--!strict
-- Notificările Roblox (Experience Notifications): șirurile de text sunt create în Creator Dashboard
-- (Engagement → Notifications); aici stau id-urile lor (asset id). Un id gol oprește tipul respectiv.

return {
	messages = {
		grown = "6216f26c-5f22-9f48-8128-85ad4a769d26", -- „Creaturile tale s-au copt în ogradă. Vino să le culegi până nu vin hoții!”
		saturday = "a503eb6f-f4dc-f644-9cb2-c5d7806a4481", -- „Sâmbăta în sat începe în 15 minute: tot satul e online!”
		bazaar = "0a8a18ec-7775-5f4e-af58-b5234ec86521", -- „Bazarul mare de duminică s-a deschis: 12 tarabe!”
	} :: { [string]: string },
	-- invitația către un prieten (ExperienceInviteOptions.InviteMessageId): „{displayName} needs help…”
	invite = "dbf6a3d2-47b7-ec4e-87bf-9f2e1008e35a",
	-- numele secretului (Creator Dashboard → Secrets) cu cheia Open Cloud care are user.user-notification:write
	secret = "notifications",
}
