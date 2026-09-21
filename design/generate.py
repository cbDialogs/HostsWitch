#!/usr/bin/env python3
"""Generates the HostsWitch design artboards (design/project/*.dc.html + canvas.json).

Five style directions x three screens (Edit window, View Hosts window, menu-bar
dropdown). Every artboard shows identical data so only style varies.
Run:  python3 design/generate.py
"""
import json, os, datetime

OUT = os.path.join(os.path.dirname(__file__), "project")

# ---------------------------------------------------------------- shared data
GROUPS = [
    {"name": "Default", "nodes": [{"name": "Default", "on": True}], "flat": True},
    {"name": "Acme", "nodes": [
        {"name": "Development", "on": True, "sel": True},
        {"name": "Staging", "on": False},
        {"name": "Production", "on": False}]},
    {"name": "Client B", "nodes": [
        {"name": "Local", "on": True},
        {"name": "Production", "on": False}]},
]
ENTRIES = [
    ("c", "# Acme — local dev stack"),
    ("e", "127.0.0.1", "acme.local"),
    ("e", "127.0.0.1", "api.acme.local"),
    ("e", "192.168.1.80", "cdn.acme.local"),
]
HOSTS_FILE = [
    ("c", "##"), ("c", "# Host Database"), ("c", "#"),
    ("c", "# localhost is used to configure the loopback interface"),
    ("c", "# when the system is booting.  Do not change this entry."),
    ("c", "##"),
    ("e", "127.0.0.1", "localhost"), ("e", "255.255.255.255", "broadcasthost"), ("e", "::1", "localhost"),
    ("b",),
    ("h", "# ---- HostsWitch: Default ----"), ("e", "127.0.0.1", "mysite.test"),
    ("b",),
    ("h", "# ---- HostsWitch: Acme / Development ----"),
    ("e", "127.0.0.1", "acme.local"), ("e", "127.0.0.1", "api.acme.local"), ("e", "192.168.1.80", "cdn.acme.local"),
    ("b",),
    ("h", "# ---- HostsWitch: Client B / Local ----"), ("e", "127.0.0.1", "clientb.test"),
]

# ---------------------------------------------------------------- styles
STYLES = {
 "Cupertino": dict(
    backdrop="#D5D6DB", win="#FFFFFF", side="#EDEDEF", sideBorder="#D9D9DE", bar="#F6F6F7", barBorder="#DADADF",
    text="#1D1D1F", muted="#5F5F66", faint="#8A8A91", accent="#0A66E0", accentText="#FFFFFF",
    selBg="#0A66E0", selText="#FFFFFF", rowHover="#E4E4E8", border="#D9D9DE", editor="#FFFFFF",
    ip="#0A66E0", host="#1D1D1F", comment="#7A7A82", hl="#EAF2FD", onColor="#0A66E0",
    ui="-apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif",
    mono="'SF Mono', Menlo, Consolas, monospace", title=None, fonts=[],
    lights=("#FF5F57", "#FEBC2E", "#28C840"), radius=10, btnRadius=6,
    apply="Apply", revert="Revert", tag="H", theme="light", dark=False,
    toggles=False, lineNumbers=False, statusBar=False, badges=False, glow=False, cauldron=False,
    menuBar="#E9E9EC", menuBarText="#1D1D1F", menuBg="#F2F2F4", menuText="#1D1D1F", menuSel="#0A66E0",
 ),
 "Slate": dict(
    backdrop="#141519", win="#24272E", side="#1D2026", sideBorder="#31353E", bar="#1D2026", barBorder="#31353E",
    text="#E6E8EC", muted="#9AA1AC", faint="#6C7380", accent="#5B9CF6", accentText="#0E1420",
    selBg="#2F3542", selText="#FFFFFF", rowHover="#282C34", border="#31353E", editor="#24272E",
    ip="#5B9CF6", host="#E6E8EC", comment="#7F8794", hl="#2A3040", onColor="#4CC38A",
    ui="-apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif",
    mono="'JetBrains Mono', 'SF Mono', Menlo, monospace", title=None,
    fonts=['https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&display=swap'],
    lights=("#FF5F57", "#FEBC2E", "#28C840"), radius=10, btnRadius=6,
    apply="Apply", revert="Revert", tag="H", theme="dark", dark=True,
    toggles=True, lineNumbers=True, statusBar=True, badges=False, glow=False, cauldron=False,
    menuBar="#1D2026", menuBarText="#E6E8EC", menuBg="#24272E", menuText="#E6E8EC", menuSel="#5B9CF6",
 ),
 "Terminal": dict(
    backdrop="#DDDDD8", win="#FBFBF8", side="#F2F2ED", sideBorder="#C9CBC4", bar="#F2F2ED", barBorder="#C9CBC4",
    text="#1F2320", muted="#5B625C", faint="#8B928C", accent="#0B7A5B", accentText="#FFFFFF",
    selBg="#0B7A5B", selText="#FFFFFF", rowHover="#E7E8E2", border="#C9CBC4", editor="#FBFBF8",
    ip="#0B7A5B", host="#1F2320", comment="#7A817B", hl="#E8F3EE", onColor="#0B7A5B",
    ui="'IBM Plex Mono', Menlo, monospace",
    mono="'IBM Plex Mono', Menlo, monospace", title=None,
    fonts=['https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&display=swap'],
    lights=("#FF5F57", "#FEBC2E", "#28C840"), radius=6, btnRadius=3,
    apply="Apply", revert="Revert", tag="H", theme="light", dark=False,
    toggles=False, lineNumbers=True, statusBar=True, badges=True, glow=False, cauldron=False,
    menuBar="#EDEDE8", menuBarText="#1F2320", menuBg="#FBFBF8", menuText="#1F2320", menuSel="#0B7A5B",
 ),
 "Coven": dict(
    backdrop="#0B0814", win="#1B1530", side="#150F28", sideBorder="#2E2650", bar="#150F28", barBorder="#2E2650",
    text="#E6E0F4", muted="#A89ECB", faint="#6F6592", accent="#F0894A", accentText="#1B1530",
    selBg="#2B2250", selText="#FFFFFF", rowHover="#221B40", border="#2E2650", editor="#1B1530",
    ip="#F0894A", host="#E6E0F4", comment="#8C82B3", hl="#261E48", onColor="#F0894A",
    ui="-apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif",
    mono="'JetBrains Mono', 'SF Mono', Menlo, monospace", title="'Cormorant Garamond', Georgia, serif",
    fonts=['https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,500;0,600;1,500&family=JetBrains+Mono:wght@400;500&display=swap'],
    lights=("#7A5A8A", "#6C5A9A", "#5A6AA0"), radius=12, btnRadius=8,
    apply="Cast", revert="Revert", tag="hat", theme="dark", dark=True,
    toggles=True, lineNumbers=False, statusBar=True, badges=False, glow=True, cauldron=False,
    menuBar="#120D22", menuBarText="#E6E0F4", menuBg="#1B1530", menuText="#E6E0F4", menuSel="#F0894A",
 ),
 "Hearth": dict(
    backdrop="#C4B698", win="#F8F1E2", side="#EFE4CE", sideBorder="#D9CBAE", bar="#EFE4CE", barBorder="#D9CBAE",
    text="#3A2E22", muted="#76644E", faint="#A08F76", accent="#B0601A", accentText="#FFFFFF",
    selBg="#E3D2B3", selText="#2A1F14", rowHover="#E9DDC5", border="#D9CBAE", editor="#F8F1E2",
    ip="#B0601A", host="#3A2E22", comment="#8C7A62", hl="#F1E6CF", onColor="#5C7A4A",
    ui="-apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif",
    mono="'IBM Plex Mono', Menlo, monospace", title="'Newsreader', Georgia, serif",
    fonts=['https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,500;0,6..72,600;1,6..72,400&family=IBM+Plex+Mono:wght@400;500&display=swap'],
    lights=("#C9846A", "#D6B26A", "#93A883"), radius=12, btnRadius=8,
    apply="Apply", revert="Revert", tag="cauldron", theme="light", dark=False,
    toggles=False, lineNumbers=False, statusBar=True, badges=False, glow=False, cauldron=True,
    menuBar="#E8DCC3", menuBarText="#3A2E22", menuBg="#F8F1E2", menuText="#3A2E22", menuSel="#B0601A",
 ),
}

# ---------------------------------------------------------------- svg icons (inline stroke)
def svg(path, size=14, stroke="currentColor", sw=1.8, fill="none"):
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="{fill}" stroke="{stroke}" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{path}</svg>')
CHECK = '<path d="M5 12.5l4.5 4.5L19 7"/>'
PLUS = '<path d="M12 5v14M5 12h14"/>'
MINUS = '<path d="M5 12h14"/>'
GEAR = '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>'
CHEV_DOWN = '<path d="M6 9l6 6 6-6"/>'
CHEV_RIGHT = '<path d="M9 6l6 6-6 6"/>'
SEARCH = '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>'
PENCIL = '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>'
EYE = '<path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/>'
LOCK = '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>'
FOLDER = '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'
HAT = '<path d="M2.5 18.5c2 1.6 17 1.6 19 0"/><path d="M6 18L11.2 4.2c.3-.8 1.3-.8 1.6 0L14 8.2 18 18"/><path d="M8.2 13.6c2.4 1.1 5.2 1.1 7.6 0"/>'
CAULDRON = '<path d="M4 10h16"/><path d="M5 10c0 6 3 9 7 9s7-3 7-9"/><path d="M7 10V8a5 5 0 0 1 10 0v2"/><path d="M9 4.5v-2M12 4V1.5M15 4.5v-2"/>'
MOON = '<path d="M21 13A9 9 0 1 1 11 3a7 7 0 0 0 10 10z"/>'
BROOM = '<path d="M3 21l9-9"/><path d="M12 12l6-6 3 3-6 6z"/><path d="M4 20c1-3 3-5 6-6"/>'
FLAME = '<path d="M12 22c4 0 7-3 7-7 0-3-2-5-3-7-1 2-2 3-3 3 0-3-1-6-3-8-1 4-5 6-5 12 0 4 3 7 7 7z"/>'
TERM = '<path d="M4 17l6-5-6-5"/><path d="M12 19h8"/>'
CHECK_ROUNDED = '<path d="M20 6L9 17l-5-5"/>'

def app_glyph(s, size=18, color=None):
    color = color or s["accent"]
    if s["tag"] == "hat":
        return svg(HAT, size, color, 1.9)
    if s["tag"] == "cauldron":
        return svg(CAULDRON, size, color, 1.9)
    return (f'<span style="display:inline-flex; align-items:center; justify-content:center; width:{size}px; height:{size}px; '
            f'border-radius:{max(4, size//4)}px; background:{color}; color:{s["accentText"]}; font-family:{s["ui"]}; '
            f'font-weight:700; font-size:{int(size*0.62)}px; letter-spacing:-0.02em;">H</span>')

# ---------------------------------------------------------------- primitives
def lights(s):
    return "".join(f'<span style="width:12px; height:12px; border-radius:50%; background:{c}; '
                   f'box-shadow: inset 0 0 0 0.5px rgba(0,0,0,0.15);"></span>' for c in s["lights"])

def toggle(s, on):
    bg = s["onColor"] if on else ("#3A3F4A" if s["dark"] else "#C8C8CE")
    x = 15 if on else 2
    glow = f' box-shadow: 0 0 10px {s["onColor"]}99;' if (on and s["glow"]) else ""
    return (f'<span style="position:relative; display:inline-block; width:30px; height:17px; border-radius:9px; '
            f'background:{bg}; flex-shrink:0;{glow}"><span style="position:absolute; top:2px; left:{x}px; width:13px; '
            f'height:13px; border-radius:50%; background:#FFFFFF; box-shadow:0 1px 2px rgba(0,0,0,0.3);"></span></span>')

def check_mark(s, on, color=None):
    if not on:
        return '<span style="width:14px; height:14px; flex-shrink:0;"></span>'
    c = color or s["onColor"]
    glow = f' filter: drop-shadow(0 0 4px {c});' if s["glow"] else ""
    return f'<span style="display:inline-flex; width:14px; height:14px; flex-shrink:0; color:{c};{glow}">{svg(CHECK, 14, "currentColor", 2.6)}</span>'

def btn(s, label, primary=False, w=None):
    if primary:
        st = (f'background:{s["accent"]}; color:{s["accentText"]}; border:1px solid {s["accent"]};')
        if s["glow"]:
            st += f' box-shadow: 0 0 16px {s["accent"]}66;'
    else:
        st = (f'background:{"#2C303A" if s["dark"] else "#FFFFFF"}; color:{s["text"]}; border:1px solid {s["border"]};')
    wst = f' min-width:{w}px;' if w else ""
    return (f'<button type="button" style="height:30px; padding:0 16px; border-radius:{s["btnRadius"]}px; font-family:{s["ui"]}; '
            f'font-size:13px; font-weight:{600 if primary else 500}; cursor:pointer;{wst} {st}">{label}</button>')

def icon_btn(s, path, label):
    return (f'<button type="button" aria-label="{label}" style="width:28px; height:26px; display:inline-flex; align-items:center; '
            f'justify-content:center; border:none; background:transparent; color:{s["muted"]}; border-radius:5px; cursor:pointer; padding:0;">'
            f'{svg(path, 14, "currentColor", 2)}</button>')

def segmented(s, active):
    items = [("edit", PENCIL, "Edit Hosts"), ("view", EYE, "View Hosts")]
    out = []
    for key, p, lab in items:
        on = key == active
        bg = (s["selBg"] if s["dark"] else "#FFFFFF") if on else "transparent"
        col = s["text"] if on else s["muted"]
        sh = " box-shadow: 0 1px 2px rgba(0,0,0,0.18);" if (on and not s["dark"]) else ""
        out.append(f'<button type="button" style="display:inline-flex; align-items:center; gap:6px; height:24px; padding:0 10px; '
                   f'border:none; border-radius:5px; background:{bg}; color:{col}; font-family:{s["ui"]}; font-size:12px; '
                   f'font-weight:500; cursor:pointer;{sh}">{svg(p, 13, "currentColor", 2)}{lab}</button>')
    trackbg = "#2C303A" if s["dark"] else ("#DEDEE2" if s["theme"] == "light" else s["side"])
    if s["tag"] == "cauldron": trackbg = "#E1D3B6"
    return (f'<div style="display:inline-flex; gap:2px; padding:2px; border-radius:7px; background:{trackbg};">' + "".join(out) + '</div>')

def toolbar(s, title, active, right_extra=""):
    tf = s["title"] or s["ui"]
    tsize = "20px" if s["title"] else "13px"
    tweight = "600" if s["title"] else "600"
    glyph = app_glyph(s, 18)
    return (f'<header style="height:52px; flex-shrink:0; display:flex; align-items:center; gap:14px; padding:0 16px 0 18px; '
            f'box-sizing:border-box; background:{s["bar"]}; border-bottom:1px solid {s["barBorder"]};">'
            f'<div style="display:flex; gap:8px; align-items:center; width:56px; flex-shrink:0;">{lights(s)}</div>'
            f'<div style="display:flex; align-items:center; gap:9px; width:250px; flex-shrink:0;">{glyph}'
            f'<span style="font-family:{tf}; font-size:{tsize}; font-weight:{tweight}; color:{s["text"]}; letter-spacing:-0.01em;">{title}</span></div>'
            f'<div style="flex-grow:1; display:flex; justify-content:center;">{segmented(s, active)}</div>'
            f'<div style="width:250px; display:flex; justify-content:flex-end; align-items:center; gap:10px; flex-shrink:0;">{right_extra}</div>'
            f'</header>')

def search_box(s):
    bg = "#2C303A" if s["dark"] else "#FFFFFF"
    return (f'<label style="display:flex; align-items:center; gap:7px; height:26px; width:180px; padding:0 9px; box-sizing:border-box; '
            f'border-radius:6px; border:1px solid {s["border"]}; background:{bg}; color:{s["faint"]};">'
            f'{svg(SEARCH, 13, "currentColor", 2)}<span style="font-family:{s["ui"]}; font-size:12px;">Search hosts</span>'
            f'<input type="search" aria-label="Search hosts" style="width:0; border:none; outline:none; background:transparent;"></label>')

def window(s, inner, w=1216, h=764, backdrop_extra=""):
    shadow = "0 30px 70px rgba(0,0,0,0.55), 0 0 0 0.5px rgba(255,255,255,0.10)" if s["dark"] else \
             "0 22px 60px rgba(30,25,20,0.30), 0 0 0 0.5px rgba(30,25,20,0.22)"
    return (f'<div style="width:1280px; height:820px; background:{s["backdrop"]}; display:flex; align-items:center; justify-content:center; '
            f'box-sizing:border-box; position:relative; overflow:hidden;">{backdrop_extra}'
            f'<div style="width:{w}px; height:{h}px; background:{s["win"]}; border-radius:{s["radius"]}px; overflow:hidden; display:flex; '
            f'flex-direction:column; box-shadow:{shadow}; position:relative;">{inner}</div></div>')

def moon_backdrop(s):
    if s["tag"] == "hat":
        return ('<div style="position:absolute; top:-90px; right:-60px; width:190px; height:190px; border-radius:50%; '
                'background:#E6E0F4; opacity:0.9; box-shadow:0 0 90px 30px rgba(230,224,244,0.25);"></div>'
                '<div style="position:absolute; top:-130px; right:-100px; width:190px; height:190px; border-radius:50%; '
                'background:#0B0814;"></div>'
                '<div style="position:absolute; bottom:-160px; left:-120px; width:520px; height:520px; border-radius:50%; '
                'background:#7A5CFF; opacity:0.10;"></div>')
    return ""

# ---------------------------------------------------------------- sidebar (shared by Edit and View)
def sidebar(s, mode="edit"):
    rows = []
    for g in GROUPS:
        if g.get("flat"):
            n = g["nodes"][0]
            rows.append(node_row(s, n, top=True))
            continue
        badge = ""
        if s["badges"]:
            badge = (f'<span style="margin-left:auto; font-size:10px; padding:1px 6px; border-radius:3px; border:1px solid {s["border"]}; '
                     f'color:{s["muted"]}; letter-spacing:0.04em;">1 of {len(g["nodes"])}</span>')
        rows.append(f'<div style="display:flex; align-items:center; gap:6px; padding:12px 12px 4px 12px; color:{s["faint"]}; '
                    f'font-family:{s["ui"]}; font-size:11px; font-weight:600; letter-spacing:0.08em; text-transform:uppercase;">'
                    f'{svg(CHEV_DOWN, 11, "currentColor", 2.4)}<span style="color:{s["muted"]};">{g["name"]}</span>{badge}</div>')
        for n in g["nodes"]:
            rows.append(node_row(s, n))
    footer = (f'<div style="height:34px; flex-shrink:0; border-top:1px solid {s["sideBorder"]}; display:flex; align-items:center; '
              f'padding:0 6px; gap:2px;">{icon_btn(s, PLUS, "Add group or node")}{icon_btn(s, MINUS, "Remove")}'
              f'<span style="flex-grow:1;"></span>{icon_btn(s, GEAR, "Options")}</div>')
    head = (f'<div style="padding:14px 16px 4px; font-family:{s["ui"]}; font-size:11px; font-weight:600; letter-spacing:0.1em; '
            f'text-transform:uppercase; color:{s["faint"]};">Hosts</div>')
    if s["title"]:
        head = (f'<div style="padding:14px 16px 4px; font-family:{s["title"]}; font-size:17px; font-weight:600; '
                f'color:{s["muted"]}; font-style:italic;">Your hosts</div>')
    return (f'<aside style="width:240px; flex-shrink:0; background:{s["side"]}; border-right:1px solid {s["sideBorder"]}; '
            f'display:flex; flex-direction:column;">{head}'
            f'<nav aria-label="Host groups" style="flex-grow:1; display:flex; flex-direction:column; padding:4px 8px; gap:1px; overflow:hidden;">'
            + "".join(rows) + '</nav>' + footer + '</aside>')

def node_row(s, n, top=False):
    sel = n.get("sel", False)
    pad = "6px 10px 6px 10px" if top else "6px 10px 6px 26px"
    bg = s["selBg"] if sel else "transparent"
    col = s["selText"] if sel else s["text"]
    tick_col = s["selText"] if (sel and s["selText"] == "#FFFFFF" and not s["dark"]) else None
    ctrl = toggle(s, n["on"]) if s["toggles"] else check_mark(s, n["on"], tick_col)
    weight = "600" if n["on"] else "400"
    if s["toggles"]:
        return (f'<a href="#" style="display:flex; align-items:center; gap:10px; padding:{pad}; border-radius:6px; background:{bg}; '
                f'color:{col}; text-decoration:none; font-family:{s["ui"]}; font-size:13px; font-weight:{weight};">'
                f'<span style="flex-grow:1;">{n["name"]}</span>{ctrl}</a>')
    return (f'<a href="#" style="display:flex; align-items:center; gap:8px; padding:{pad}; border-radius:6px; background:{bg}; '
            f'color:{col}; text-decoration:none; font-family:{s["ui"]}; font-size:13px; font-weight:{weight};">'
            f'{ctrl}<span>{n["name"]}</span></a>')

# ---------------------------------------------------------------- editor pane
def code_lines(s, lines, numbers=False, hostswitch_hl=False):
    out = []
    for i, ln in enumerate(lines, 1):
        kind = ln[0]
        num = (f'<span style="width:34px; flex-shrink:0; text-align:right; padding-right:14px; color:{s["faint"]}; user-select:none;">{i}</span>'
               if numbers else "")
        if kind == "b":
            body = "&nbsp;"
            bg = ""
        elif kind in ("c", "h"):
            body = f'<span style="color:{s["comment"]}; font-style:italic;">{ln[1]}</span>'
            bg = f' background:{s["hl"]};' if (kind == "h" and hostswitch_hl) else ""
            if kind == "h": body = f'<span style="color:{s["accent"]}; font-weight:600;">{ln[1]}</span>'
        else:
            ip = ln[1].ljust(16).replace(" ", "&nbsp;")
            body = f'<span style="color:{s["ip"]};">{ip}</span><span style="color:{s["host"]};">{ln[2]}</span>'
            bg = ""
        out.append(f'<div style="display:flex; align-items:center; height:22px; padding:0 8px; border-radius:3px;{bg}">{num}<span>{body}</span></div>')
    return "".join(out)

def status_bar(s, left, right):
    if not s["statusBar"]:
        return ""
    return (f'<div style="height:26px; flex-shrink:0; border-top:1px solid {s["border"]}; display:flex; align-items:center; '
            f'justify-content:space-between; padding:0 14px; font-family:{s["mono"]}; font-size:11px; color:{s["muted"]}; '
            f'background:{s["side"]};"><span>{left}</span><span>{right}</span></div>')

def editor_pane(s):
    crumb_font = s["title"] or s["ui"]
    crumb_size = "22px" if s["title"] else "15px"
    pill = (f'<span style="display:inline-flex; align-items:center; gap:6px; padding:3px 9px; border-radius:99px; font-family:{s["ui"]}; '
            f'font-size:11px; font-weight:600; color:{s["onColor"]}; border:1px solid {s["onColor"]};'
            f'{" box-shadow:0 0 12px " + s["onColor"] + "66;" if s["glow"] else ""}">'
            f'<span style="width:7px; height:7px; border-radius:50%; background:{s["onColor"]};"></span>Active</span>')
    head = (f'<div style="display:flex; align-items:center; gap:12px; padding:18px 22px 10px;">'
            f'<div style="display:flex; align-items:baseline; gap:8px; font-family:{crumb_font}; font-size:{crumb_size}; color:{s["text"]}; font-weight:600;">'
            f'<span style="color:{s["muted"]}; font-weight:400;">Acme</span><span style="color:{s["faint"]}; font-weight:400;">›</span><span>Development</span></div>'
            f'{pill}<span style="flex-grow:1;"></span>'
            f'<span style="font-family:{s["ui"]}; font-size:12px; color:{s["muted"]};">3 entries · edited</span></div>')
    editor = (f'<div role="textbox" aria-label="Host entries" aria-multiline="true" tabindex="0" style="flex-grow:1; margin:0 22px; padding:12px 6px; '
              f'border:1px solid {s["border"]}; border-radius:{max(4, s["btnRadius"])}px; background:{s["editor"]}; font-family:{s["mono"]}; '
              f'font-size:13px; line-height:22px; color:{s["text"]}; box-sizing:border-box; overflow:hidden;">'
              f'{code_lines(s, ENTRIES, numbers=s["lineNumbers"])}'
              f'<div style="display:flex; align-items:center; height:22px; padding:0 8px;">'
              f'{"<span style=\"width:34px; flex-shrink:0;\"></span>" if s["lineNumbers"] else ""}'
              f'<span style="display:inline-block; width:1.5px; height:16px; background:{s["accent"]};"></span></div></div>')
    hint = (f'<span style="font-family:{s["ui"]}; font-size:12px; color:{s["faint"]};">One entry per line: IP, then hostnames. '
            f'<span style="font-family:{s["mono"]};">#</span> starts a comment.</span>')
    foot = (f'<div style="display:flex; align-items:center; gap:10px; padding:14px 22px 18px;">{hint}<span style="flex-grow:1;"></span>'
            f'{btn(s, s["revert"], w=84)}{btn(s, s["apply"], primary=True, w=84)}</div>')
    sb = status_bar(s, "3 active · 6 nodes", "last applied 14:02")
    return (f'<section style="flex-grow:1; display:flex; flex-direction:column; background:{s["win"]}; min-width:0;">'
            f'<div style="flex-grow:1; display:flex; flex-direction:column;">{head}{editor}{foot}</div>{sb}</section>')

# ---------------------------------------------------------------- view pane
def view_pane(s):
    crumb_font = s["title"] or s["ui"]
    crumb_size = "22px" if s["title"] else "15px"
    lockpill = (f'<span style="display:inline-flex; align-items:center; gap:6px; padding:3px 9px; border-radius:99px; font-family:{s["ui"]}; '
                f'font-size:11px; font-weight:600; color:{s["muted"]}; border:1px solid {s["border"]};">{svg(LOCK, 11, "currentColor", 2)}Read-only</span>')
    head = (f'<div style="display:flex; align-items:center; gap:12px; padding:18px 22px 10px;">'
            f'<div style="font-family:{crumb_font}; font-size:{crumb_size}; color:{s["text"]}; font-weight:600;">'
            f'<span style="font-family:{s["mono"]}; font-weight:500;">/etc/hosts</span></div>{lockpill}<span style="flex-grow:1;"></span>'
            f'<span style="font-family:{s["ui"]}; font-size:12px; color:{s["muted"]};">19 lines · written by HostsWitch at 14:02</span></div>')
    body = (f'<pre style="flex-grow:1; margin:0 22px; padding:12px 6px; border:1px solid {s["border"]}; border-radius:{max(4, s["btnRadius"])}px; '
            f'background:{s["editor"]}; font-family:{s["mono"]}; font-size:13px; line-height:22px; color:{s["text"]}; overflow:hidden; '
            f'white-space:normal;">{code_lines(s, HOSTS_FILE, numbers=s["lineNumbers"], hostswitch_hl=True)}</pre>')
    legend = (f'<span style="display:inline-flex; align-items:center; gap:8px; font-family:{s["ui"]}; font-size:12px; color:{s["muted"]};">'
              f'<span style="width:12px; height:12px; border-radius:3px; background:{s["hl"]}; border:1px solid {s["border"]};"></span>'
              f'Sections HostsWitch manages · everything else is left untouched</span>')
    foot = (f'<div style="display:flex; align-items:center; gap:10px; padding:14px 22px 18px;">{legend}<span style="flex-grow:1;"></span>'
            f'{btn(s, "Reveal in Finder")}{btn(s, "Copy")}</div>')
    sb = status_bar(s, "watching /etc/hosts", "changes outside HostsWitch appear live")
    return (f'<section style="flex-grow:1; display:flex; flex-direction:column; background:{s["win"]}; min-width:0;">'
            f'<div style="flex-grow:1; display:flex; flex-direction:column;">{head}{body}{foot}</div>{sb}</section>')

# ---------------------------------------------------------------- menu-bar dropdown (480×620)
def menu_board(s):
    ui = s["ui"]
    def item(label, on=None, shortcut="", sub=False, dim=False, arrow=False, selected=False):
        col = s["menuText"]
        if dim: col = s["faint"]
        bg = s["menuSel"] if selected else "transparent"
        if selected: col = s["accentText"] if s["dark"] else "#FFFFFF"
        mark = check_mark(s, bool(on), col if selected else None) if on is not None else '<span style="width:14px;"></span>'
        sc = f'<span style="color:{s["faint"] if not selected else col}; font-size:13px;">{shortcut}</span>' if shortcut else ""
        ar = svg(CHEV_RIGHT, 12, "currentColor", 2.2) if arrow else ""
        pad = "0 12px 0 30px" if sub else "0 12px 0 10px"
        return (f'<div style="display:flex; align-items:center; gap:8px; height:28px; padding:{pad}; margin:0 6px; border-radius:6px; '
                f'background:{bg}; color:{col}; font-family:{ui}; font-size:14px; font-weight:{600 if on else 400};">'
                f'{mark}<span style="flex-grow:1;">{label}</span>{sc}{ar}</div>')
    def header(label):
        return (f'<div style="display:flex; align-items:center; gap:6px; height:24px; padding:0 12px 0 16px; margin:4px 6px 0; '
                f'color:{s["faint"]}; font-family:{ui}; font-size:11px; font-weight:600; letter-spacing:0.08em; text-transform:uppercase;">'
                f'{svg(FOLDER, 12, "currentColor", 2)}{label}</div>')
    sep = f'<div style="height:1px; background:{s["border"]}; margin:5px 12px;"></div>'
    items = [item("Default", on=True)]
    for g in GROUPS[1:]:
        items.append(header(g["name"]))
        for n in g["nodes"]:
            items.append(item(n["name"], on=n["on"], sub=True, selected=n.get("sel", False)))
    items.append(sep)
    items.append(item("View Hosts", shortcut="⌘V"))
    items.append(item("Edit Hosts…", shortcut="⌘E"))
    items.append(sep)
    items.append(item("Pause HostsWitch", shortcut=""))
    items.append(item("More", arrow=True))
    items.append(sep)
    items.append(item("Quit HostsWitch", shortcut="⌘Q"))
    glyph = app_glyph(s, 18, s["menuBarText"] if s["tag"] != "H" else s["menuSel"])
    if s["tag"] == "H":
        glyph = app_glyph(s, 18, s["menuSel"])
    bar = (f'<div style="height:30px; display:flex; align-items:center; justify-content:flex-end; gap:14px; padding:0 14px; background:{s["menuBar"]}; '
           f'border-bottom:1px solid {s["border"]}; font-family:{ui}; font-size:13px; color:{s["menuBarText"]};">'
           f'<span style="display:inline-flex; align-items:center; justify-content:center; width:34px; height:24px; border-radius:5px; '
           f'background:{"rgba(255,255,255,0.14)" if s["dark"] else "rgba(0,0,0,0.10)"};">{glyph}</span>'
           f'<span style="color:{s["muted"]};">{svg(SEARCH, 14, "currentColor", 2)}</span><span>Mon 21 Sep</span><span>14:07</span></div>')
    shadow = "0 18px 50px rgba(0,0,0,0.6), 0 0 0 0.5px rgba(255,255,255,0.10)" if s["dark"] else "0 18px 50px rgba(0,0,0,0.28), 0 0 0 0.5px rgba(0,0,0,0.15)"
    panel = (f'<div style="position:absolute; top:34px; right:122px; width:270px; padding:6px 0; border-radius:10px; background:{s["menuBg"]}; '
             f'box-shadow:{shadow}; display:flex; flex-direction:column;">' + "".join(items) + '</div>')
    caption = (f'<div style="position:absolute; left:18px; bottom:18px; width:160px; font-family:{ui}; font-size:11px; line-height:1.45; color:{s["muted"]};">'
               f'Menu-bar dropdown. One active node per group; picking another swaps it and rewrites /etc/hosts.</div>')
    return (f'<div style="width:480px; height:620px; background:{s["backdrop"]}; position:relative; overflow:hidden; box-sizing:border-box;">'
            f'{moon_backdrop(s)}{bar}{panel}{caption}</div>')

# ---------------------------------------------------------------- page wrapper
def page(s, title, body, w, h):
    links = "".join(f'<link rel="stylesheet" href="{u}">' for u in s["fonts"])
    return f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
{links}
<style>
body{{margin:0;font-family:{s["ui"]};color:{s["text"]};background:{s["backdrop"]}}}
a{{color:{s["accent"]}}}a:hover{{color:{s["accent"]}}}
</style>
</helmet>
{body}
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":{w},"height":{h}}}}}'>
class Component extends DCLogic {{
  renderVals() {{ return {{}}; }}
}}
</script>
</body>
</html>
'''

def edit_board(s, name):
    inner = toolbar(s, "HostsWitch", "edit", search_box(s)) + \
        f'<div style="flex-grow:1; display:flex; min-height:0;">{sidebar(s)}{editor_pane(s)}</div>'
    return window(s, inner, backdrop_extra=moon_backdrop(s))

def view_board(s, name):
    inner = toolbar(s, "HostsWitch", "view", search_box(s)) + \
        f'<div style="flex-grow:1; display:flex; min-height:0;">{sidebar(s, "view")}{view_pane(s)}</div>'
    return window(s, inner, backdrop_extra=moon_backdrop(s))

# ---------------------------------------------------------------- annotations
NOTES = {
 "Cupertino": "1 · CUPERTINO — the safe one.\nStock macOS: grey source-list sidebar, unified toolbar with an Edit/View segmented control, SF Mono editor, standard Revert/Apply push buttons, blue selection. Closest to iHosts.\nTradeoff: indistinguishable from every other Mac utility. Nothing here is yours.",
 "Slate": "2 · SLATE — dark developer tool (Tower / Kaleidoscope lineage).\nGraphite panels, cool-blue accent, JetBrains Mono editor with line numbers and IP/hostname tinting. Each node carries a real toggle switch in the sidebar, so you switch environments without leaving the list. Status bar shows active count + last apply.\nTradeoff: dark-only as drawn; toggles make the sidebar busier.",
 "Terminal": "3 · TERMINAL — monospace everything, hairlines, no chrome.\nIBM Plex Mono for UI and editor, forest-green accent, tag-style ‘1 of 3’ badges on each group, square corners, status bar. Feels like a config file that grew a sidebar.\nTradeoff: mono UI type is less legible at 13px than SF; least ‘Mac-like’ of the straight three.",
 "Coven": "4 · COVEN — the witch theme, moonlit.\nDeep indigo panels, moon-silver text, ember-orange accent; active nodes and the Active pill glow faintly. Cormorant Garamond for the window title and breadcrumb, JetBrains Mono editor. Menu-bar icon is a witch’s hat; Apply becomes ‘Cast’ (optional wording — everything else stays plain).\nTradeoff: a strong mood — some people will never want a purple hosts editor.",
 "Hearth": "5 · HEARTH — the witch theme, cottage edition.\nParchment and cream panels, candle-amber accent, dried-herb green for active nodes, muted traffic lights. Newsreader serif titles (as in MarkDownNotes) over an IBM Plex Mono editor. Cauldron in the toolbar and menu bar. The friendlier take on Hosts-Witch.\nTradeoff: warm palette lowers contrast on the small mono text; watch legibility in bright rooms.",
}
HOW_TO_READ = ("How to read this canvas.\n\nFive directions, one row each: the Edit window, the read-only View Hosts window, and the menu-bar dropdown.\n\n"
               "Every artboard shows the same three groups (Default, Acme, Client B), the same selected node (Acme › Development) and the same /etc/hosts — "
               "only style varies.\n\nOptions 1–3 are straight macOS looks; 4–5 carry the Hosts-Witch theme. Mix and match: a palette from one row on the layout of another is fair game, as MarkDownNotes did.\n\nStatic pictures — nothing clicks yet.")

# ---------------------------------------------------------------- main
def main():
    os.makedirs(OUT, exist_ok=True)
    boards, order, notes = {}, [], {}
    PITCH = 1260
    for i, (name, s) in enumerate(STYLES.items()):
        row_y = i * PITCH + 300
        files = [
            (f"{name}-Edit.dc.html" if name != "Cupertino" else "Main.dc.html", f"{name} · Edit Hosts", edit_board(s, name), 1280, 820, 0),
            (f"{name}-View.dc.html", f"{name} · View Hosts", view_board(s, name), 1280, 820, 1360),
            (f"{name}-Menu.dc.html", f"{name} · Menu bar", menu_board(s), 480, 620, 2720),
        ]
        for fn, title, body, w, h, x in files:
            with open(os.path.join(OUT, fn), "w") as f:
                f.write(page(s, title, body, w, h))
            boards[fn] = {"x": x, "y": row_y, "w": w, "h": h, "title": title}
            order.append(fn)
        notes[f"opt-{i+1}"] = {"x": 0, "y": row_y - 250, "w": 1280, "maxH": 220, "text": NOTES[name], "size": "m"}
    notes["how-to-read"] = {"x": 3300, "y": 300, "w": 420, "maxH": 620, "text": HOW_TO_READ, "size": "m", "fill": "orange"}
    canvas = {
        "v": 3,
        "createdOnFiles": {"v": 1, "at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")},
        "title": "HostsWitch Styles",
        "launch": {"view": "canvas"},
        "pages": [],
        "boards": boards,
        "order": order,
        "notes": notes,
        "designSystems": [],
    }
    with open(os.path.join(OUT, "canvas.json"), "w") as f:
        json.dump(canvas, f, indent=2, ensure_ascii=False)
    print(f"wrote {len(order)} artboards + canvas.json to {OUT}")

if __name__ == "__main__":
    main()
