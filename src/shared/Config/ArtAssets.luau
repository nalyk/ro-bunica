--!strict
-- GENERAT de tools/art.py — nu edita de mână.
-- Modelele din art/: asset-ul încărcat, culorile sloturilor (MeshPart-uri numite după slot),
-- conturul („ink”) și mărimea. Lipsa unei chei = jocul folosește forma procedurală.

export type Art = { assetId: number, palette: { [string]: Color3 }, ink: Color3?, size: Vector3 }

return table.freeze({} :: { [string]: Art })
