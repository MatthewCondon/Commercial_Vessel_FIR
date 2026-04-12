"""
brain_report.py
---------------
Page 1  : Cover / summary
Pages 2+: One graph per nature TYPE, scaled intelligently.
          PGNs are grouped into scale bands so lines are always readable.
          If a type has PGNs across wildly different scales, it gets
          multiple pages — one per scale band.
"""

import os, io, re, math, joblib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from matplotlib.lines import Line2D
import matplotlib.cm as cm
from collections import Counter, defaultdict
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, Image
)
from reportlab.lib.colors import HexColor

BRAIN_PATH  = 'ML models/system_hmm_brain.pkl'
OUTPUT_PATH = 'ML models/pgn_brain_report.pdf'
DATA_FOLDER = 'GoodData'
MAX_POINTS  = 3000   # per PGN line, downsampled evenly if exceeded

# ── PDF colours ───────────────────────────────────────────────────────────────
C_DARK     = HexColor('#1C2340')
C_WHITE    = HexColor('#FFFFFF')
C_OFFWHITE = HexColor('#F5F7FA')
C_RULE     = HexColor('#DDE3EE')
C_TEXT     = HexColor('#2C3350')
C_MUTED    = HexColor('#6B7399')

NATURE_META = {
    'circular': ('#E8F4FD', '#1A7FC4', 'Circular  (wraps around 360°)'),
    'linear':   ('#EAF7EE', '#1E8A45', 'Linear  (rises and falls freely)'),
    'counter':  ('#FFF4E5', '#C07A00', 'Counter  (always counts up)'),
    'static':   ('#F3EEFF', '#6D3EC1', 'Static  (rarely changes)'),
}

# 20 visually distinct colours for lines
LINE_COLORS = [
    '#1A7FC4','#E05A2B','#1E8A45','#9B3DC8','#C07A00',
    '#D62728','#17BECF','#8C6D31','#E377C2','#7F7F7F',
    '#BCBD22','#AEC7E8','#FF7F0E','#2CA02C','#9467BD',
    '#8C564B','#F7B6D2','#C7C7C7','#DBDB8D','#9EDAE5',
]


# ══════════════════════════════════════════════════════════════════════════════
# DATA LOADING
# ══════════════════════════════════════════════════════════════════════════════
def parse_line(line):
    try:
        parts = line.strip().split()
        if len(parts) < 5:
            return None
        pgn     = parts[4]
        payload = line.split(":", 1)[1]
        inst_m  = re.search(r"Instance\s*=\s*([^;,\n]+)", payload)
        instance = inst_m.group(1).strip().split()[-1] if inst_m else "0"
        sid      = f"{pgn}_{instance}"
        matches  = re.findall(r"=\s*([-+]?\d*\.\d+|\d+)", payload)
        if not matches:
            return None
        val = float(matches[1] if len(matches) > 1 and "2026" in matches[0] else matches[0])
        if val == 2026.0 and pgn not in ["126992", "129033"]:
            return None
        return sid, val
    except:
        return None


def load_all_data(folder):
    sequences = {}
    if not os.path.exists(folder):
        print(f"[!] '{folder}' not found — graphs will be empty.")
        return sequences
    for fname in sorted(os.listdir(folder)):
        if not fname.endswith('.txt'):
            continue
        with open(os.path.join(folder, fname), 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                res = parse_line(line)
                if res:
                    sid, val = res
                    sequences.setdefault(sid, []).append(val)
    return sequences


def downsample(values, limit):
    if len(values) <= limit:
        return list(range(len(values))), values
    step = len(values) / limit
    idx  = [int(i * step) for i in range(limit)]
    return idx, [values[i] for i in idx]


# ══════════════════════════════════════════════════════════════════════════════
# SCALE GROUPING
# Splits a list of (sid, values) into bands so no two PGNs on the same
# sub-graph differ in range by more than 2 orders of magnitude (100x).
# This keeps every line visible without the small ones becoming flat.
# ══════════════════════════════════════════════════════════════════════════════
def group_by_scale(sid_values_list, max_ratio=100):
    """
    Returns a list of groups, each group = list of (sid, values).
    Within each group the max value range / min value range <= max_ratio.
    PGNs with no data are placed in a separate 'no data' group.
    """
    has_data   = []
    no_data    = []

    for sid, values in sid_values_list:
        if not values:
            no_data.append((sid, values))
            continue
        v_range = max(values) - min(values)
        if v_range < 1e-9:
            v_range = abs(np.mean(values)) if abs(np.mean(values)) > 1e-9 else 1.0
        has_data.append((sid, values, v_range))

    # Sort by range so nearby scales end up together
    has_data.sort(key=lambda x: x[2])

    groups = []
    current_group = []
    current_min_range = None

    for sid, values, v_range in has_data:
        if current_min_range is None:
            current_min_range = v_range
            current_group.append((sid, values))
        elif v_range / current_min_range <= max_ratio:
            current_group.append((sid, values))
        else:
            groups.append(current_group)
            current_group     = [(sid, values)]
            current_min_range = v_range

    if current_group:
        groups.append(current_group)

    return groups   # list of lists of (sid, values)


# ══════════════════════════════════════════════════════════════════════════════
# SMART Y-AXIS FORMATTER
# Uses engineering notation for large numbers, plain for small ones.
# ══════════════════════════════════════════════════════════════════════════════
def smart_formatter(ax):
    ymin, ymax = ax.get_ylim()
    span = abs(ymax - ymin)
    if span == 0:
        return
    if span > 9999 or abs(ymax) > 99999:
        ax.yaxis.set_major_formatter(
            mticker.FuncFormatter(lambda x, _: f'{x:,.0f}')
        )
    elif span < 0.01:
        ax.yaxis.set_major_formatter(
            mticker.FuncFormatter(lambda x, _: f'{x:.4f}')
        )
    elif span < 1:
        ax.yaxis.set_major_formatter(
            mticker.FuncFormatter(lambda x, _: f'{x:.3f}')
        )
    else:
        ax.yaxis.set_major_formatter(
            mticker.FuncFormatter(lambda x, _: f'{x:,.2f}')
        )


# ══════════════════════════════════════════════════════════════════════════════
# GRAPH BUILDER  — one matplotlib figure per scale group
# ══════════════════════════════════════════════════════════════════════════════
def _buf(fig):
    buf = io.BytesIO()
    fig.savefig(buf, format='png', dpi=130, bbox_inches='tight')
    plt.close(fig)
    buf.seek(0)
    return buf


def build_group_graph(nature, group, group_idx, total_groups, color_offset=0):
    """
    Draws one graph for a scale group of PGNs of the same nature type.
    Returns a BytesIO PNG buffer.
    """
    _, accent, type_label = NATURE_META.get(nature, ('#eee','#333',nature.title()))

    fig, ax = plt.subplots(figsize=(13, 7.8))
    fig.patch.set_facecolor('#ffffff')
    ax.set_facecolor('#f7f8fc')

    legend_handles = []

    for i, (sid, values) in enumerate(group):
        color = LINE_COLORS[(i + color_offset) % len(LINE_COLORS)]
        xs, ys = downsample(values, MAX_POINTS)

        # Line thickness and alpha scale with number of lines on graph
        lw    = 1.4 if len(group) <= 6 else (1.0 if len(group) <= 14 else 0.7)
        alpha = 0.85 if len(group) <= 6 else (0.70 if len(group) <= 14 else 0.60)

        ax.plot(xs, ys, linewidth=lw, alpha=alpha, color=color, zorder=3)

        # Value range annotation for the legend
        v_min  = min(values)
        v_max  = max(values)
        v_mean = np.mean(values)
        if v_max - v_min > 0.001:
            range_str = f'{v_min:,.2f} – {v_max:,.2f}'
        else:
            range_str = f'≈ {v_mean:,.4f}'

        handle = Line2D([0], [0], color=color, linewidth=2.5,
                        label=f'{sid}   [{range_str}]  ({len(values):,} pts)')
        legend_handles.append(handle)

    # ── Circular: fix y-axis to 0-360 with compass labels ────────────────
    if nature == 'circular':
        ax.set_ylim(-5, 365)
        ax.set_yticks(range(0, 361, 45))
        ax.set_yticklabels(
            ['0° N','45° NE','90° E','135° SE',
             '180° S','225° SW','270° W','315° NW','360°'],
            fontsize=9
        )
    else:
        # Let matplotlib auto-scale, then apply smart formatter
        ax.autoscale(axis='y', tight=False)
        # Add 5% padding
        ymin, ymax = ax.get_ylim()
        pad = (ymax - ymin) * 0.05
        ax.set_ylim(ymin - pad, ymax + pad)
        smart_formatter(ax)

    # ── Axis labels ───────────────────────────────────────────────────────
    y_label = {
        'circular': 'Heading (Degrees)',
        'counter':  'Counter Value',
    }.get(nature, 'Sensor Value')

    ax.set_ylabel(y_label, fontsize=11, color='#333', labelpad=8)
    ax.set_xlabel('Log Line Index  (reading number over time)',
                  fontsize=10, color='#444', labelpad=8)

    # ── Title ─────────────────────────────────────────────────────────────
    page_note = f'  (group {group_idx} of {total_groups})' if total_groups > 1 else ''
    ax.set_title(
        f'{type_label}{page_note}\n'
        f'Showing {len(group)} PGN{"s" if len(group)!=1 else ""}  —  '
        f'each colour is one sensor',
        fontsize=13, fontweight='bold', color='#1C2340', pad=12, linespacing=1.5
    )

    # ── Grid ──────────────────────────────────────────────────────────────
    ax.grid(True, linestyle='--', alpha=0.45, zorder=0)
    ax.spines[['top','right']].set_visible(False)
    ax.tick_params(labelsize=9, colors='#444')

    # ── Legend ────────────────────────────────────────────────────────────
    # Decide legend position: if many PGNs, put it below the graph
    n = len(legend_handles)
    if n <= 8:
        ax.legend(handles=legend_handles, fontsize=8.5, loc='best',
                  framealpha=0.90, edgecolor='#CCC', fancybox=True,
                  title='PGN   [value range]   (data points)',
                  title_fontsize=8)
        fig.subplots_adjust(bottom=0.09, top=0.88, left=0.10, right=0.97)
    else:
        n_col = max(1, min(3, math.ceil(n / 10)))
        fig.legend(handles=legend_handles, fontsize=7.5,
                   loc='lower center', ncol=n_col,
                   framealpha=0.92, edgecolor='#CCC', fancybox=True,
                   bbox_to_anchor=(0.5, 0.0),
                   title='PGN   [value range]   (data points)',
                   title_fontsize=8)
        fig.subplots_adjust(bottom=0.22 + 0.03 * math.ceil(n / n_col / 5),
                            top=0.88, left=0.10, right=0.97)

    return _buf(fig)


# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY CHART
# ══════════════════════════════════════════════════════════════════════════════
def make_summary_chart(brain):
    nature_counts = {}
    states_dist   = []
    for e in brain.values():
        n = e.get('nature', 'linear')
        nature_counts[n] = nature_counts.get(n, 0) + 1
        states_dist.append(e['model'].n_components)

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 3.4))
    fig.patch.set_facecolor('#ffffff')

    labels      = list(nature_counts.keys())
    sizes       = list(nature_counts.values())
    pie_colors  = [NATURE_META.get(l, ('#EEE','#888',''))[1] for l in labels]
    nice_labels = [NATURE_META.get(l, ('#EEE','#888',l))[2].split('(')[0].strip()
                   for l in labels]

    _, _, autotexts = ax1.pie(
        sizes, labels=nice_labels, colors=pie_colors,
        autopct=lambda p: f'{p:.0f}%\n({int(round(p*sum(sizes)/100))})',
        startangle=140, textprops={'fontsize': 9},
        wedgeprops={'linewidth': 1.5, 'edgecolor': 'white'}
    )
    for at in autotexts:
        at.set_fontsize(8)
    ax1.set_title('PGN Types', fontsize=12, fontweight='bold', color='#1C2340', pad=10)

    sc   = Counter(states_dist)
    xs   = sorted(sc.keys())
    ys   = [sc[x] for x in xs]
    bars = ax2.bar([str(x) for x in xs], ys, color='#1A7FC4', alpha=0.85,
                   width=0.55, edgecolor='white', linewidth=1.2)
    ax2.set_xlabel('Number of Hidden States', fontsize=9, color='#555')
    ax2.set_ylabel('Number of PGNs', fontsize=9, color='#555')
    ax2.set_title('States Per PGN', fontsize=12, fontweight='bold',
                  color='#1C2340', pad=10)
    ax2.tick_params(labelsize=9, colors='#555')
    ax2.spines[['top','right']].set_visible(False)
    for bar, val in zip(bars, ys):
        ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.1,
                 str(val), ha='center', va='bottom',
                 fontsize=9, fontweight='bold', color='#1C2340')
    ax2.grid(True, linestyle='--', alpha=0.4, axis='y')

    fig.tight_layout()
    buf = io.BytesIO()
    fig.savefig(buf, format='png', dpi=130, bbox_inches='tight')
    plt.close(fig)
    buf.seek(0)
    return buf


# ══════════════════════════════════════════════════════════════════════════════
# PDF BUILDER
# ══════════════════════════════════════════════════════════════════════════════
def build_report(brain, raw_data):
    os.makedirs('ML models', exist_ok=True)

    doc = SimpleDocTemplate(
        OUTPUT_PATH, pagesize=letter,
        leftMargin=0.45*inch, rightMargin=0.45*inch,
        topMargin=0.50*inch,  bottomMargin=0.50*inch,
    )

    story = []

    # ── PAGE 1: COVER / SUMMARY ───────────────────────────────────────────────
    nature_counts = {}
    by_type       = defaultdict(list)
    for sid, e in brain.items():
        n = e.get('nature', 'linear')
        nature_counts[n] = nature_counts.get(n, 0) + 1
        by_type[n].append(sid)

    cover_tbl = Table([[Paragraph(
        '<font color="#FFFFFF"><b>Boat Brain &mdash; PGN Report</b></font>',
        ParagraphStyle('CT', fontSize=26, leading=32,
                       fontName='Helvetica-Bold', textColor=C_WHITE)
    )]], colWidths=[7.6*inch])
    cover_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), C_DARK),
        ('PADDING',    (0,0), (-1,-1), 26),
    ]))
    story.append(cover_tbl)
    story.append(Spacer(1, 0.15*inch))

    story.append(Paragraph(
        'This report shows every PGN (Parameter Group Number) the boat sensor brain '
        'has learned about. Each PGN is a specific type of sensor data such as wind '
        'speed, heading, or engine RPM. The following pages show all PGNs grouped by '
        'type. PGNs with very different value scales are split across separate graphs '
        'so every line stays readable.',
        ParagraphStyle('intro', fontSize=10, leading=15, textColor=C_TEXT, spaceAfter=13)
    ))

    total      = len(brain)
    avg_states = np.mean([e['model'].n_components for e in brain.values()])

    def card(top, bottom, color='#1C2340'):
        return Paragraph(
            f'<font size="17"><b><font color="{color}">{top}</font></b></font>'
            f'<br/><font size="8" color="#6B7399">{bottom}</font>',
            ParagraphStyle('card', leading=24, alignment=1)
        )

    cards_tbl = Table([[
        card(str(total),                            'Total PGNs learned'),
        card(f'{avg_states:.1f}',                   'Avg hidden states'),
        card(str(nature_counts.get('circular', 0)), 'Circular PGNs',  '#1A7FC4'),
        card(str(nature_counts.get('linear',   0)), 'Linear PGNs',    '#1E8A45'),
        card(str(nature_counts.get('counter',  0)), 'Counter PGNs',   '#C07A00'),
        card(str(nature_counts.get('static',   0)), 'Static PGNs',    '#6D3EC1'),
    ]], colWidths=[1.26*inch]*6)
    cards_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), C_OFFWHITE),
        ('BOX',        (0,0), (-1,-1), 0.5, C_RULE),
        ('INNERGRID',  (0,0), (-1,-1), 0.5, C_RULE),
        ('PADDING',    (0,0), (-1,-1), 10),
        ('VALIGN',     (0,0), (-1,-1), 'MIDDLE'),
        ('ALIGN',      (0,0), (-1,-1), 'CENTER'),
    ]))
    story.append(cards_tbl)
    story.append(Spacer(1, 0.15*inch))
    story.append(Image(make_summary_chart(brain), width=7.6*inch, height=2.7*inch))
    story.append(Spacer(1, 0.13*inch))

    legend_data = [
        [Paragraph('<b>Circular</b>',
                   ParagraphStyle('l', fontSize=9, textColor=HexColor('#1A7FC4'))),
         Paragraph('Values that wrap around, like compass heading (0-360 degrees). '
                   'Y-axis is always fixed 0-360 with compass point labels.',
                   ParagraphStyle('l', fontSize=9, textColor=C_TEXT)),
         Paragraph('<b>Linear</b>',
                   ParagraphStyle('l', fontSize=9, textColor=HexColor('#1E8A45'))),
         Paragraph('Values that go up and down freely. '
                   'Y-axis auto-scales to the actual data range.',
                   ParagraphStyle('l', fontSize=9, textColor=C_TEXT))],
        [Paragraph('<b>Counter</b>',
                   ParagraphStyle('l', fontSize=9, textColor=HexColor('#C07A00'))),
         Paragraph('Values that only count upward, like engine hours or trip distance.',
                   ParagraphStyle('l', fontSize=9, textColor=C_TEXT)),
         Paragraph('<b>Static</b>',
                   ParagraphStyle('l', fontSize=9, textColor=HexColor('#6D3EC1'))),
         Paragraph('Values that almost never change. '
                   'Readings outside the normal band are highlighted.',
                   ParagraphStyle('l', fontSize=9, textColor=C_TEXT))],
    ]
    legend_tbl = Table(legend_data, colWidths=[0.9*inch, 2.85*inch, 0.9*inch, 2.95*inch])
    legend_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), C_OFFWHITE),
        ('BOX',        (0,0), (-1,-1), 0.5, C_RULE),
        ('INNERGRID',  (0,0), (-1,-1), 0.5, C_RULE),
        ('PADDING',    (0,0), (-1,-1), 7),
        ('VALIGN',     (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(legend_tbl)

    # ── GRAPH PAGES ───────────────────────────────────────────────────────────
    for nature in ['circular', 'linear', 'counter', 'static']:
        sids = sorted(by_type.get(nature, []))
        if not sids:
            continue

        _, accent, type_label = NATURE_META[nature]

        # Build (sid, values) list — empty list if no raw data
        sid_values = [(sid, raw_data.get(sid, [])) for sid in sids]

        # Group into scale bands
        groups = group_by_scale(sid_values)

        total_groups = len(groups)
        print(f"  {nature}: {len(sids)} PGNs → {total_groups} graph(s)")

        color_offset = 0
        for g_idx, group in enumerate(groups, 1):
            story.append(PageBreak())

            # Page header bar
            page_note = f'  (graph {g_idx} of {total_groups})' if total_groups > 1 else ''
            scale_note = ''
            if total_groups > 1:
                vals_in_group = [v for _, v in group if v]
                if vals_in_group:
                    all_v  = [x for vlist in vals_in_group for x in vlist]
                    scale_note = (f'  |  Value range on this page: '
                                  f'{min(all_v):,.2f} – {max(all_v):,.2f}')

            hdr_tbl = Table([[
                Paragraph(
                    f'<font color="#FFFFFF"><b>{type_label}{page_note}</b></font>',
                    ParagraphStyle('ph', fontSize=13, fontName='Helvetica-Bold',
                                   textColor=C_WHITE, leading=17)
                ),
                Paragraph(
                    f'<font color="#AABBDD">'
                    f'{len(group)} PGN{"s" if len(group)!=1 else ""}'
                    f'  |  each colour = one sensor{scale_note}'
                    f'</font>',
                    ParagraphStyle('ph2', fontSize=8.5, fontName='Helvetica',
                                   textColor=C_WHITE, leading=13, alignment=2)
                ),
            ]], colWidths=[3.8*inch, 3.8*inch])
            hdr_tbl.setStyle(TableStyle([
                ('BACKGROUND', (0,0), (-1,-1), C_DARK),
                ('PADDING',    (0,0), (-1,-1), 10),
                ('VALIGN',     (0,0), (-1,-1), 'MIDDLE'),
            ]))
            story.append(hdr_tbl)
            story.append(Spacer(1, 0.08*inch))

            graph_buf = build_group_graph(
                nature, group, g_idx, total_groups,
                color_offset=color_offset
            )
            story.append(Image(graph_buf, width=7.6*inch, height=8.8*inch))

            color_offset += len(group)   # keep colours distinct across pages of same type

    doc.build(story)
    print(f'\n[OK] Report saved → {OUTPUT_PATH}')


# ══════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if not os.path.exists(BRAIN_PATH):
        print(f'Brain not found at: {BRAIN_PATH}')
        print('Run the builder first.')
        exit(1)

    print('Loading brain...')
    brain = joblib.load(BRAIN_PATH)
    print(f'{len(brain)} PGN entries found.')

    print(f'Loading raw data from {DATA_FOLDER}...')
    raw_data = load_all_data(DATA_FOLDER)
    print(f'Loaded data for {len(raw_data)} PGNs.')

    print('Generating report...')
    build_report(brain, raw_data)
