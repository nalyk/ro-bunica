--!strict
-- Evenimentele de progres ale jucătorilor (plantat, eclozat, furat, apărat…), pentru Caietul Bunicii.
-- Serviciile le emit fără să depindă de cine le ascultă (fără require circular).
-- `obtained` = o creatură a intrat în posesia jucătorului sau s-a schimbat (colecția o înregistrează).

export type Kind =
	"plant"
	| "hatch"
	| "buySeed"
	| "steal"
	| "defend"
	| "sell"
	| "hora"
	| "mutation"
	| "obtained"

type Listener = (owner: any, kind: Kind, amount: number, record: any?) -> ()

local Progress = {}

local listeners: { Listener } = {}

function Progress.emit(owner: any, kind: Kind, amount: number?, record: any?)
	if not owner or owner.kind ~= "Player" then
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
