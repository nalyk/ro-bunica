"""Partitura satului: melodii originale în stil moldovenesc (mod „românesc minor”: D E F G# A B C).

Totul e date: (start în optimi, instrument, notă MIDI, durată în optimi, intensitate).
Aceeași partitură o cântă interpretul din joc (Luau) și randarea de previzualizare (Python).
Bucla are 16 măsuri de 2/4 = 64 de optimi. Straturile au aceeași grilă, deci se pot suprapune.
"""

LOOP = 64  # optimi

# Melodia „Hora din ogradă” (originală). Fiecare măsură: listă de (notă, optimi).
A1 = [[(69, 1), (69, 1), (71, 1), (72, 1)], [(74, 1), (72, 1), (71, 1), (69, 1)],
      [(68, 1), (69, 1), (71, 1), (68, 1)], [(69, 2), (64, 2)]]
A2 = [[(65, 1), (68, 1), (69, 1), (71, 1)], [(72, 1), (71, 1), (69, 1), (68, 1)],
      [(69, 1), (65, 1), (64, 1), (65, 1)], [(62, 4)]]
B1 = [[(74, 1), (74, 1), (76, 1), (77, 1)], [(76, 1), (74, 1), (72, 1), (74, 1)],
      [(76, 1), (77, 1), (80, 1), (77, 1)], [(76, 2), (72, 2)]]
B2 = [[(74, 1), (72, 1), (71, 1), (72, 1)], [(69, 1), (71, 1), (68, 1), (69, 1)],
      [(65, 1), (64, 1), (65, 1), (68, 1)], [(62, 4)]]
MELODY = A1 + A2 + B1 + B2

# Armonia pe măsură: (fundamentală la bas, cvinta la bas, acord la cobză)
DM = (38, 33, (50, 53, 57))
E = (40, 35, (52, 56, 59))
AM = (45, 40, (52, 57, 60))
HARMONY = [DM, DM, E, DM, DM, E, DM, DM, DM, AM, E, AM, DM, E, DM, DM]

# Scara pentru ornamente („lăutarul improvizează”)
SCALE = [62, 64, 65, 68, 69, 71, 72, 74, 76, 77, 80, 81, 83, 84, 86]


def melody_events(instrument, octave=0, vel=0.9):
    ev, t = [], 0
    for bar in MELODY:
        for note, d in bar:
            ev.append((t, instrument, note + 12 * octave, d, vel))
            t += d
    return ev


def oompah(bass_vel=0.9, chord_vel=0.55, chord_instr="cobza"):
    ev = []
    for b, (root, fifth, chord) in enumerate(HARMONY):
        t = b * 4
        ev.append((t, "bass", root, 1, bass_vel))
        ev.append((t + 2, "bass", fifth, 1, bass_vel * 0.8))
        for k, n in enumerate(chord):  # strum: notele acordului ușor decalate (în interpret)
            ev.append((t + 1, chord_instr, n, 1, chord_vel))
            ev.append((t + 3, chord_instr, n, 1, chord_vel * 0.85))
    return ev


def tipatura(vel=0.5):
    """„Țâpătura”: acord scurt de acordeon pe contratimp (mâna stângă a acordeonistului)."""
    return [(b * 4 + k, "acc_chord", n, 1, vel) for b, (_, _, chord) in enumerate(HARMONY)
            for k in (1, 3) for n in chord]


def layer_zi():
    """Ziua: vioara cântă hora, acordeonul face țâpătura, cobza și basul țin ritmul."""
    ev = oompah(chord_vel=0.35) + tipatura()
    ev += [(b * 4, "doba", 0, 1, 0.5) for b in range(16)]
    return ev


def layer_noapte():
    """Noaptea: naiul cântă melodia rar, basul ține un pedal pe Re."""
    ev = []
    ev += [(b * 8, "bass", 38, 4, 0.5) for b in range(8)]
    ev += [(b * 4 + 3, "tambal", h, 1, 0.18) for b, (_, _, chord) in enumerate(HARMONY) for h in chord[2:]]
    return ev


def layer_pericol():
    """Hoțul e în ogradă: pizzicato care se furișează și toaca de lemn pe contratimp."""
    sneak = [38, 38, 41, 38, 44, 45, 44, 41]
    ev = [(i, "bass", sneak[i % 8], 1, 0.75) for i in range(0, LOOP)]
    ev += [(i, "lemn", 0, 1, 0.35) for i in range(1, LOOP, 2)]
    ev += [(b * 8 + 6, "tambal", 80, 1, 0.3) for b in range(8)]
    return ev


def layer_urmarire():
    """Urmărirea: sârbă dublă — doba în șaisprezecimi (aici: optimi accentuate), rulade de țambal."""
    ev = [(i, "doba", 1, 1, 0.8 if i % 2 == 0 else 0.45) for i in range(LOOP)]
    ev += [(b * 4, "tambal_roll", chord[2] + 12, 2, 0.5) for b, (_, _, chord) in enumerate(HARMONY)]
    return ev


def layer_hora():
    """Hora (ritualul): toată taraful — țambal cântă melodia, acordeonul o dublează, doba plină."""
    ev = melody_events("tambal", octave=0, vel=0.55)
    ev += oompah(1.0, 0.45) + tipatura(0.6)
    ev += [(i, "doba", 1 if i % 4 == 0 else 2, 1, 0.8 if i % 2 == 0 else 0.4) for i in range(LOOP)]
    return ev


LAYERS = {
    "zi": layer_zi,
    "noapte": layer_noapte,
    "pericol": layer_pericol,
    "urmarire": layer_urmarire,
    "hora": layer_hora,
}


def melody_notes(octave=0, sparse=False):
    """Melodia ca listă (notă, optimi) pentru randarea frazată. `sparse`: doar notele de pe timp (noaptea)."""
    out, t = [], 0
    for bar in MELODY:
        for note, d in bar:
            if sparse and t % 2 == 1:
                out[-1] = (out[-1][0], out[-1][1] + d)
            else:
                out.append((note + 12 * octave, d))
            t += d
    return out


# Vocea principală a fiecărui strat: (instrument frazat, octavă, rar, intensitate)
LEADS = {
    "zi": [("vioara", 0, False, 0.9)],
    "noapte": [("nai", 1, True, 0.7)],
    "pericol": [],
    "urmarire": [("vioara", 1, False, 0.75)],
    "hora": [("vioara", 0, False, 1.0), ("acordeon", -1, False, 0.55)],
}
