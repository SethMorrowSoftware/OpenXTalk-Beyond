#!/usr/bin/env python3
"""Run sweep.livecodescript over every stack of a folder, in parallel.

    python3 sweep.py --engine PATH --stacks stacks/ --out runs/fix-main
    python3 sweep.py --engine PATH --stacks stacks/ --out runs/run-main --mode run

--engine is an OXT-Beyond engine (LiveCode-Community on Linux,
"OXT-Beyond.exe" or the like on Windows, the binary inside the .app on a
Mac). Each stack is one engine started with -ui, so a stack that hangs or
crashes takes only itself; its log is out/NNNNN.txt. A stack whose log
already ends with an EXIT line is skipped, so a run that was stopped
goes on where it was. --lib is the folder of the HyperCard libraries to
load (default: this checkout's ide/Toolset/libraries), so a branch's
rules can be measured against the released ones with the same engine.
"""

import argparse
import concurrent.futures
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LIBRARIES = os.path.normpath(os.path.join(HERE, "..", "..", "ide", "Toolset", "libraries"))


def finished(log):
    try:
        with open(log, encoding="utf-8", errors="replace") as handle:
            return any(line.startswith("EXIT\t") for line in handle)
    except OSError:
        return False


def one(args, stack):
    name = os.path.splitext(os.path.basename(stack))[0]
    log = os.path.join(args.out, name + ".txt")
    if finished(log):
        return name, "skipped"
    if os.path.exists(log):
        os.remove(log)
    env = dict(os.environ, HC_IN=os.path.abspath(stack), HC_OUT=os.path.abspath(log),
               HC_LIB=os.path.abspath(args.lib), HC_MODE=args.mode,
               HC_ORDER="1" if args.hypertalk_order else "0")
    command = [args.engine, "-ui", os.path.join(HERE, "sweep.livecodescript")]
    try:
        result = subprocess.run(command, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                timeout=args.timeout)
        code = str(result.returncode)
    except subprocess.TimeoutExpired:
        code = "timeout"
    with open(log, "a", encoding="utf-8") as handle:
        handle.write("EXIT\t%s\n" % code)
    return name, code


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--engine", required=True)
    parser.add_argument("--stacks", required=True, help="the folder extract.py wrote")
    parser.add_argument("--hypertalk-order", action="store_true",
                        help="set hyperTalkCompatible on each stack before its scripts are fixed, as File > "
                             "Import Stack does (an engine that has the property)")
    parser.add_argument("--out", required=True, help="the folder for this run's logs")
    parser.add_argument("--mode", choices=["fix", "run"], default="fix")
    parser.add_argument("--lib", default=LIBRARIES)
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    parser.add_argument("--timeout", type=float, default=None,
                        help="seconds per stack (default: 60 for fix, 25 for run)")
    args = parser.parse_args()
    if args.timeout is None:
        args.timeout = 60 if args.mode == "fix" else 25
    os.makedirs(args.out, exist_ok=True)
    stacks = sorted(os.path.join(args.stacks, name) for name in os.listdir(args.stacks) if name.endswith(".bin"))
    if not stacks:
        sys.exit("no .bin stacks in " + args.stacks)
    done = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for name, code in pool.map(lambda stack: one(args, stack), stacks):
            done += 1
            if done % 100 == 0 or done == len(stacks):
                print("%d of %d" % (done, len(stacks)), flush=True)
    print("logs in", args.out)


if __name__ == "__main__":
    main()
