from geo import *
EO = ' fill-rule="evenodd"'
I = {}


I["siege"] = {"l": ['<path d="M8 54 H56 M23 54 L33 34 L43 54 M14 47 L45 18"/>'],
              "s": ['<path d="%s"/>' % circ(49.5, 14, 6.5)]}


I["fire_ranged"] = {"s": ['<path d="%s %s %s"/>' % (cap(11, 53, 42, 22, 7), cap(8.5, 44.5, 19.5, 44.5, 7), cap(19.5, 44.5, 19.5, 55.5, 7)),
                          '<path d="%s"/>' % head((57.5, 6.5), (39.5, 24.5), 11)]}

def knife_s(dx=0.0, dy=0.0):
    blade = "M%s L%s L%s L%s L%s L%s L%s L%s C%s %s %s L%s L%s L%s L%s Z" % (pts((20 + dx, 37.5 + dy)), pts((29 + dx, 30 + dy)), pts((29.5 + dx, 27.5 + dy)), pts((38 + dx, 22.5 + dy)), pts((38.5 + dx, 20 + dy)), pts((47 + dx, 15 + dy)), pts((47.5 + dx, 12.5 + dy)), pts((55 + dx, 8.5 + dy)), pts((54 + dx, 20 + dy)), pts((47.5 + dx, 31 + dy)), pts((38 + dx, 38.5 + dy)),
        pts((35 + dx, 38.5 + dy)), pts((33 + dx, 41.5 + dy)), pts((29.5 + dx, 42.5 + dy)), pts((26.5 + dx, 44 + dy)))
    return ['<path d="%s"/>' % blade, '<path d="%s"/>' % cap(10 + dx, 54 + dy, 22.5 + dx, 41.5 + dy, 8.5)]
I["coat"] = {"s": knife_s(-3, -5) + ['<path d="%s"/>' % drop(40.5, 41, 4.4), '<path d="%s"/>' % drop(52, 36, 5.4)]}
I["drink"] = {"s": ['<path d="M9 36 H55 C55 47.5 45 55.5 32 55.5 C19 55.5 9 47.5 9 36 Z"/>', '<path d="%s"/>' % drop(32, 7, 8.2)]}

I["wash"] = {"l": ['<circle cx="25" cy="38" r="13"/>', '<circle cx="45.5" cy="19.5" r="7.5"/>', '<path d="M18.5 37 A7 7 0 0 1 24 31.5"/>'],
             "s": ['<path d="%s"/>' % circ(48, 43, 4.5)]}

I["sleep"] = {"s": ['<path d="M29.67 14.01 A20 20 0 1 0 49.29 39.23 A16 16 0 1 1 29.67 14.01 Z"/>', '<path d="%s"/>' % sparkle(49, 15, 8)]}

I["cook"] = {"s": [g("translate(24 58) scale(1.05)", flame()), g("translate(30 -2) rotate(-30 32 32) scale(0.66)", *drum())]}

BAG = 'M18 27 C11 34 9.5 44 12 50 C14 54.5 18.5 56 24 56 H40 C45.5 56 50 54.5 52 50 C54.5 44 53 34 46 27 Z'
I["bag"] = {"s": ['<path d="%s"/>' % BAG, '<rect x="19" y="19" width="26" height="6" rx="3"/>',
                  '<path d="M23 17 L18.5 8.5 L28 12 L32 6.5 L36 12 L45.5 8.5 L41 17 Z"/>']}

I["loot"] = {"l": ['<path d="M32 5 V13"/>'],
             "s": ['<path%s d="%s %s"/>' % (EO, BAG.replace("M18 27", "M17.5 28").replace("46 27 Z", "46.5 28 Z"), "M21 30.5 H43 C44.5 30.5 45 31.5 44 32.5 C41 35 36.5 36 32 36 C27.5 36 23 35 20 32.5 C19 31.5 19.5 30.5 21 30.5 Z"),
                   '<path d="M15 26 C15 23 17 21.5 20 21.5 H44 C47 21.5 49 23 49 26 Z"/>',
                   '<path d="%s"/>' % head((32, 19), (32, 9), 7.5)]}


I["pen"] = {"l": ['<path d="M7 29 H57 M7 45 H57"/>'],
            "s": ['<path d="%s"/>' % " ".join(poly((x - 3.2, 55), (x - 3.2, 19.5), (x, 12), (x + 3.2, 19.5), (x + 3.2, 55)) for x in (14.5, 26, 38, 49.5))]}

