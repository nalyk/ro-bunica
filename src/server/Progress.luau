--!strict
-- Evenimentele de progres ale jucătorilor (plantat, eclozat, furat, apărat…), pentru Caietul Bunicii.
-- Serviciile le emit fără să depindă de cine le ascultă (fără require circular).
-- `obtained` = o creatură a intrat în posesia jucătorului sau s-a schimbat (colecția o înregistrează).

export type Kind =
	"plant"
	| "hatch"
	| "buySeed"
	| "steal"
	| "decor" -- câte obiecte de decor sunt așezate (titlul „Gospodina”)
	| "fish" -- un pește prins
	| "minigame" -- un mini-joc terminat
	| "happening" -- o întâmplare a satului la care a participat
	| "defend"
	| "sell"
	| "hora"
	| "mutation"
	| "obtained"

type Listener = (owner: any, kind: Kind, amount: number, record: any?) -> ()

local Progress = {}

local listeners: { Listener } = {}

function Progress.emit(owner: any, kind: Kind, amount: number?, record: any?)
	-- jucătorii și boții care țin locul unui jucător (teste); vecinii NPC nu au progres
	if not owner or (owner.kind ~= "Player" and not owner.standIn) then
		return
	end
	for _, listener in listeners do
		task.spawn(listener, owner, kind, amount or 1, record)
	end
end

function Progress.on(listener: Listener)
	table.insert(listeners, listener)
end

return Progress
