"""Cycle model of Roman's proyecto_final/vga_out.sv as checked by vga_out_tb.sv.

Source: https://github.com/romanmg00/FPGA at f5cb82c. No HDL simulator was used.
vga_out registers pix_* (pix <= visible ? draw : 0) while the testbench compares
pix_* at each posedge against the *current* curr_x/curr_y, with draw_* held at 0xF.
Predicts one false mismatch at x = 0 and one at x = 1280 of every visible line
(800 + 800 per frame). See "CS-256 Tron Integration Comparison" finding H4.
"""
H, V = 1680, 828
def vis(h, v): return 336 <= h < 1616 and 27 <= v < 827
errs = {"pix!=draw (visible)": 0, "pix!=0 (blank)": 0}
first = []
h = v = 0
pix = 0          # registered output, reset to 0
for cyc in range(H * V + 5):
    cx = (h - 336) & 0x7FF; cy = (v - 27) & 0x3FF
    # TB samples pre-edge values at posedge
    if cx < 1280 and cy < 800:
        if pix != 0xF: errs["pix!=draw (visible)"] += 1; first.append(("vis", h, v)) if len(first) < 4 else None
    else:
        if pix != 0: errs["pix!=0 (blank)"] += 1; first.append(("blank", h, v)) if len(first) < 8 else None
    # edge: pix <= visible(now) ? draw : 0 ; counters advance
    pix = 0xF if vis(h, v) else 0
    if h == H - 1:
        h = 0; v = 0 if v == V - 1 else v + 1
    else:
        h += 1
print(errs); print(first)
