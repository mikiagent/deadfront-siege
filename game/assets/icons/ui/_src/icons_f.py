from geo import *
EO = ' fill-rule="evenodd"'
I = {}
# Status glyphs are drawn as small as 12 px on plates: one bold idea each, no fine detail.

I["bleed"] = {"s": ['<path d="%s"/>' % drop(32, 6, 17)]}


I["knockdown"] = {"l": ['<path d="M17 8 L32 21 L47 8 M17 23 L32 36 L47 23 M8 53 H56"/>']}


I["fracture"] = {"s": ['<path d="%s %s %s M17 41 L30.5 27.5 L28 34.5 L33.5 33 L23 47 Z"/>' % (circ(9.5, 48.5, 5), circ(15.5, 54.5, 5), cap(13, 51, 24, 40, 8.5)),
                       '<path d="%s %s %s M47 23 L33.5 36.5 L36 29.5 L30.5 31 L41 17 Z"/>' % (circ(54.5, 15.5, 5), circ(48.5, 9.5, 5), cap(51, 13, 40, 24, 8.5))]}




I["enraged"] = {"s": ['<path d="M6 17 L29 28 L27 34 L4 23 Z M58 17 L35 28 L37 34 L60 23 Z"/>', '<path d="%s %s"/>' % (circ(19, 41, 6), circ(45, 41, 6)), '<path d="M20 55 C25 51 39 51 44 55 L42 57.5 C37 55 27 55 22 57.5 Z"/>']}


I["full"] = {"s": ['<path d="M7 35 H57 C57 47 46 56 32 56 C18 56 7 47 7 35 Z"/>', '<path d="M11 31.5 C11 26 14 23 18 23 C18 17.5 22 14 27 14.5 C29 10.5 35 10.5 37 14.5 C42 14 46 17.5 46 23 C50 23 53 26 53 31.5 Z"/>']}



# skills, progression, island biomes
I["survival"] = {"l": ['<circle cx="32" cy="32" r="23"/>'],
                 "s": ['<path%s d="%s %s"/>' % (EO, poly((32, 12), (37, 27), (52, 32), (37, 37), (32, 52), (27, 37), (12, 32), (27, 27)), circ(32, 32, 3.2))]}

LEAF = lambda x1, y1, x2, y2, w: '<path d="M%s Q%s %s Q%s %s Z"/>' % (pts((x1, y1)), pts(((x1 + x2) / 2 - (y2 - y1) * w, (y1 + y2) / 2 + (x2 - x1) * w)), pts((x2, y2)), pts(((x1 + x2) / 2 + (y2 - y1) * w, (y1 + y2) / 2 - (x2 - x1) * w)), pts((x1, y1)))
I["gathering"] = {"l": ['<path d="M18 57 C22 44 28 32 40 20"/>'],
                  "s": [LEAF(23, 42, 6, 29, 0.62), LEAF(29, 33, 47, 33, 0.6), LEAF(39, 21, 56, 6, 0.6)]}

I["processing"] = {"l": ['<path d="M7 9 H57 M7 55 H57 M9 7 V57 M55 7 V57"/>'],
                   "s": ['<g transform="translate(8 8) scale(0.75)"><path d="M29 13 C30 11 34 11 35 13 L35.5 17 C38 17.5 40 18.5 41.5 20 L48 15 L46 23.5 C47.5 27 47.5 33 46 37 L48.5 47 L41 42.5 C39.5 44.5 37 46 35 46.5 L32 52 L29 46.5 C27 46 24.5 44.5 23 42.5 L15.5 47 L18 37 C16.5 33 16.5 27 18 23.5 L16 15 L22.5 20 C24 18.5 26 17.5 28.5 17 Z"/></g>']}

I["ranged"] = {"l": ['<path d="M14 9 L55 50"/>', '<path d="M11 53 L40 24"/>'],
               "s": ['<path d="M12 7 C30 4 47 9 53 16 C59 23 59 36 57 52 C54 38 50 27 44 21 C38 15 27 10 12 7 Z"/>', '<path d="%s"/>' % head((52, 12), (38.5, 25.5), 7.5),
                     '<path d="M15.5 44.5 L10 44.5 L6.5 48 L12 48 Z M15.5 44.5 V50 L12 53.5 V48 Z"/>']}



def kernel(cx, cy, side):
    return '<ellipse cx="%s" cy="%s" rx="3.6" ry="6.5" transform="rotate(%s %s %s)"/>' % (f(cx), f(cy), f(40 * side), f(cx), f(cy))
def kernel(cx, cy, side):
    return '<ellipse cx="%s" cy="%s" rx="3.4" ry="6.4" transform="rotate(%s %s %s)"/>' % (f(cx), f(cy), f(35 * side), f(cx), f(cy))
I["farming"] = {"l": ['<path d="M32 57 V16 M32 47 C27 41 21 41 16 37"/>'],
                "s": [kernel(32, 9.5, 0)] + [kernel(32 + 6.5 * sd, y, sd) for y in (17, 26, 35) for sd in (-1, 1)]}

I["xp"] = {"s": ['<path%s d="M5 32 C13 18 22 13 32 13 C42 13 51 18 59 32 C51 46 42 51 32 51 C22 51 13 46 5 32 Z %s"/>' % (EO, circ(32, 32, 11)), '<path d="%s"/>' % circ(32, 32, 5.5)]}

I["t_stone"] = {"s": ['<path%s d="M30 8 L42 10 L52 18 L56 31 L52 45 L41 54 L27 56 L15 50 L9 38 L10 24 L18 13 Z %s"/>' % (EO, circ(32, 32, 10.5))]}

I["meadow"] = {"s": ['<path d="M8 56 C10 46 13 38 19 32 C16 40 15 48 16 56 Z M17 56 C19 42 23 32 31 24 C27 34 26 46 27 56 Z M28 56 C29 44 33 36 41 30 C37 38 36 47 37 56 Z M38 56 C41 48 46 43 54 40 C49 45 47 50 47 56 Z"/>', '<path d="%s"/>' % circ(46, 18, 6), '<path d="M45 24 L43.5 40 H46.5 Z"/>']}

I["forest"] = {"s": ['<path d="M24 5 L36 21 H31 L40 33 H34 L44 47 H4 L14 33 H8 L17 21 H12 Z"/>', '<path d="M21 46 H27 V57 H21 Z"/>',
                     '<path d="M46 20 L54 31 H51 L58 41 H54 L60 50 H33 L40 41 H38 L42 31 H39 Z" transform="translate(-2 0)"/>', '<path d="M42 49 H46 V57 H42 Z"/>']}

I["rocky"] = {"s": ['<path%s d="M4 54 L24 14 L35 33 L41 25 L60 54 Z M24 14 L30 24 L26 22 L22 26 L19 22 L17 27 Z"/>' % EO]}

I["river"] = {"l": ['<path d="M7 19 C13 13 19 13 25 19 C31 25 37 25 43 19 C49 13 55 14 57 16 M7 32 C13 26 19 26 25 32 C31 38 37 38 43 32 C49 26 55 27 57 29 M7 45 C13 39 19 39 25 45 C31 51 37 51 43 45 C49 39 55 40 57 42"/>']}

I["coast"] = {"l": ['<path d="M6 56 H58"/>'],
              "s": ['<path%s d="M6 48 C8 30 22 16 38 16 C49 16 57 23 57 32 C57 39 52 43 46 43 C41 43 38 39.5 38 35.5 C38 32 41 30 44 31 C42 27 38 26 34 27.5 C25 31 22 40 22 48 Z"/>' % ""]}
