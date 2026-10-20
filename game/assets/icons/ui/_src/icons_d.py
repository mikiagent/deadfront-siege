from geo import *
EO = ' fill-rule="evenodd"'
I = {}
# hafted tools: handle is a 5 line; heads are solid; lashing is a short solid collar under the head.
# axe head drawn in haft-local space (haft along local -y), placed on the haft with one transform
AXE = '<g transform="translate(40 26) rotate(15)"><path d="M4 -6 L-9 -6.5 C-14 -8 -17.5 -11 -20 -15 C-25.5 -5 -25.5 5 -20 15 C-17.5 11 -14 8 -9 6.5 L4 6 Z"/></g>'


I["pick"] = {"l": ['<path d="M46 56 C46 44 42 36 34 30"/>'],
             "s": ['<path d="M39 34 C34 28 33 20 39 14 C44 20 46 27 39 34 Z"/>', '<path d="M36 41 C28 42 19 38 16 30 C24 28 32 31 36 41 Z"/>',
                   '<path%s d="%s M12.5 15.5 A3.5 3.5 0 0 1 16 12 V14.5 A1 1 0 0 0 15 15.5 Z"/>' % (EO, circ(15.5, 15.5, 7.5)), '<path d="%s"/>' % circ(26, 9, 5)]}


I["fish"] = {"s": ['<path%s d="M7 33 C13 21 28 16 40 22 L53 13 C51 20 50.5 26.5 51.5 33 C50.5 39.5 51 46 53 53 L40 44 C28 50 13 45 7 33 Z %s M26 22 C28 27 28 39 26 44 L23.5 43 C25.5 37 25.5 29 23.5 23 Z"/>' % (EO, circ(16, 29.5, 3.4))]}

HAMMER = '<g transform="translate(36.5 18.5) rotate(32.5)"><rect x="-14" y="-7.5" width="28" height="15" rx="6"/></g>'
I["craft"] = {"l": ['<path d="M14 55 L35 22"/>', '<path d="M54 34 L59 35 M49 40 L52 45 M44 43 L44 48"/>'], "s": [HAMMER]}

I["station_fire"] = {"l": ['<path d="M11 57 L53 47 M11 47 L53 57"/>'], "s": [g("translate(32 43) scale(1.45)", flame())]}

I["station_dryer"] = {"l": ['<path d="M13 56 V14 M51 56 V14 M7 15 H57"/>'],
                      "s": ['<path d="M21 18 H27 C28 26 25 31 27 38 L24 45 L21 38 C20 31 22.5 26 21 18 Z"/>', '<path d="M29 18 H35 C36 28 33 34 35 42 L32 50 L29 42 C28 34 30.5 28 29 18 Z"/>',
                            '<path d="M37 18 H43 C44 25 41 29 43 35 L40 41 L37 35 C36 29 38.5 25 37 18 Z"/>']}

I["station_pot"] = {"s": ['<path d="M13 31 H51 C51 45 43 55 32 55 C21 55 13 45 13 31 Z"/>', '<rect x="9" y="25" width="46" height="6.5" rx="3.25"/>',
                          '<path d="M14 22 C15 15 22 11.5 32 11.5 C42 11.5 49 15 50 22 Z"/>', '<path d="%s"/>' % circ(32, 8.5, 3.6),
                          '<path d="%s %s"/>' % (cap(6, 36, 12, 36, 6), cap(52, 36, 58, 36, 6))]}

I["station_mortar"] = {"s": ['<path d="M8 31 H56 C56 42 48 49.5 41 51 L43 57 H21 L23 51 C16 49.5 8 42 8 31 Z"/>', '<path d="%s"/>' % cap(32, 25, 47, 7, 8)]}

I["station_grill"] = {"l": ['<path d="M8 18 H56 M8 30 H56 M18 18 V30 M32 18 V30 M46 18 V30"/>'],
                      "s": [g("translate(20 57) scale(0.78)", flame(False)), g("translate(32 56) scale(0.95)", flame(False)), g("translate(44 57) scale(0.78)", flame(False))]}

I["station_steamer"] = {"l": ['<path d="M21 30 C16 25 26 20.5 21 14.5 C17 10 23 7 21 4 M32 30 C27 25 37 20.5 32 14.5 C28 10 34 7 32 4 M43 30 C38 25 48 20.5 43 14.5 C39 10 45 7 43 4"/>'],
                        "s": ['<path d="M7 38 C9 34 13 33 16 36 C17 41 23 44 32 44 C41 44 47 41 48 36 C51 33 55 34 57 38 C57 49 46 56 32 56 C18 56 7 49 7 38 Z"/>']}

I["station_well"] = {"l": ['<path d="M16 39 V13 M48 39 V13 M9 15 L32 6 L55 15 M32 11 V23"/>'],
                     "s": ['<path d="M26.5 24 H37.5 L36 34 H28 Z"/>',
                           '<path%s d="M10 39 H54 V56 H10 Z M10 46 H54 V49 H10 Z M24 39 H27.5 V46 H24 Z M38 39 H41.5 V46 H38 Z M17 49 H20.5 V56 H17 Z M31 49 H34.5 V56 H31 Z M45 49 H48.5 V56 H45 Z"/>' % EO]}

I["lock"] = {"l": ['<path d="M21 28 V20 A11 11 0 0 1 43 20 V28"/>'],
             "s": ['<path%s d="M19 27 H45 C48 27 50 29 50 32 V51 C50 54 48 56 45 56 H19 C16 56 14 54 14 51 V32 C14 29 16 27 19 27 Z M29.8 42.8 A4.8 4.8 0 1 1 34.2 42.8 L35 49 H29 Z"/>' % EO]}
I["unlock"] = {"l": ['<path d="M21 28 V17 A11 11 0 0 1 43 17 V19"/>'], "s": I["lock"]["s"]}
