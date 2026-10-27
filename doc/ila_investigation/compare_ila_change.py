"""Check the functional LURecover text before/after ILA insertion.

This is source normalization, not a formal netlist-equivalence proof.
Only instrumentation, output aliases, and whitespace are removed.
"""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "Vivado_project/Encoder_v3.1_Firmware.srcs/sources_1/new/LURecover.vhd"


def revision(rev):
    return subprocess.check_output(
        ["git", "show", f"{rev}:{SOURCE}"], cwd=ROOT, text=True
    )


old = revision("aa75390")
new = revision("3bad011")
new = re.sub(r"    component ila_LURecover.*?    end component;", "", new, flags=re.S)
new = re.sub(
    r"process \(lu_judge, hit_check, ap_off_wait, ap_on_wait, dac_run, reg_dac\).*?(?=end Behavioral;)",
    "", new, flags=re.S,
)
new = re.sub(r"    signal\s+(reg_ap_on|reg_dac_ctrl|lu_debug_state)\s*:.*?;", "", new)
new = re.sub(
    r"^(ap_on\s*<= reg_ap_on;|dac_ctrl\s*<= reg_dac_ctrl;)\s*", "", new, flags=re.M
)
new = new.replace("reg_ap_on", "ap_on").replace("reg_dac_ctrl", "dac_ctrl")
assert re.sub(r"\s", "", old) == re.sub(r"\s", "", new)
print("PASS: aa75390 and 3bad011 LURecover functional source matches after instrumentation/alias removal")
