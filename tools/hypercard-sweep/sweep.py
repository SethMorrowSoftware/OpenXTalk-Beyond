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
--icons is the IDE's revicons.rev (default: this checkout's), which the
IDE keeps in memory and which holds HyperCard's brushes and patterns.
--image is the disk image extract.py read the stacks from: a stack then
finds the stacks beside it on the image, as one imported from that image
by File > Import Stack does.
"""

import argparse
import concurrent.futures
import os
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LIBRARIES = os.path.normpath(os.path.join(HERE, "..", "..", "ide", "Toolset", "libraries"))
ICONS = os.path.normpath(os.path.join(HERE, "..", "..", "ide", "Toolset", "palettes", "revicons.rev"))


def volume_name(image):
    """The name of the HFS volume in a disk image (a bare volume, a
    DiskCopy 4.2 image or the Apple_HFS partition of an Apple partition
    map): the first part of a stack's path on the image as the disk image
    library gives it, which index.tsv leaves out"""
    with open(image, "rb") as handle:
        def read(at, size):
            handle.seek(at)
            return handle.read(size)
        # a bare volume, and a DiskCopy 4.2 image's 84-byte header
        starts = [0, 84]
        head = read(0, 512)
        if head[:2] == b"ER":
            block = struct.unpack(">H", head[2:4])[0] or 512
            entry, count = 1, 1
            while entry <= min(count, 256):
                part = read(entry * 512, 512)
                if part[:2] != b"PM":
                    break
                count = struct.unpack(">I", part[4:8])[0]
                if part[48:57] == b"Apple_HFS":
                    first = struct.unpack(">I", part[8:12])[0]
                    starts += [first * 512, first * block]
                entry += 1
        for start in starts:
            # the master directory block, with the volume's name
            mdb = read(start + 1024, 64)
            if mdb[:2] == b"BD":
                return mdb[37:37 + mdb[36]].decode("mac_roman")
    sys.exit("no HFS volume in " + image)


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
               HC_LIB=os.path.abspath(args.lib), HC_ICONS=os.path.abspath(args.icons) if args.icons else "",
               HC_MODE=args.mode,
               HC_ORDER="1" if args.hypertalk_order else "0",
               HC_SOUND="1" if args.sound else "0",
               HC_IMAGE=os.path.abspath(args.image) if name in args.paths else "",
               HC_IMAGEPATH=args.paths.get(name, ""))
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
    parser.add_argument("--image", help="the disk image extract.py read the stacks from: a stack finds the stacks "
                                         "beside it on the image, as File > Import Stack from a disk image does "
                                         "(the stacks folder's index.tsv gives where each one is)")
    parser.add_argument("--out", required=True, help="the folder for this run's logs")
    parser.add_argument("--mode", choices=["fix", "run"], default="fix")
    parser.add_argument("--lib", default=LIBRARIES)
    parser.add_argument("--icons", default=ICONS,
                        help="the IDE's revicons.rev, with HyperCard's brushes and patterns (empty: none)")
    parser.add_argument("--sound", action="store_true",
                        help="let the stacks play their sounds and speak (a run sweep silences them: several "
                             "stacks at a time play sounds while nobody is there to hear them)")
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    parser.add_argument("--timeout", type=float, default=None,
                        help="seconds per stack (default: 60 for fix, 25 for run)")
    args = parser.parse_args()
    if args.timeout is None:
        args.timeout = 60 if args.mode == "fix" else 25
    # each stack's path on the image: its volume, then the folders and name
    # that extract.py's index.tsv gives, joined by colons
    args.paths = {}
    if args.image:
        volume = volume_name(args.image)
        with open(os.path.join(args.stacks, "index.tsv"), encoding="utf-8") as handle:
            for line in handle:
                fields = line.rstrip("\n").split("\t")
                if len(fields) >= 2:
                    args.paths[fields[0]] = volume + ":" + fields[1]
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
