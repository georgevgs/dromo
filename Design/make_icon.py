"""Generates the Dromo layered app icon (Icon Composer .icon bundle).

Concept: a stopwatch dial. The volt arc is the run, stopping just short of the heat-pink
goal dot at 25 minutes on a 60-minute dial — sub-25, without a single word.
"""
import json, math, os, sys

OUT = sys.argv[1]
C = 1024                     # canvas
CX, CY = 512, 548            # dial centre, nudged down to balance the crown
R = 292                      # dial radius (centre line)

def pt(r, deg):
    """Point at clock angle `deg` (0 = 12 o'clock, clockwise)."""
    a = math.radians(deg)
    return CX + r * math.sin(a), CY - r * math.cos(a)

def ring(r_out, r_in):
    def circle(r, sweep):
        return (f"M {CX - r:.2f} {CY:.2f} A {r} {r} 0 1 {sweep} {CX + r:.2f} {CY:.2f} "
                f"A {r} {r} 0 1 {sweep} {CX - r:.2f} {CY:.2f} Z")
    return circle(r_out, 1) + " " + circle(r_in, 0)

def arc(r, width, start, end):
    """Thick arc with round caps, as a filled outline (no strokes: crisper glass edges)."""
    ro, ri, cap = r + width / 2, r - width / 2, width / 2
    large = 1 if (end - start) % 360 > 180 else 0
    s_o, e_o, e_i, s_i = pt(ro, start), pt(ro, end), pt(ri, end), pt(ri, start)
    return (f"M {s_o[0]:.2f} {s_o[1]:.2f} "
            f"A {ro} {ro} 0 {large} 1 {e_o[0]:.2f} {e_o[1]:.2f} "
            f"A {cap} {cap} 0 0 1 {e_i[0]:.2f} {e_i[1]:.2f} "
            f"A {ri} {ri} 0 {large} 0 {s_i[0]:.2f} {s_i[1]:.2f} "
            f"A {cap} {cap} 0 0 1 {s_o[0]:.2f} {s_o[1]:.2f} Z")

def dot(r, deg, radius):
    x, y = pt(r, deg)
    return (f"M {x - radius:.2f} {y:.2f} A {radius} {radius} 0 1 0 {x + radius:.2f} {y:.2f} "
            f"A {radius} {radius} 0 1 0 {x - radius:.2f} {y:.2f} Z")

def rrect(x, y, w, h, r):
    return (f"M {x + r} {y} H {x + w - r} A {r} {r} 0 0 1 {x + w} {y + r} V {y + h - r} "
            f"A {r} {r} 0 0 1 {x + w - r} {y + h} H {x + r} A {r} {r} 0 0 1 {x} {y + h - r} "
            f"V {y + r} A {r} {r} 0 0 1 {x + r} {y} Z")

def svg(path, color, rule="nonzero"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{C}" height="{C}" viewBox="0 0 {C} {C}">'
            f'<path fill="{color}" fill-rule="{rule}" d="{path}"/></svg>')

# Floodlight: a night sky, a volt run, a heat goal (the Dromo Design tokens accent and effort, dark values).
WHITE, VOLT, HEAT = "#FFFFFF", "#D4FF3A", "#FF3D7F"
ring_w, arc_w = 44, 104
top = CY - R - ring_w / 2                       # outer top edge of the ring

layers = {
    "1-dial.svg":   svg(ring(R + ring_w / 2, R - ring_w / 2), WHITE, "evenodd"),
    "2-crown.svg":  svg(rrect(CX - 30, top - 52, 60, 60, 14) + " " + rrect(CX - 84, top - 118, 168, 72, 30), WHITE),
    "3-goal.svg":   svg(dot(R, 150, 40), HEAT),                  # 25 min on a 60-min dial
    "4-run.svg":    svg(arc(R, arc_w, 0, 124), VOLT),             # the run finishes before it
}

icon = {
    "fill": {"linear-gradient": ["extended-srgb:0.11,0.13,0.29,1.00000", "extended-srgb:0.02,0.02,0.04,1.00000"],
             "orientation": {"start": {"x": 0.5, "y": 0.0}, "stop": {"x": 0.5, "y": 1.0}}},
    "groups": [
        {"name": "Run",
         "layers": [{"name": "Run", "image-name": "4-run.svg", "glass": True},
                    {"name": "Goal", "image-name": "3-goal.svg", "glass": True}],
         "shadow": {"kind": "layer-color", "opacity": 0.5},
         "translucency": {"enabled": True, "value": 0.15}},
        {"name": "Dial",
         "layers": [
             {"name": "Crown", "image-name": "2-crown.svg", "glass": True, "opacity": 0.9,
              "fill-specializations": [{"appearance": "dark", "value": {"solid": "display-p3:1.0,1.0,1.0,1.00000"}}]},
             {"name": "Dial", "image-name": "1-dial.svg", "glass": True, "opacity": 0.35,
              "opacity-specializations": [{"appearance": "dark", "value": 0.5}],
              "fill-specializations": [{"appearance": "dark", "value": {"solid": "display-p3:1.0,1.0,1.0,1.00000"}}]},
         ],
         "shadow": {"kind": "neutral", "opacity": 0.5},
         "translucency": {"enabled": True, "value": 0.4}},
    ],
    "supported-platforms": {"squares": "shared"},
}

os.makedirs(os.path.join(OUT, "Assets"), exist_ok=True)
for name, content in layers.items():
    open(os.path.join(OUT, "Assets", name), "w").write(content)
json.dump(icon, open(os.path.join(OUT, "icon.json"), "w"), indent=2)
print("wrote", OUT)
